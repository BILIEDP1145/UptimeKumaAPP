import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/server_config.dart';
import '../models/status_page.dart';
import '../net/uk_http.dart';

class UkApiException implements Exception {
  UkApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'UkApiException($statusCode): $message';
}

class ProbeResult {
  const ProbeResult({
    required this.ok,
    this.title,
    this.monitorCount = 0,
    this.message,
  });

  final bool ok;
  final String? title;
  final int monitorCount;
  final String? message;
}

/// Talks to the public status-page endpoints of an Uptime Kuma instance.
///
/// Only read endpoints are used, so no credentials ever leave the device.
class UkApi {
  UkApi({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    bool doh = false,
    String? dohEndpoint,
    String? userAgent,
  })  : _client = client ??
            UkHttp.build(doh: doh, userAgent: userAgent, dohEndpoint: dohEndpoint),
        _userAgent = (userAgent == null || userAgent.trim().isEmpty)
            ? UkHttp.defaultUserAgent
            : userAgent.trim();

  final http.Client _client;
  final Duration timeout;
  final String _userAgent;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      };

  Future<Map<String, dynamic>> _getJson(String url) async {
    http.Response res;
    try {
      res = await _client.get(Uri.parse(url), headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw UkApiException('Request timed out');
    } on SocketException catch (e) {
      throw UkApiException('Network unreachable: ${e.message}');
    } on http.ClientException catch (e) {
      throw UkApiException(e.message);
    } on HandshakeException {
      throw UkApiException('TLS handshake failed');
    }

    if (res.statusCode != 200) {
      throw UkApiException('HTTP ${res.statusCode}', statusCode: res.statusCode);
    }
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      throw UkApiException('Unexpected payload');
    } on FormatException {
      throw UkApiException('Response was not JSON');
    }
  }

  /// Fetches config + heartbeats and merges them into one snapshot.
  Future<StatusSnapshot> fetchSnapshot(ServerConfig server) async {
    final configFuture = _getJson(server.configEndpoint);
    final heartbeatFuture = _getJson(server.heartbeatEndpoint);

    final results = await Future.wait([configFuture, heartbeatFuture]);
    final configJson = results[0];
    final heartbeat = results[1];

    final configRaw = (configJson['config'] as Map?)?.cast<String, dynamic>();
    if (configRaw == null) {
      throw UkApiException('Missing config — check the status page slug');
    }
    if (configRaw['published'] == false) {
      throw UkApiException('Status page is not published');
    }

    final groupsJson = (configJson['publicGroupList'] as List?) ?? const [];
    final groups = groupsJson
        .whereType<Map>()
        .map((g) => MonitorGroup.fromJson(g.cast<String, dynamic>()))
        .toList(growable: false);

    final hbRaw = (heartbeat['heartbeatList'] as Map?) ?? const {};
    final heartbeats = <int, List<Heartbeat>>{};
    hbRaw.forEach((key, value) {
      final id = int.tryParse(key.toString());
      if (id == null) return;
      final list = (value as List?) ?? const [];
      heartbeats[id] = list
          .whereType<Map>()
          .map((h) => Heartbeat.fromJson(h.cast<String, dynamic>()))
          .toList(growable: false);
    });

    final uptimeRaw = (heartbeat['uptimeList'] as Map?) ?? const {};
    final uptime = <String, double>{};
    uptimeRaw.forEach((key, value) {
      if (value is num) uptime[key.toString()] = value.toDouble();
    });

    final incidentRaw = configJson['incident'];
    final maintRaw = (configJson['maintenanceList'] as List?) ?? const [];

    return StatusSnapshot(
      config: StatusPageConfig.fromJson(configRaw),
      groups: groups,
      heartbeats: heartbeats,
      uptime: uptime,
      incident: incidentRaw is Map
          ? Incident.fromJson(incidentRaw.cast<String, dynamic>())
          : null,
      maintenances: maintRaw
          .whereType<Map>()
          .map((m) => MaintenanceWindow.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      fetchedAt: DateTime.now(),
    );
  }

  /// Validates an instance before it is saved.
  Future<ProbeResult> probe(ServerConfig server) async {
    try {
      final snapshot = await fetchSnapshot(server);
      return ProbeResult(
        ok: true,
        title: snapshot.config.title,
        monitorCount: snapshot.allMonitors.length,
      );
    } on UkApiException catch (e) {
      return ProbeResult(ok: false, message: e.message);
    } catch (e) {
      return ProbeResult(ok: false, message: e.toString());
    }
  }

  void dispose() => _client.close();
}
