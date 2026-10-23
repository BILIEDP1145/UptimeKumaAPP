import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// DNS-over-HTTPS resolver used when the user turns the privacy switch on.
///
/// Only the name lookup is tunnelled; the actual connection still goes to the
/// resolved address with the original hostname for SNI, so certificate
/// validation keeps working.
///
/// The endpoint is user-configurable — any JSON API that accepts
/// `?name=<host>&type=A` works (Cloudflare, Google, AdGuard Home, a
/// self-hosted resolver listening on a custom port).
class DohResolver {
  DohResolver._();

  /// Used when the user has not entered a custom endpoint.
  static const List<String> defaults = [
    'https://cloudflare-dns.com/dns-query',
    'https://dns.google/dns-query',
  ];

  /// Cache keyed by `endpoint|host`, so switching resolvers never serves stale
  /// answers from the previous one.
  static final Map<String, String> _cache = {};

  static String? cached(String host, {String? endpoint}) {
    final target = endpointTargets(endpoint).first;
    return _cache['$target|$host'];
  }

  /// Drops every cached answer — call it whenever the endpoint changes.
  static void clearCache() => _cache.clear();

  /// Endpoints to try, in order. A custom endpoint is used exclusively: a typo
  /// must fail loudly rather than silently fall back to another provider.
  static List<String> endpointTargets(String? endpoint) {
    final custom = endpoint?.trim() ?? '';
    return custom.isEmpty ? defaults : [custom];
  }

  /// Normalises whatever the user typed into a query URL.
  ///
  /// Accepts `https://host/dns-query`, `host:8443/dns-query`, a bare host, or a
  /// full query URL; existing query parameters are preserved.
  /// Which wire format worked last time, per endpoint. RFC 8484 is the
  /// standard; the `?name=` JSON API is a Cloudflare/Google extension that many
  /// self-hosted resolvers simply do not implement (they answer 400).
  static final Map<String, bool> _jsonWorks = {};

  /// Resolves [host] to an address literal.
  ///
  /// Tries the RFC 8484 `dns=` wire format first, then the JSON API, and
  /// remembers which one the endpoint accepted.
  ///
  /// Returns [host] unchanged when every endpoint fails, so a broken DoH server
  /// degrades to the platform resolver instead of taking the app offline.
  static Future<String> resolve(String host, {String? endpoint}) async {
    final targets = endpointTargets(endpoint);
    final key = '${targets.first}|$host';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_isIpLiteral(host)) return host;

