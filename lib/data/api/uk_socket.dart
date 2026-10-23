import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/server_config.dart';

/// A single inbound Socket.IO event.
class UkSocketEvent {
  UkSocketEvent(this.name, this.args);

  final String name;
  final List<dynamic> args;

  dynamic get first => args.isEmpty ? null : args.first;
}

class UkSocketException implements Exception {
  UkSocketException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin, testable wrapper around `socket_io_client`.
///
/// Uptime Kuma exposes *no* management REST API — everything except the public
/// status page runs over Socket.IO with an authenticated session. The API key
/// only unlocks `/metrics`.
class UkSocket {
  UkSocket({required this.baseUrl, this.userAgent});

  final String baseUrl;
  final String? userAgent;

  io.Socket? _socket;
  final _events = StreamController<UkSocketEvent>.broadcast();
  final _pending = <String, Completer<dynamic>>{};

  Stream<UkSocketEvent> get events => _events.stream;

  bool get connected => _socket?.connected ?? false;

  io.Socket get _require {
    final socket = _socket;
    if (socket == null) throw UkSocketException('Socket not initialised');
    return socket;
  }

  Future<void> connect({Duration timeout = const Duration(seconds: 15)}) async {
    if (_socket?.connected == true) return;

    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          // WebSocket first: `socket_io_client` 3.x never completes the
          // handshake over long-polling (verified against both a local
          // Kuma 2.5 container and a public instance), so polling is only a
          // fallback for networks that block the upgrade.
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .setExtraHeaders(_headers())
          .build(),
    );
    _socket = socket;

    // Kuma pushes some events with no payload at all (`setup`,
    // `loginRequired`). The emitter uses Function.apply, so the second
    // parameter has to be optional or those events throw NoSuchMethodError.
    socket.onAny((event, [dynamic data]) {
      if (event == 'connect' || event == 'disconnect') return;
      final args = data == null
          ? <dynamic>[]
          : (data is List ? List<dynamic>.from(data) : <dynamic>[data]);
      _events.add(UkSocketEvent(event, args));
    });

    final ready = Completer<void>();
    socket.onConnect((_) {
      if (!ready.isCompleted) ready.complete();
    });
    socket.onConnectError((err) {
      if (!ready.isCompleted) {
        ready.completeError(UkSocketException('Handshake rejected: $err'));
      }
    });
    socket.onError((err) {
      if (!ready.isCompleted) {
        ready.completeError(UkSocketException('Connection failed: $err'));
      }
    });

    socket.connect();
    try {
      await ready.future.timeout(timeout);
    } on TimeoutException {
      throw UkSocketException('Connection timed out');
    }
  }

  /// Emits [event] and waits for the server ack.
  Future<dynamic> ack(String event, [Object? data, Duration? timeout]) {
    final socket = _require;
    final completer = Completer<dynamic>();
    void complete(dynamic value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    _pending[event] = completer;
    try {
      if (data == null) {
        socket.emitWithAck(event, null, ack: complete);
      } else {
        socket.emitWithAck(event, data, ack: complete);
      }
    } catch (e) {
      _pending.remove(event);
      throw UkSocketException('$event failed: $e');
    }

    return completer.future
        .timeout(timeout ?? const Duration(seconds: 15))
        .whenComplete(() => _pending.remove(event));
  }

  /// Waits for the first event matching [name] within [timeout].
  Future<UkSocketEvent?> waitFor(String name, {Duration? timeout}) {
    final completer = Completer<UkSocketEvent?>();
    late StreamSubscription<UkSocketEvent> sub;
    sub = events.listen((e) {
      if (e.name == name && !completer.isCompleted) {
        completer.complete(e);
        sub.cancel();
      }
    });
    return completer.future.timeout(
      timeout ?? const Duration(seconds: 12),
      onTimeout: () => null,
    );
  }

  Map<String, String> _headers() {
    final ua = userAgent?.trim();
    if (ua == null || ua.isEmpty) return const {};
    return {'User-Agent': ua};
  }

  void dispose() {
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(UkSocketException('Socket closed'));
    }
    _pending.clear();
    if (!_events.isClosed) _events.close();
  }
}

