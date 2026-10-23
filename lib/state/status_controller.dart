import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import '../core/l10n/l10n.dart';
import '../data/api/uk_api.dart';
import '../data/cache/image_cache.dart';
import '../data/cache/cache_store.dart';
import '../data/models/server_config.dart';
import '../data/models/status_page.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';

/// Owns polling, caching and the "did this monitor just change state?"
/// detection that drives notifications.
class StatusController extends ChangeNotifier {
  /// Set [seedSnapshot] to render a pre-loaded dashboard without hitting the
  /// network — used by widget tests.
  StatusController(
    this._app, {
    StatusSnapshot? seedSnapshot,
    this.snapshotBuilder,
  }) {
    _api = _newApi();
    if (seedSnapshot != null) {
      _snapshot = seedSnapshot;
      _lastSyncAt = seedSnapshot.fetchedAt;
      _primed = true;
    }
  }

  final AppState _app;
  late UkApi _api;

  /// Optional alternative data source. Management-mode instances have no
  /// public status page, so their board is built from the admin session.
  /// Returning `null` falls back to the public endpoints.
  final Future<StatusSnapshot?> Function(ServerConfig server)? snapshotBuilder;

  UkApi _newApi() => UkApi(
        doh: _app.dohEnabled,
        dohEndpoint: _app.dohUrl,
        userAgent: _app.userAgent,
      );

  Timer? _timer;
  ServerConfig? _server;
  StatusSnapshot? _snapshot;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastSyncAt;

  /// Last known status per monitor id, used for transition detection.
  final Map<int, MonitorStatus> _lastStatus = {};

  /// When a monitor first went down, keyed by monitor id.
  final Map<int, DateTime> _downSince = {};

  /// Suppresses alerts for the very first successful load of an instance.
  bool _primed = false;

  /// Instances rendered together. More than one means the active instance is
  /// part of a collection: their boards are merged, in list order.
  List<ServerConfig> _members = const [];

  StatusSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  DateTime? get lastSyncAt => _lastSyncAt;
  ServerConfig? get server => _server;
  bool get hasData => _snapshot != null;

  /// Instances currently on screen (one, unless a collection is active).
  List<ServerConfig> get members => _members;
  bool get merged => _members.length > 1;

  /// Collections only merge public pages: a management session belongs to one
  /// instance and cannot be multiplexed.
  static List<ServerConfig> _resolveMembers(
    AppState app,
    ServerConfig? server,
  ) {
    if (server == null) return const [];
    if (!server.inCollection || server.isManage) return [server];
    final list = app
        .serversInCollection(server.collectionId)
        .where((s) => !s.isManage && s.hasPublicPage)
        .toList(growable: false);
    return list.length > 1 ? list : [server];
  }

  /// Cache is keyed by collection so a merged board survives a cold start.
  String? get _cacheKey {
    final server = _server;
    if (server == null) return null;
    if (merged) return 'col_${server.collectionId}';
    return server.id;
  }

