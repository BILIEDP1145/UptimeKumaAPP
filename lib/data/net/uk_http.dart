import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    'https://dns.google/resolve',
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
  static Uri queryUri(String endpoint, String host) {
    var raw = endpoint.trim();
    if (raw.isEmpty) raw = defaults.first;
    if (!raw.contains('://')) raw = 'https://$raw';
    final base = Uri.parse(raw);
    final params = <String, String>{...base.queryParameters}
      ..['name'] = host
      ..['type'] = 'A';
    return base.replace(queryParameters: params);
  }

  /// Resolves [host] to an address literal.
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
      try {
        final res = await http
            .get(
              queryUri(target, host),
              headers: const {'Accept': 'application/dns-json'},
            )
            .timeout(const Duration(seconds: 6));
        if (res.statusCode != 200) continue;
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final answers = (body is Map ? body['Answer'] : null) as List?;
        if (answers == null) continue;
        for (final a in answers) {
          if (a is Map && (a['type'] == 1 || a['type'] == 28)) {
            final data = a['data'] as String?;
            if (data != null && data.isNotEmpty) {
              _cache[key] = data;
              return data;
            }
          }
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      debugPrint('DoH lookup failed for $host via ${targets.first}: $lastError');
    }
    return host;
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
        return Socket.startConnect(address, port);
      };
    }

    return IOClient(inner);
  }
}