class AdminLoginResult {
  const AdminLoginResult({
    required this.ok,
    this.token,
    this.requires2fa = false,
    this.message,
  });

  final bool ok;
  final String? token;
  final bool requires2fa;
  final String? message;
}

/// Everything one management session needs, fetched in a single burst.
class AdminData {
  AdminData({
    required this.monitors,
    required this.heartbeats,
    required this.uptime,
    required this.notifications,
    required this.statusPages,
  });

  /// Keyed by monitor id, values are the raw rows from the instance.
  final Map<int, Map<String, dynamic>> monitors;
  final Map<int, List<Map<String, dynamic>>> heartbeats;
  final Map<String, double> uptime;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> statusPages;

  int? statusPageIdForSlug(String slug) {
    for (final page in statusPages) {
      if ((page['slug'] as String?) == slug) return (page['id'] as num?)?.toInt();
    }
    return null;
  }

  int? get firstStatusPageId {
    if (statusPages.isEmpty) return null;
    return (statusPages.first['id'] as num?)?.toInt();
  }
}

/// Authenticated operations against one Uptime Kuma instance.
class UkAdmin {
  UkAdmin(this.server, {this.userAgent});

  final ServerConfig server;
  final String? userAgent;

  UkSocket? _socket;
  StreamSubscription<UkSocketEvent>? _sub;
  String _token = '';

  // Kuma only pushes `notificationList` / `statusPageList` in response to a
  // login, so the session keeps absorbing every push from the moment it
  // connects instead of waiting for one inside `fetch()`.
  final Map<int, Map<String, dynamic>> _monitors = {};
  final Map<int, List<Map<String, dynamic>>> _heartbeats = {};
  final Map<String, double> _uptime = {};
  final List<Map<String, dynamic>> _notifications = [];
  final List<Map<String, dynamic>> _statusPages = [];

  UkSocket get _s {
    final socket = _socket;
    if (socket == null) throw UkSocketException('Not signed in');
    return socket;
  }

  Future<UkSocket> _ensure() async {
    if (_socket == null || !_socket!.connected) {
      final socket = UkSocket(baseUrl: server.baseUrl, userAgent: userAgent);
      await socket.connect();
      _socket = socket;
      _sub?.cancel();
      _sub = socket.events.listen(_absorb);
    }
    return _socket!;
  }

  void _absorb(UkSocketEvent event) {
    switch (event.name) {
      case 'monitorList':
        final payload = event.first;
        if (payload is Map) {
          _monitors.clear();
          payload.forEach((key, value) {
            final id = int.tryParse(key.toString());
            if (id == null || value is! Map) return;
            _monitors[id] = value.cast<String, dynamic>();
          });
        } else if (payload is List) {
          _monitors.clear();
          for (final value in payload) {
            if (value is! Map) continue;
            final id = (value['id'] as num?)?.toInt();
            if (id == null) continue;
            _monitors[id] = value.cast<String, dynamic>();
          }
        }
      case 'heartbeatList':
        final args = event.args;
        if (args.length >= 2) {
          final id = int.tryParse(args[0].toString());
          final list = args[1];
          final overwrite = args.length >= 3 ? args[2] == true : true;
          if (id != null && list is List) {
            final rows = list
                .whereType<Map>()
                .map((h) => h.cast<String, dynamic>())
                .toList(growable: false);
            if (overwrite) {
              _heartbeats[id] = rows;
            } else {
              final merged = [...?_heartbeats[id], ...rows];
              _heartbeats[id] = merged.length > 100
                  ? merged.sublist(merged.length - 100)
                  : merged;
            }
          }
        }
      case 'uptime':
        final args = event.args;
        if (args.length >= 3) {
          final id = args[0].toString();
          final period = args[1].toString();
          final value = args[2];
          if (value is num) _uptime['${id}_$period'] = value.toDouble();
        }
      case 'notificationList':
        // `notificationList` is a plain array, `statusPageList` is keyed by id —
        // accept either shape, and either as one list argument or as spread
        // arguments (the client library makes them indistinguishable).
        _notifications
          ..clear()
          ..addAll(_rowsFrom(event.args));
      case 'statusPageList':
        _statusPages
          ..clear()
          ..addAll(_rowsFrom(event.args));
    }
  }

