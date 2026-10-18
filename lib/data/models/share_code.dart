import 'dart:convert';

import 'server_config.dart';

/// Result of decoding a share string: one instance or a whole collection.
class SharePayload {
  const SharePayload({required this.servers, this.collectionName});

  final List<ServerConfig> servers;
  final String? collectionName;

  bool get isCollection => collectionName != null;
}

/// Encodes instances as `uptimekuma://…` strings so a configuration can be
/// moved between phones by pasting text.
///
/// Format (base64url, no padding, so it survives chat apps):
///
/// ```
/// uptimekuma://instance/<base64url({"v":1,"type":"instance",...})>
/// uptimekuma://collection/<base64url({"v":1,"type":"collection",...})>
/// ```
///
/// Credentials are deliberately left out: the API key and the session JWT never
/// appear in a share string, so a leaked clipboard cannot grant management
/// access. Imported management instances ask for a password again.
class ShareCode {
  ShareCode._();

  static const String scheme = 'uptimekuma';
  static const String instanceHost = 'instance';
  static const String collectionHost = 'collection';

  static String forInstance(ServerConfig server, {String? collectionName}) {
    final body = <String, dynamic>{
      'v': 1,
      'type': 'instance',
      'name': server.name,
      'url': server.baseUrl,
      'slug': server.slug,
      'mode': server.mode.name,
      'color': server.colorTag,
      if (collectionName != null && collectionName.isNotEmpty)
        'collection': collectionName,
    };
    return '$scheme://$instanceHost/${_encode(body)}';
  }

  static String forCollection(String name, List<ServerConfig> servers) {
    final body = <String, dynamic>{
      'v': 1,
      'type': 'collection',
      'name': name,
      'instances': [
        for (final server in servers)
          {
            'name': server.name,
            'url': server.baseUrl,
            'slug': server.slug,
            'mode': server.mode.name,
            'color': server.colorTag,
          },
      ],
    };
    return '$scheme://$collectionHost/${_encode(body)}';
  }

  /// Parses a share string. Returns null when the text is not one of ours or is
  /// structurally broken; the caller shows a friendly error.
  static SharePayload? parse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    String? kind;
    String? payload;
    final uri = Uri.tryParse(text);
    if (uri != null && uri.scheme == scheme) {
      kind = uri.host;
      payload = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    } else {
      // Tolerate a bare payload pasted without the scheme.
      payload = text;
    }
    if (payload.isEmpty) return null;

    final decoded = _decode(payload);
    if (decoded == null) return null;

    final type = (decoded['type'] as String?) ?? kind;
    if (type == 'instance') {
      final server = _server(decoded);
      if (server == null) return null;
      final collection = (decoded['collection'] as String?)?.trim() ?? '';
      return SharePayload(
        servers: [server],
        collectionName: collection.isEmpty ? null : collection,
      );
    }
    if (type == 'collection') {
      final list = decoded['instances'];
      if (list is! List || list.isEmpty) return null;
      final servers = <ServerConfig>[];
      for (final item in list) {
        if (item is! Map) continue;
        final server = _server(item.cast<String, dynamic>());
        if (server != null) servers.add(server);
      }
      if (servers.isEmpty) return null;
      final name = (decoded['name'] as String?)?.trim() ?? '';
      return SharePayload(
        servers: servers,
        collectionName: name.isEmpty ? 'Imported' : name,
      );
    }
    return null;
  }

  static String _encode(Map<String, dynamic> body) =>
      base64Url.encode(utf8.encode(jsonEncode(body))).replaceAll('=', '');

  static Map<String, dynamic>? _decode(String payload) {
    try {
      final padded = payload.padRight((payload.length + 3) & ~3, '=');
      final bytes = base64Url.decode(padded);
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  static ServerConfig? _server(Map<String, dynamic> json) {
    final url = (json['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) return null;
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme) return null;
    final name = (json['name'] as String?)?.trim();
    return ServerConfig(
      id: DateTime.now().microsecondsSinceEpoch.toString() +
          (json['name'] as String? ?? '').hashCode.toString(),
      name: (name == null || name.isEmpty) ? parsed.host : name,
      baseUrl: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
      slug: (json['slug'] as String?)?.trim() ?? '',
      mode: ServerMode.fromName(json['mode'] as String?),
      colorTag: (json['color'] as String?) ?? 'terminal',
    );
  }
}