    Object? lastError;
    for (final target in targets) {
      // Try A then AAAA: some resolvers publish only one family.
      for (final type in const [1, 28]) {
        try {
          final address = await _query(target, host, type);
          if (address != null) {
            _cache[key] = address;
            return address;
          }
        } catch (e) {
          lastError = e;
        }
      }
    }
    if (lastError != null) {
      debugPrint('DoH lookup failed for $host via ${targets.first}: $lastError');
    }
    return host;
  }

  static Future<String?> _query(String endpoint, String host, int type) async {
    final preferJson = _jsonWorks[endpoint] ?? false;

    if (!preferJson) {
      final address = await _queryWireformat(endpoint, host, type);
      if (address != null) {
        _jsonWorks[endpoint] = false;
        return address;
      }
    }

    final json = await _queryJson(endpoint, host, type);
    if (json != null) {
      _jsonWorks[endpoint] = true;
      return json;
    }

    if (preferJson) {
      // The remembered format suddenly failed; fall back once.
      final address = await _queryWireformat(endpoint, host, type);
      if (address != null) {
        _jsonWorks[endpoint] = false;
        return address;
      }
    }
    return null;
  }

  /// RFC 8484: `GET …/dns-query?dns=<base64url(wireformat)>`, response is a
  /// binary `application/dns-message`.
  static Future<String?> _queryWireformat(
    String endpoint,
    String host,
    int type,
  ) async {
    final query = _buildQuery(host, type);
    final base = _baseUri(endpoint);
    final url = base.replace(queryParameters: {
      ...base.queryParameters,
      'dns': base64Url.encode(query).replaceAll('=', ''),
    });

    final res = await http
        .get(url, headers: const {'Accept': 'application/dns-message'})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
    // A JSON error body served with 200 must not be parsed as a DNS message.
    final contentType = res.headers['content-type'] ?? '';
    if (contentType.contains('json')) return null;
    return _parseAnswers(res.bodyBytes);
  }

  static Future<String?> _queryJson(
    String endpoint,
    String host,
    int type,
  ) async {
    final base = _baseUri(endpoint);
    final url = base.replace(queryParameters: {
      ...base.queryParameters,
      'name': host,
      'type': type == 1 ? 'A' : 'AAAA',
    });

    final res = await http
        .get(url, headers: const {'Accept': 'application/dns-json'})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final answers = (body is Map ? body['Answer'] : null) as List?;
    if (answers == null) return null;
    for (final a in answers) {
      if (a is Map && a['type'] == type) {
        final data = a['data'] as String?;
        if (data != null && data.isNotEmpty) return data;
      }
    }
    return null;
  }

  /// Normalises an endpoint into a base URI without query parameters.
  static Uri _baseUri(String endpoint) {
    var raw = endpoint.trim();
    if (raw.isEmpty) raw = defaults.first;
    if (!raw.contains('://')) raw = 'https://$raw';
    final parsed = Uri.parse(raw);
    var path = parsed.path;
    // RFC 8484 servers live at `/dns-query`; a bare host would answer 400, and
    // so does a trailing slash on AliDNS / doh.pub.
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty || path == '/') path = '/dns-query';
    return parsed.replace(path: path, queryParameters: const {});
  }

  /// One-shot check used by the settings page: does this endpoint answer at
  /// all, and with what status? Reporting the HTTP code is the difference
  /// between "it doesn't work" and knowing it answered 400.
  static Future<({bool ok, String? address, int? status, String? error})> probe(
    String endpoint, {
    String host = 'example.com',
  }) async {
    final base = _baseUri(endpoint);
    try {
      final query = _buildQuery(host, 1);
      final url = base.replace(queryParameters: {
        ...base.queryParameters,
        'dns': base64Url.encode(query).replaceAll('=', ''),
      });
      final res = await http
          .get(url, headers: const {'Accept': 'application/dns-message'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return (ok: false, address: null, status: res.statusCode, error: null);
      }
      final address = _parseAnswers(res.bodyBytes);
      if (address != null) {
        return (ok: true, address: address, status: 200, error: null);
      }
      final json = await _queryJson(endpoint, host, 1);
      return (
        ok: json != null,
        address: json,
        status: 200,
        error: json == null ? 'unreadable response' : null,
      );
    } catch (e) {
      return (ok: false, address: null, status: null, error: e.toString());
    }
  }

  /// Minimal DNS query: one question, recursion desired.
  static Uint8List _buildQuery(String host, int type) {
    final builder = BytesBuilder();
    final id = DateTime.now().microsecondsSinceEpoch & 0xFFFF;
    builder.add([id >> 8 & 0xFF, id & 0xFF]);
    builder.add([0x01, 0x00]); // flags: RD
    builder.add([0x00, 0x01]); // QDCOUNT
    builder.add([0x00, 0x00]); // ANCOUNT
    builder.add([0x00, 0x00]); // NSCOUNT
    builder.add([0x00, 0x00]); // ARCOUNT
    for (final label in host.split('.')) {
      if (label.isEmpty) continue;
      final bytes = utf8.encode(label);
      if (bytes.length > 63) return Uint8List(0);
      builder.addByte(bytes.length);
      builder.add(bytes);
    }
    builder.addByte(0);
    builder.add([type >> 8 & 0xFF, type & 0xFF]);
    builder.add([0x00, 0x01]); // IN
    return builder.toBytes();
  }

  /// Walks the answer section and returns the first A/AAAA record.
  static String? _parseAnswers(Uint8List data) {
    if (data.length < 12) return null;
    final qdCount = data[4] << 8 | data[5];
    final anCount = data[6] << 8 | data[7];
    if (anCount == 0) return null;

    var offset = 12;
    for (var i = 0; i < qdCount; i++) {
      offset = _skipName(data, offset) + 4;
      if (offset > data.length) return null;
    }

    String? found;
    for (var i = 0; i < anCount; i++) {
      offset = _skipName(data, offset);
      if (offset + 10 > data.length) return null;
      final type = data[offset] << 8 | data[offset + 1];
      final rdLength = data[offset + 8] << 8 | data[offset + 9];
      offset += 10;
      if (offset + rdLength > data.length) return null;

      if (type == 1 && rdLength == 4) {
        found ??= '${data[offset]}.${data[offset + 1]}.'
            '${data[offset + 2]}.${data[offset + 3]}';
      } else if (type == 28 && rdLength == 16) {
        final parts = <String>[];
        for (var j = 0; j < 16; j += 2) {
          parts.add(((data[offset + j] << 8) | data[offset + j + 1])
              .toRadixString(16));
        }
        found ??= parts.join(':');
      }
      offset += rdLength;
    }
    return found;
  }

  /// Skips a (possibly compressed) domain name.
  static int _skipName(Uint8List data, int offset) {
    while (offset < data.length) {
      final length = data[offset];
      if (length == 0) return offset + 1;
      if (length & 0xC0 == 0xC0) return offset + 2;
      offset += 1 + length;
    }
    return offset;
  }

  static bool _isIpLiteral(String host) {
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    return ipv4.hasMatch(host) || host.contains(':');
  }
}

