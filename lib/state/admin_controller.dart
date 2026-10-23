import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api/uk_socket.dart';
import '../services/credential_store.dart';
import '../data/models/admin_models.dart';
import '../data/models/server_config.dart';
import '../data/models/status_page.dart';
import 'app_state.dart';

/// Owns the authenticated management session for the active instance.
///
/// Uptime Kuma has no management REST API: monitors, notifications and
/// incidents are only reachable through Socket.IO. A successful login returns
/// a JWT, which is what we persist — the password is used once and dropped.
class AdminController extends ChangeNotifier {
  AdminController(this._app);

  final AppState _app;

  UkAdmin? _admin;
  ServerConfig? _server;

  AdminData? _data;
  bool _connecting = false;
  bool _signedIn = false;
  bool _needsCredentials = false;
  String? _error;
  DateTime? _syncedAt;

  ServerConfig? get server => _server;
  AdminData? get data => _data;
  bool get connecting => _connecting;
  bool get signedIn => _signedIn;
  bool get needsCredentials => _needsCredentials;
  String? get error => _error;
  DateTime? get syncedAt => _syncedAt;

  List<AdminMonitor> get monitors {
    final data = _data;
    if (data == null) return const [];
    final list = data.monitors.values.map(AdminMonitor.new).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  List<Map<String, dynamic>> get notifications => _data?.notifications ?? const [];

  List<Map<String, dynamic>> get statusPages => _data?.statusPages ?? const [];

  /// Top-level monitors (those not inside a group) plus their children.
  List<AdminMonitor> childrenOf(int groupId) =>
      monitors.where((m) => m.parent == groupId).toList(growable: false);

  List<AdminMonitor> get rootMonitors =>
      monitors.where((m) => m.parent == null).toList(growable: false);

  List<AdminMonitor> get groups =>
      monitors.where((m) => m.kind.isGroup).toList(growable: false);

  Future<void> attach(ServerConfig? server) async {
    final changed = server?.id != _server?.id || server?.token != _server?.token;
    _server = server;
    if (!changed) return;

    _data = null;
    _signedIn = false;
    _needsCredentials = false;
    _error = null;
    _syncedAt = null;

    await _admin?.dispose();
    _admin = null;

    if (server == null || !server.isManage) {
      notifyListeners();
      return;
    }

    _admin = UkAdmin(server, userAgent: _app.store.userAgent);
    notifyListeners();

    if (server.hasSession) {
      final ok = await _admin!.resume(server.token);
      if (ok) {
        _signedIn = true;
        notifyListeners();
        await refresh();
        return;
      }
      // The JWT expired (typically after the app sat in the background). Try
      // the stored password before bothering the user.
      if (await _silentSignIn(server)) return;
      _needsCredentials = true;
      notifyListeners();
      return;
    }

    if (await _silentSignIn(server)) return;
    _needsCredentials = true;
    notifyListeners();
  }

  /// Signs in with the keystore password. Returns false when the feature is off,
  /// nothing is stored, or the server demands a second factor.
  Future<bool> _silentSignIn(ServerConfig server) async {
    if (!_app.silentLogin) return false;
    if (server.username.isEmpty) return false;
    final password = await CredentialStore.read(server.id);
    if (password == null || password.isEmpty) return false;

    _connecting = true;
    notifyListeners();
    final result = await _admin!.signIn(
      username: server.username,
      password: password,
    );
    _connecting = false;
    if (!result.ok) {
      notifyListeners();
      return false;
    }

    _signedIn = true;
    _needsCredentials = false;
    await _app.updateServer(server.copyWith(token: result.token ?? ''));
    _server = _app.servers.firstWhere((s) => s.id == server.id, orElse: () => server);
    notifyListeners();
    await refresh();
    return true;
  }

  /// First-time sign-in. Stores the JWT on success, never the password.
  Future<AdminLoginResult> signIn({
    required String username,
    required String password,
    String? otp,
  }) async {
    final server = _server;
    final admin = _admin;
    if (server == null || admin == null) {
      return const AdminLoginResult(ok: false, message: 'No instance selected');
    }

    _connecting = true;
    _error = null;
    notifyListeners();

    final result = await admin.signIn(username: username, password: password, otp: otp);
    _connecting = false;

    if (!result.ok) {
      _error = result.message;
      notifyListeners();
      return result;
    }

    _signedIn = true;
    _needsCredentials = false;
    // Persist the session token instead of the password.
    await _app.updateServer(
      server.copyWith(username: username, token: result.token ?? ''),
    );
    _server = _app.servers.firstWhere((s) => s.id == server.id, orElse: () => server);
    notifyListeners();

    await refresh();
    return result;
  }

  Future<void> signOut() async {
    await _admin?.logout();
    await _admin?.dispose();
    _admin = null;
    _signedIn = false;
    _data = null;
    final server = _server;
    if (server != null) {
      await _app.updateServer(server.copyWith(token: ''));
      _server = server.copyWith(token: '');
      _admin = UkAdmin(_server!, userAgent: _app.store.userAgent);
    }
    _needsCredentials = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    final admin = _admin;
    if (admin == null || !_signedIn) return;
    _connecting = true;
    notifyListeners();
    try {
      _data = await admin.fetch();
      _error = null;
      _syncedAt = DateTime.now();
    } on UkSocketException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  // Mutations --------------------------------------------------------------

  Future<void> saveMonitor(MonitorDraft draft) async {
    final admin = _admin;
    if (admin == null) throw UkSocketException('Not signed in');
    if (draft.isNew) {
      await admin.addMonitor(draft.toPayload());
    } else {
      await admin.editMonitor(draft.toPayload());
    }
    await refresh();
  }

  Future<void> deleteMonitor(int id) async {
    await _admin?.deleteMonitor(id);
    await refresh();
  }

  Future<void> setMonitorActive(int id, bool active) async {
    await _admin?.setMonitorActive(id, active);
    await refresh();
  }

  Future<void> saveNotification(Map<String, dynamic> payload, {int? id}) async {
    await _admin?.addNotification(payload, id: id);
    await refresh();
  }

  Future<void> deleteNotification(int id) async {
    await _admin?.deleteNotification(id);
    await refresh();
  }

  /// Creates a bare status page. Monitors are attached to it from the web UI.
  Future<void> addStatusPage({required String title, required String slug}) async {
    await _admin?.addStatusPage(title: title, slug: slug);
    await refresh();
  }

  Future<void> testNotification(Map<String, dynamic> notification) async {
    await _admin?.testNotification(notification);
  }

  Future<void> postIncident({
    required String slug,
    required String title,
    required String content,
    required String style,
  }) async {
    await _admin?.postIncident(
      slug: slug,
      title: title,
      content: content,
      style: style,
    );
  }

  /// Builds a dashboard snapshot out of the admin payload, so instances with
  /// no published status page still get a full monitor board.
  StatusSnapshot? buildSnapshot() {
    final data = _data;
    final server = _server;
    if (data == null || server == null || data.monitors.isEmpty) return null;

    final heartbeats = <int, List<Heartbeat>>{};
    data.heartbeats.forEach((id, rows) {
      heartbeats[id] = rows
          .map((h) => Heartbeat(
                status: MonitorStatus.fromCode((h['status'] as num?)?.toInt()),
                time: Heartbeat.parseKumaTime(h['time'] as String?),
                msg: (h['msg'] as String?) ?? '',
                ping: (h['ping'] as num?)?.toDouble(),
              ))
          .toList(growable: false);
    });

    final groups = <MonitorGroup>[];
    final groupRows = data.monitors.values
        .where((row) => (row['type'] as String?) == 'group')
        .toList()
      ..sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));

    Monitor toMonitor(Map<String, dynamic> row) => Monitor(
          id: (row['id'] as num).toInt(),
          name: (row['name'] as String?) ?? '—',
          type: (row['type'] as String?) ?? 'http',
          sendUrl: true,
          certExpiryDays: (row['certExpiryDaysRemaining'] as num?)?.toInt(),
        );

    for (final group in groupRows) {
      final groupId = (group['id'] as num).toInt();
      final members = data.monitors.values
          .where((row) => ((row['parent'] as num?)?.toInt() ?? 0) == groupId)
          .where((row) => (row['type'] as String?) != 'group')
          .toList()
        ..sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
      groups.add(MonitorGroup(
        id: groupId,
        name: (group['name'] as String?) ?? 'Group',
        monitors: members.map(toMonitor).toList(growable: false),
      ));
    }

    final loose = data.monitors.values
        .where((row) => ((row['parent'] as num?)?.toInt() ?? 0) == 0)
        .where((row) => (row['type'] as String?) != 'group')
        .toList()
      ..sort((a, b) => ((a['id'] as num).toInt()).compareTo((b['id'] as num).toInt()));
    if (loose.isNotEmpty || groups.isEmpty) {
      groups.insert(
        0,
        MonitorGroup(
          id: 0,
          name: server.name,
          monitors: loose.map(toMonitor).toList(growable: false),
        ),
      );
    }

    return StatusSnapshot(
      config: StatusPageConfig(
        slug: server.slug,
        title: server.name,
        description: '',
        iconPath: null,
        theme: 'auto',
        published: true,
      ),
      groups: groups,
      heartbeats: heartbeats,
      uptime: data.uptime,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    unawaited(_admin?.dispose());
    super.dispose();
  }
}
