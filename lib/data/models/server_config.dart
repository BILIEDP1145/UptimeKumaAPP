import 'dart:convert';

/// How the app is allowed to talk to one instance.
///
/// * [monitor] – public status page only, read-only.
/// * [manage]  – authenticated Socket.IO session, full CRUD.
enum ServerMode {
  monitor,
  manage;

  static ServerMode fromName(String? raw) =>
      raw == manage.name ? manage : monitor;
}

/// A single self-hosted Uptime Kuma instance the user monitors.
class ServerConfig {
  const ServerConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.slug = '',
    this.mode = ServerMode.monitor,
    this.apiKey = '',
    this.username = '',
    this.token = '',
    this.colorTag = 'terminal',
    this.collectionId,
    this.collectionName,
  });

  final String id;
  final String name;

  /// Origin only, e.g. `https://status.example.com`.
  final String baseUrl;

  /// Public status page slug. Empty when the instance has no published page.
  final String slug;

  final ServerMode mode;

  /// Uptime Kuma API key (`uk1_…`). Only unlocks `/metrics`, kept for
  /// diagnostics and per-monitor metrics.
  final String apiKey;

  /// Account used for the Socket.IO session. The password itself is never
  /// persisted — only the JWT handed back by `login`.
  final String username;
  final String token;

  /// Accent palette id used as a per-instance visual tag.
  final String colorTag;

  /// Instances sharing this id are shown as one merged status page on the
  /// phone. It is app-local bookkeeping — nothing is written to the server, so
  /// the web UI never notices.
  final String? collectionId;

  /// Display name of that collection, stored on every member for redundancy.
  final String? collectionName;

  bool get inCollection => collectionId != null && collectionId!.isNotEmpty;

  bool get isManage => mode == ServerMode.manage;

  bool get hasPublicPage => slug.isNotEmpty;

  bool get hasSession => token.isNotEmpty;

  String get statusPageUrl => '$baseUrl/status/$slug';

  String get configEndpoint => '$baseUrl/api/status-page/$slug';

  String get heartbeatEndpoint => '$baseUrl/api/status-page/heartbeat/$slug';

  String get metricsEndpoint => '$baseUrl/metrics';

  /// Resolves a possibly server-relative asset path against the instance.
  String? resolveAsset(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:')) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return value.startsWith('/') ? '$baseUrl$value' : '$baseUrl/$value';
  }

  String get displayHost {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return baseUrl;
    return uri.host.isEmpty ? baseUrl : uri.host;
  }

  ServerConfig copyWith({
    String? name,
    String? baseUrl,
    String? slug,
    ServerMode? mode,
    String? apiKey,
    String? username,
    String? token,
    String? colorTag,
    String? collectionId,
    String? collectionName,
    bool clearCollection = false,
  }) {
    return ServerConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      slug: slug ?? this.slug,
      mode: mode ?? this.mode,
      apiKey: apiKey ?? this.apiKey,
      username: username ?? this.username,
      token: token ?? this.token,
      colorTag: colorTag ?? this.colorTag,
      collectionId: clearCollection ? null : (collectionId ?? this.collectionId),
      collectionName: clearCollection ? null : (collectionName ?? this.collectionName),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'slug': slug,
        'mode': mode.name,
        'apiKey': apiKey,
        'username': username,
        'token': token,
        'colorTag': colorTag,
        if (collectionId != null) 'collectionId': collectionId,
        if (collectionName != null) 'collectionName': collectionName,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Uptime Kuma',
        baseUrl: json['baseUrl'] as String,
        slug: (json['slug'] as String?) ?? '',
        mode: ServerMode.fromName(json['mode'] as String?),
        apiKey: (json['apiKey'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        token: (json['token'] as String?) ?? '',
        colorTag: (json['colorTag'] as String?) ?? 'terminal',
        collectionId: json['collectionId'] as String?,
        collectionName: json['collectionName'] as String?,
      );

  /// Accepts a bare origin, an origin with a path, or a full
  /// `.../status/<slug>` URL and splits it into origin + slug.
  static ({String baseUrl, String slug}) parseInput(String raw, {String? slugOverride}) {
    var value = raw.trim();
    if (value.isEmpty) return (baseUrl: '', slug: slugOverride?.trim() ?? '');

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final uri = Uri.parse(value);
    var origin = '${uri.scheme}://${uri.host}';
    if (uri.hasPort) origin = '$origin:${uri.port}';

    var slug = slugOverride?.trim() ?? '';
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (slug.isEmpty && segments.length >= 2 && segments[segments.length - 2] == 'status') {
      slug = segments.last;
    }
    if (slug.isEmpty && segments.isNotEmpty) {
      slug = segments.last;
    }

    return (baseUrl: origin, slug: slug);
  }

  static String encodeList(List<ServerConfig> servers) =>
      jsonEncode(servers.map((s) => s.toJson()).toList());

  static List<ServerConfig> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ServerConfig.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