/// Builds the HTTP client used for every status-page / metrics request,
/// honouring the user's DoH and User-Agent preferences.
class UkHttp {
  UkHttp._();

  static const String defaultUserAgent = 'UptimeKumaMobile/1.1 (Flutter; Android)';

  /// Long-lived clients keyed by the settings that affect them. Reusing the
  /// connection pool avoids a full TLS handshake for every small request (an
  /// instance logo is a few KB; the handshake dominated the wait).
  static final Map<String, http.Client> _shared = {};

  static http.Client shared({
    required bool doh,
    String? userAgent,
    String? dohEndpoint,
  }) {
    final key = '$doh|${userAgent ?? ''}|${dohEndpoint ?? ''}';
    return _shared.putIfAbsent(
      key,
      () => build(doh: doh, userAgent: userAgent, dohEndpoint: dohEndpoint),
    );
  }

  /// Drops every pooled client — call it when DoH / UA settings change.
  static void resetShared() {
    for (final client in _shared.values) {
      try {
        client.close();
      } catch (_) {}
    }
    _shared.clear();
  }

  static http.Client build({
    required bool doh,
    String? userAgent,
    String? dohEndpoint,
  }) {
    final inner = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = (userAgent == null || userAgent.trim().isEmpty)
          ? defaultUserAgent
          : userAgent.trim();

    if (doh) {
      inner.connectionFactory = (uri, proxyHost, proxyPort) async {
        final address = await DohResolver.resolve(uri.host, endpoint: dohEndpoint);
        final port = uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port;

        if (uri.scheme != 'https') {
          return Socket.startConnect(address, port);
        }

        // A `connectionFactory` socket is used **as-is**: HttpClient does not
        // wrap it in TLS. Returning a plain socket here sent unencrypted HTTP to
        // port 443, and Cloudflare answered
        // "400 The plain HTTP request was sent to HTTPS port".
        // So the TLS handshake happens here, with the real hostname as SNI —
        // which is also what keeps virtual hosting and certificate checks
        // working when we connect to an IP we resolved ourselves.
        final raw = await Socket.connect(address, port);
        final secure = await SecureSocket.secure(raw, host: uri.host);
        return ConnectionTask.fromSocket(Future<Socket>.value(secure), () {});
      };
    }

    return IOClient(inner);
  }
}