  Future<void> attach(ServerConfig? server) async {
    if (server?.id == _server?.id) {
      if (server != null && _snapshot == null) await load(showSpinner: true);
      return;
    }
    // Hopping between members of the same collection reuses the merged board:
    // nothing on screen changes, so reloading would only flash the list.
    if (merged &&
        server != null &&
        server.collectionId != null &&
        server.collectionId == _server?.collectionId) {
      _server = server;
      notifyListeners();
      return;
    }
    _server = server;
    _members = _resolveMembers(_app, server);
    _snapshot = null;
    _error = null;
    _primed = false;
    _lastStatus.clear();
    _downSince.clear();
    _lastSyncAt = null;
    _timer?.cancel();
    notifyListeners();

    if (server == null) return;
    await load(showSpinner: true);
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final seconds = _app.pollSeconds;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => load());
  }

  /// Recreates the HTTP stack after DoH / User-Agent changes.
  Future<void> onNetworkPrefsChanged() async {
    _api.dispose();
    _api = _newApi();
    if (_server != null) await load(showSpinner: false);
  }

  void onPollIntervalChanged() {
    if (_server != null) _restartTimer();
  }

  /// Instant paint from disk, then a network refresh.
  Future<void> load({bool showSpinner = false}) async {
    final server = _server;
    if (server == null) return;

    if (showSpinner && _snapshot == null) {
      _loading = true;
      notifyListeners();
    }

    if (_snapshot == null) {
      final cacheKey = _cacheKey ?? server.id;
      final cached = await CacheStore.instance.readSnapshot(cacheKey);
      if (cached != null && _snapshot == null) {
        _snapshot = cached;
        _lastSyncAt = cached.fetchedAt;
        _seedStatusMap(cached);
        _loading = false;
        notifyListeners();
      }
    }

    _refreshing = true;
    notifyListeners();

    try {
      final StatusSnapshot fresh;
      if (merged) {
        // One board made of every collection member, in list order.
        final parts = <({String label, StatusSnapshot snapshot})>[];
        Object? lastError;
        for (final member in _members) {
          try {
            parts.add((
              label: member.name,
              snapshot: await _api.fetchSnapshot(member),
            ));
          } catch (e) {
            lastError = e;
            debugPrint('collection member ${member.name} failed: $e');
          }
        }
        if (parts.isEmpty) {
          throw UkApiException(lastError?.toString() ?? 'No member responded');
        }
        fresh = StatusSnapshot.merge(parts);
      } else {
        final builder = snapshotBuilder;
        StatusSnapshot? built;
        if (builder != null) {
          try {
            built = await builder(server);
          } catch (e) {
            debugPrint('admin snapshot unavailable: $e');
          }
        }
        fresh = built ?? await _api.fetchSnapshot(server);
      }
      _snapshot = fresh;
      _error = null;
      _lastSyncAt = fresh.fetchedAt;
      await CacheStore.instance.writeSnapshot(_cacheKey ?? server.id, fresh);
      // Pull the status-page logo down now so the header never waits for it.
      for (final member in merged ? _members : [server]) {
        final iconUrl = member.resolveAsset(fresh.config.iconPath);
        if (iconUrl == null) continue;
        unawaited(ImageDiskCache.instance.prefetch(
          iconUrl,
          doh: _app.dohEnabled,
          dohEndpoint: _app.dohUrl,
          userAgent: _app.userAgent,
        ));
      }
      _detectTransitions(fresh);
      _loading = false;
      _refreshing = false;
      notifyListeners();
    } on UkApiException catch (e) {
      _error = e.message;
      _loading = false;
      _refreshing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  void _seedStatusMap(StatusSnapshot snapshot) {
    if (_primed) return;
    for (final m in snapshot.allMonitors) {
      final st = snapshot.statusOf(m.id);
      if (st != MonitorStatus.unknown) _lastStatus[m.id] = st;
      if (st == MonitorStatus.down) _downSince[m.id] = snapshot.fetchedAt;
    }
    _primed = true;
  }

  Future<void> _detectTransitions(StatusSnapshot fresh) async {
    final firstRun = !_primed;
    final l10n = L10n(_app.localeOverride ?? const Locale('zh'));
    final sound = _app.sound;
    final settings = _app.store;

    for (final monitor in fresh.allMonitors) {
      final status = fresh.statusOf(monitor.id);
      if (status == MonitorStatus.unknown) continue;
      final previous = _lastStatus[monitor.id];

      if (firstRun) {
        _lastStatus[monitor.id] = status;
        if (status == MonitorStatus.down) {
          _downSince[monitor.id] = _lastDownTime(fresh, monitor.id) ?? DateTime.now();
        }
        continue;
      }

      if (previous == status) continue;
      _lastStatus[monitor.id] = status;

      final downHeartbeat = _lastDownTime(fresh, monitor.id);
      final detail = _lastMessage(fresh, monitor.id);

      if (status == MonitorStatus.down) {
        final since = downHeartbeat ?? DateTime.now();
        _downSince[monitor.id] = since;
        if (settings.notificationsEnabled && settings.notifyOnDown) {
          unawaited(NotificationService.instance.showFault(
            l10n: l10n,
            monitor: monitor,
            instanceName: _server?.name ?? 'Uptime Kuma',
            startedAt: since,
            sound: sound,
            detail: detail,
            inApp: _app.inAppSound,
          ));
        }
      } else if (previous == MonitorStatus.down &&
          (status == MonitorStatus.up || status == MonitorStatus.maintenance)) {
        final since = _downSince.remove(monitor.id) ?? downHeartbeat;
        final downtime = since == null ? null : _humanDuration(DateTime.now().difference(since));
        if (settings.notificationsEnabled && settings.notifyOnUp) {
          unawaited(NotificationService.instance.showRecovery(
            l10n: l10n,
            monitor: monitor,
            instanceName: _server?.name ?? 'Uptime Kuma',
            recoveredAt: DateTime.now(),
            sound: sound,
            downtime: downtime,
            detail: detail,
            inApp: _app.inAppSound,
          ));
        }
      }
    }

    _primed = true;
    await _persistStatusMap(fresh);
  }

  Future<void> _persistStatusMap(StatusSnapshot snapshot) async {
    final server = _server;
    if (server == null) return;
    final map = <int, int>{};
    for (final m in snapshot.allMonitors) {
      final st = snapshot.statusOf(m.id);
      if (st != MonitorStatus.unknown) map[m.id] = st.code;
    }
    await CacheStore.instance.writeStatusMap(server.id, map);
  }

  DateTime? _lastDownTime(StatusSnapshot snapshot, int monitorId) {
    final list = snapshot.heartbeatsOf(monitorId);
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].status == MonitorStatus.down) return list[i].time.toLocal();
      if (list[i].status == MonitorStatus.up) return null;
    }
    return null;
  }

  String? _lastMessage(StatusSnapshot snapshot, int monitorId) {
    final list = snapshot.heartbeatsOf(monitorId);
    for (var i = list.length - 1; i >= 0; i--) {
      final msg = list[i].msg;
      if (msg.trim().isNotEmpty) return msg.trim();
    }
    return null;
  }

  static String _humanDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d ${d.inHours % 24}h';
  }

  Monitor? findMonitor(int id) {
    final snap = _snapshot;
    if (snap == null) return null;
    for (final g in snap.groups) {
      for (final m in g.monitors) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