  /// Normalises the three shapes Kuma uses for list pushes: an array of rows,
  /// an id-keyed object of rows, or those spread across several arguments.
  static List<Map<String, dynamic>> _rowsFrom(List<dynamic> args) {
    final out = <Map<String, dynamic>>[];
    void take(Map value) {
      final row = value.cast<String, dynamic>();
      // An id-keyed collection is a wrapper, not a row.
      final looksLikeRow =
          row.containsKey('id') || row.containsKey('slug') || row.containsKey('type');
      if (looksLikeRow) {
        out.add(row);
        return;
      }
      for (final nested in row.values) {
        if (nested is Map) out.add(nested.cast<String, dynamic>());
      }
    }

    for (final arg in args) {
      if (arg is Map) {
        take(arg);
      } else if (arg is List) {
        for (final item in arg) {
          if (item is Map) take(item);
        }
      }
    }
    return out;
  }

  /// Waits until [ready] holds or [limit] elapses, so a slow instance does not
  /// make the UI spin forever and an empty instance does not stall it.
  Future<void> _settle(bool Function() ready, Duration limit) async {
    final deadline = DateTime.now().add(limit);
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  /// Signs in with a username/password pair and returns the JWT the server
  /// hands back, which we store instead of the password.
  Future<AdminLoginResult> signIn({
    required String username,
    required String password,
    String? otp,
  }) async {
    try {
      final socket = await _ensure();
      final payload = <String, dynamic>{
        'username': username,
        'password': password,
        if (otp != null && otp.isNotEmpty) 'token': otp,
      };
      final res = await socket.ack('login', payload);
      if (res is! Map) {
        return const AdminLoginResult(ok: false, message: 'Unexpected response');
      }
      if (res['ok'] == true) {
        _token = (res['token'] as String?) ?? '';
        return AdminLoginResult(ok: true, token: res['token'] as String?);
      }
      if (res['tokenRequired'] == true) {
        return const AdminLoginResult(ok: false, requires2fa: true);
      }
      return AdminLoginResult(ok: false, message: _msg(res['msg']));
    } on UkSocketException catch (e) {
      return AdminLoginResult(ok: false, message: e.message);
    } catch (e) {
      return AdminLoginResult(ok: false, message: e.toString());
    }
  }

  /// Restores a session from a stored JWT. Avoids keeping the password.
  Future<bool> resume(String token) async {
    if (token.isEmpty) return false;
    try {
      final socket = await _ensure();
      final res = await socket.ack('loginByToken', token);
      if (res is Map && res['ok'] == true) {
        _token = token;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('resume failed: $e');
      return false;
    }
  }

  /// Re-emits `loginByToken` so the server replays the lists it only sends on
  /// login (`statusPageList` in particular is not pushed after a mutation).
  Future<void> resync() async {
    if (_token.isEmpty) return;
    try {
      await _ensure();
      await _s.ack('loginByToken', _token);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('resync failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _s.ack('logout');
    } catch (_) {}
  }

  /// Pulls a fresh monitor list and hands back everything the session has
  /// absorbed so far (monitors, heartbeats, uptime, notifications, pages).
  Future<AdminData> fetch() async {
    final socket = await _ensure();

    // A fresh `getMonitorList` makes the call deterministic on a session that
    // is already signed in; the pushes that follow repopulate the caches.
    socket.ack('getMonitorList').catchError((_) => null);

    await _settle(() => _monitors.isNotEmpty, const Duration(seconds: 12));
    // Heartbeats stream one monitor at a time, behind the monitor list.
    await _settle(
      () => _monitors.isEmpty || _monitors.keys.every(_heartbeats.containsKey),
      const Duration(seconds: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return AdminData(
      monitors: Map<int, Map<String, dynamic>>.from(_monitors),
      heartbeats: Map<int, List<Map<String, dynamic>>>.from(_heartbeats),
      uptime: Map<String, double>.from(_uptime),
      notifications: List<Map<String, dynamic>>.from(_notifications),
      statusPages: List<Map<String, dynamic>>.from(_statusPages),
    );
  }

  Future<void> addMonitor(Map<String, dynamic> monitor) async {
    final res = await _s.ack('add', monitor);
    _throwIfFailed(res, 'addMonitor');
  }

  Future<void> editMonitor(Map<String, dynamic> monitor) async {
    final res = await _s.ack('editMonitor', monitor);
    _throwIfFailed(res, 'editMonitor');
  }

  /// Kuma's handler is `deleteMonitor(monitorID, deleteChildren, callback)`, so
  /// the second argument has to be present or the server binds the ack to it
  /// and never answers.
  Future<void> deleteMonitor(int id, {bool deleteChildren = false}) async {
    final res = await _s.ack('deleteMonitor', [id, deleteChildren]);
    _throwIfFailed(res, 'deleteMonitor');
  }

  Future<void> setMonitorActive(int id, bool active) async {
    final res = await _s.ack(active ? 'resumeMonitor' : 'pauseMonitor', id);
    _throwIfFailed(res, active ? 'resumeMonitor' : 'pauseMonitor');
  }

  /// `addNotification(notification, notificationID, callback)` — pass a null id
  /// to create, an existing id to update.
  Future<void> addNotification(Map<String, dynamic> notification, {int? id}) async {
    final res = await _s.ack('addNotification', [notification, id]);
    _throwIfFailed(res, 'addNotification');
  }

  Future<void> deleteNotification(int id) async {
    final res = await _s.ack('deleteNotification', id);
    _throwIfFailed(res, 'deleteNotification');
  }

  /// The server wants the whole notification object, not its id: it re-reads
  /// the provider config from the payload before firing.
  Future<void> testNotification(Map<String, dynamic> notification) async {
    final res = await _s.ack('testNotification', notification);
    _throwIfFailed(res, 'testNotification');
  }

  Future<void> clearEvents(int monitorId) async {
    final res = await _s.ack('clearEvents', monitorId);
    _throwIfFailed(res, 'clearEvents');
  }

  /// `addStatusPage(title, slug, callback)` — creates the page with Kuma's
  /// defaults; monitors are assigned to it from the web UI afterwards.
  Future<void> addStatusPage({required String title, required String slug}) async {
    final res = await _s.ack('addStatusPage', [title, slug]);
    _throwIfFailed(res, 'addStatusPage');
    // The server creates the page but never re-pushes the list.
    await resync();
  }

  /// Incidents are addressed by status-page **slug** in Kuma 2.x, and the
  /// server always pins what it receives (`pin = 1`), so there is no flag to
  /// send. Pass [id] to edit an existing incident.
  Future<void> postIncident({
    required String slug,
    required String title,
    required String content,
    required String style,
    int? id,
  }) async {
    final res = await _s.ack('postIncident', [
      slug,
      {
        'title': title,
        'content': content,
        'style': style,
        // Null-aware element: omitted entirely when editing is not intended.
        'id': ?id,
      },
    ]);
    _throwIfFailed(res, 'postIncident');
  }

  /// Clears every pinned incident on the page.
  Future<void> unpinIncident(String slug) async {
    final res = await _s.ack('unpinIncident', slug);
    _throwIfFailed(res, 'unpinIncident');
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _socket?.dispose();
    _socket = null;
    _monitors.clear();
    _heartbeats.clear();
    _uptime.clear();
    _notifications.clear();
    _statusPages.clear();
  }

  static void _throwIfFailed(dynamic res, String action) {
    if (res is Map && res['ok'] == false) {
      throw UkSocketException(_msg(res['msg']) ?? '$action failed');
    }
    if (res == null) throw UkSocketException('$action: no response');
  }

  static String? _msg(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString();
    // Uptime Kuma sends i18n keys like `authIncorrectCreds`.
    switch (text) {
      case 'authIncorrectCreds':
        return 'Incorrect username or password';
      case 'authInvalidToken':
        return 'Session expired, please sign in again';
      case 'authUserInactiveOrDeleted':
        return 'Account disabled or removed';
      case 'Permission denied.':
        return 'Permission denied';
      default:
        return text;
    }
  }
}
