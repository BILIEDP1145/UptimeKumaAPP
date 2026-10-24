import 'dart:convert';

/// Monitor types this app can create and edit.
enum MonitorKind {
  http('http', 'HTTP(s)', 'HTTP(s)'),
  keyword('keyword', 'Keyword', '关键词'),
  tcp('tcp', 'TCP port', 'TCP 端口'),
  port('port', 'Port (host)', '端口探测'),
  ping('ping', 'Ping', 'Ping'),
  dns('dns', 'DNS', 'DNS'),
  group('group', 'Group', '分组');

  const MonitorKind(this.id, this.labelEn, this.labelZh);

  final String id;
  final String labelEn;
  final String labelZh;

  String label(bool zh) => zh ? labelZh : labelEn;

  bool get needsUrl => this == http || this == keyword;

  bool get needsHostname =>
      this == tcp || this == port || this == ping || this == dns;

  bool get needsPort => this == tcp || this == port;

  bool get isGroup => this == group;

  static MonitorKind fromId(String? id) =>
      values.firstWhere((k) => k.id == id, orElse: () => http);
}

/// Editable shape of one monitor. Keeps every field the instance round-trips,
/// so editing never silently drops configuration.
class MonitorDraft {
  MonitorDraft({
    this.id,
    this.kind = MonitorKind.http,
    this.name = '',
    this.url = '',
    this.hostname = '',
    this.port,
    this.method = 'GET',
    this.interval = 60,
    this.retryInterval = 60,
    this.maxretries = 0,
    this.timeout = 48,
    this.active = true,
    this.upsideDown = false,
    this.acceptedCodes = const ['200-299'],
    this.keyword = '',
    this.invertKeyword = false,
    this.parent,
    this.description = '',
    this.notificationIds = const [],
    this.dnsResolveType = 'A',
    this.dnsResolveServer = '1.1.1.1',
    this.raw = const {},
  });

  final int? id;
  MonitorKind kind;
  String name;
  String url;
  String hostname;
  int? port;
  String method;
  int interval;
  int retryInterval;
  int maxretries;
  int timeout;
  bool active;
  bool upsideDown;
  List<String> acceptedCodes;
  String keyword;
  bool invertKeyword;
  int? parent;
  String description;
  List<int> notificationIds;
  String dnsResolveType;
  String dnsResolveServer;

  /// Original row, used to preserve fields the form does not expose.
  final Map<String, dynamic> raw;

  bool get isNew => id == null;

  factory MonitorDraft.fromRow(Map<String, dynamic> row) {
    List<String> codes = const ['200-299'];
    final rawCodes = row['accepted_statuscodes_json'] ?? row['accepted_statuscodes'];
    if (rawCodes is String && rawCodes.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCodes);
        if (decoded is List) codes = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    } else if (rawCodes is List) {
      codes = rawCodes.map((e) => e.toString()).toList();
    }

    final notify = <int>[];
    final rawNotify = row['notificationIDList'];
    if (rawNotify is Map) {
      rawNotify.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null && value == true) notify.add(id);
      });
    } else if (rawNotify is List) {
      for (final id in rawNotify) {
        final parsed = int.tryParse(id.toString());
        if (parsed != null) notify.add(parsed);
      }
    }

    return MonitorDraft(
      id: (row['id'] as num?)?.toInt(),
      kind: MonitorKind.fromId(row['type'] as String?),
      name: (row['name'] as String?) ?? '',
      url: (row['url'] as String?) ?? '',
      hostname: (row['hostname'] as String?) ?? '',
      port: (row['port'] as num?)?.toInt(),
      method: (row['method'] as String?) ?? 'GET',
      interval: (row['interval'] as num?)?.toInt() ?? 60,
      retryInterval: (row['retryInterval'] as num?)?.toInt() ?? 60,
      maxretries: (row['maxretries'] as num?)?.toInt() ?? 0,
      timeout: (row['timeout'] as num?)?.toInt() ?? 48,
      active: _asBool(row['active'], fallback: true),
      upsideDown: _asBool(row['upsideDown']),
      acceptedCodes: codes,
      keyword: (row['keyword'] as String?) ?? '',
      invertKeyword: _asBool(row['invertKeyword']),
      parent: (row['parent'] as num?)?.toInt(),
      description: (row['description'] as String?) ?? '',
      notificationIds: notify,
      dnsResolveType: (row['dns_resolve_type'] as String?) ?? 'A',
      dnsResolveServer: (row['dns_resolve_server'] as String?) ?? '1.1.1.1',
      raw: Map<String, dynamic>.from(row),
    );
  }

  /// Builds the payload for `add` / `editMonitor`.
  ///
  /// **Whitelist only.** Spreading the raw row back at the server looked
  /// harmless and broke on older Kuma: a 1.x `monitor` table has no `conditions`
  /// column, so the insert died with
  /// `SQLITE_ERROR: table monitor has no column named conditions`.
  /// Kuma 2.x fields (`conditions`, Kafka/RabbitMQ options, `resendInterval`)
  /// must not be sent to a server that predates them.
  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'name': name.trim(),
      'type': kind.id,
      'interval': interval,
      'retryInterval': retryInterval,
      'maxretries': maxretries,
      'timeout': timeout,
      'active': active ? 1 : 0,
      'upsideDown': upsideDown ? 1 : 0,
      'description': description,
      'parent': parent,
      'notificationIDList': {for (final nid in notificationIds) '$nid': true},
      'accepted_statuscodes': kind == MonitorKind.http || kind == MonitorKind.keyword
          ? acceptedCodes
          : const ['200-299'],
    };

    switch (kind) {
      case MonitorKind.http:
      case MonitorKind.keyword:
        payload['url'] = url.trim();
        payload['method'] = method;
        if (kind == MonitorKind.keyword) {
          payload['keyword'] = keyword;
          payload['invertKeyword'] = invertKeyword ? 1 : 0;
        }
      case MonitorKind.tcp:
      case MonitorKind.port:
        payload['hostname'] = hostname.trim();
        payload['port'] = port ?? 80;
      case MonitorKind.ping:
        payload['hostname'] = hostname.trim();
      case MonitorKind.dns:
        payload['hostname'] = hostname.trim();
        payload['dns_resolve_type'] = dnsResolveType;
        payload['dns_resolve_server'] = dnsResolveServer;
      case MonitorKind.group:
        payload['url'] = '';
        payload['hostname'] = '';
    }

    return payload;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == '1' || value.toString() == 'true';
  }
}

/// Human-readable view over a raw monitor row from `monitorList`.
class AdminMonitor {
  AdminMonitor(this.raw);

  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num?)?.toInt() ?? 0;

  String get name => (raw['name'] as String?) ?? '—';

  MonitorKind get kind => MonitorKind.fromId(raw['type'] as String?);

  bool get active => MonitorDraft._asBool(raw['active'], fallback: true);

  bool get upsideDown => MonitorDraft._asBool(raw['upsideDown']);

  int? get parent {
    final v = (raw['parent'] as num?)?.toInt();
    return v == 0 ? null : v;
  }

  int get interval => (raw['interval'] as num?)?.toInt() ?? 60;

  String get target {
    switch (kind) {
      case MonitorKind.http:
      case MonitorKind.keyword:
        return (raw['url'] as String?) ?? '';
      case MonitorKind.tcp:
      case MonitorKind.port:
        final host = (raw['hostname'] as String?) ?? '';
        final port = (raw['port'] as num?)?.toInt();
        return port == null ? host : '$host:$port';
      default:
        return (raw['hostname'] as String?) ?? '';
    }
  }

  List<int> get notificationIds {
    final raw = this.raw['notificationIDList'];
    final out = <int>[];
    if (raw is Map) {
      raw.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null && value == true) out.add(id);
      });
    }
    return out;
  }
}

/// One configurable field of a notification provider.
class NotificationField {
  const NotificationField({
    required this.key,
    required this.labelEn,
    required this.labelZh,
    this.secret = false,
    this.required = false,
    this.hint,
  });

  final String key;
  final String labelEn;
  final String labelZh;
  final bool secret;
  final bool required;
  final String? hint;

  String label(bool zh) => zh ? labelZh : labelEn;
}

/// A notification provider the app can create from the phone.
class NotificationProviderSpec {
  const NotificationProviderSpec({
    required this.type,
    required this.labelEn,
    required this.labelZh,
    required this.fields,
    this.defaults = const {},
  });

  final String type;
  final String labelEn;
  final String labelZh;
  final List<NotificationField> fields;
  final Map<String, dynamic> defaults;

  String label(bool zh) => zh ? labelZh : labelEn;

  static const List<NotificationProviderSpec> all = [
    NotificationProviderSpec(
      type: 'telegram',
      labelEn: 'Telegram',
      labelZh: 'Telegram',
      fields: [
        NotificationField(key: 'telegramBotToken', labelEn: 'Bot token', labelZh: 'Bot Token', secret: true, required: true),
        NotificationField(key: 'telegramChatID', labelEn: 'Chat ID', labelZh: 'Chat ID', required: true),
        NotificationField(key: 'telegramUseTemplate', labelEn: 'Use template', labelZh: '使用模板'),
      ],
    ),
    NotificationProviderSpec(
      type: 'discord',
      labelEn: 'Discord',
      labelZh: 'Discord',
      fields: [
        NotificationField(key: 'discordWebhookUrl', labelEn: 'Webhook URL', labelZh: 'Webhook 地址', secret: true, required: true),
        NotificationField(key: 'discordUsername', labelEn: 'Bot name', labelZh: '机器人名称'),
      ],
    ),
    NotificationProviderSpec(
      type: 'slack',
      labelEn: 'Slack',
      labelZh: 'Slack',
      fields: [
        NotificationField(key: 'slackwebhookURL', labelEn: 'Webhook URL', labelZh: 'Webhook 地址', secret: true, required: true),
        NotificationField(key: 'slackchannel', labelEn: 'Channel', labelZh: '频道'),
      ],
    ),
    NotificationProviderSpec(
      type: 'gotify',
      labelEn: 'Gotify',
      labelZh: 'Gotify',
      fields: [
        NotificationField(key: 'gotifyServerurl', labelEn: 'Server URL', labelZh: '服务器地址', required: true),
        NotificationField(key: 'gotifyapplicationToken', labelEn: 'App token', labelZh: '应用 Token', secret: true, required: true),
        NotificationField(key: 'gotifypriority', labelEn: 'Priority', labelZh: '优先级', hint: '0-10'),
      ],
    ),
    NotificationProviderSpec(
      type: 'ntfy',
      labelEn: 'ntfy',
      labelZh: 'ntfy',
      fields: [
        NotificationField(key: 'ntfyServerUrl', labelEn: 'Server URL', labelZh: '服务器地址', hint: 'https://ntfy.sh'),
        NotificationField(key: 'ntfyTopic', labelEn: 'Topic', labelZh: '主题', required: true),
        NotificationField(key: 'ntfyPriority', labelEn: 'Priority', labelZh: '优先级', hint: '1-5'),
        NotificationField(key: 'ntfyAuthenticationMethod', labelEn: 'Auth method', labelZh: '认证方式', hint: 'usernamePassword / accessToken'),
        NotificationField(key: 'ntfyUsername', labelEn: 'Username', labelZh: '用户名'),
        NotificationField(key: 'ntfyPassword', labelEn: 'Password', labelZh: '密码', secret: true),
        NotificationField(key: 'ntfyAccessToken', labelEn: 'Access token', labelZh: '访问令牌', secret: true),
      ],
    ),
    NotificationProviderSpec(
      type: 'webhook',
      labelEn: 'Webhook',
      labelZh: 'Webhook',
      fields: [
        NotificationField(key: 'webhookURL', labelEn: 'URL', labelZh: '地址', required: true),
        NotificationField(key: 'webhookContentType', labelEn: 'Content type', labelZh: '内容类型', hint: 'json / form'),
      ],
    ),
    NotificationProviderSpec(
      type: 'lark',
      labelEn: 'Feishu / Lark',
      labelZh: '飞书 / Lark',
      fields: [
        NotificationField(key: 'larkWebhookUrl', labelEn: 'Webhook URL', labelZh: 'Webhook 地址', secret: true, required: true),
      ],
    ),
    NotificationProviderSpec(
      type: 'dingding',
      labelEn: 'DingTalk',
      labelZh: '钉钉',
      fields: [
        NotificationField(key: 'dingdingWebhookUrl', labelEn: 'Webhook URL', labelZh: 'Webhook 地址', secret: true, required: true),
        NotificationField(key: 'dingdingSecret', labelEn: 'Secret', labelZh: '加签密钥', secret: true),
      ],
    ),
    NotificationProviderSpec(
      type: 'serverchan',
      labelEn: 'ServerChan',
      labelZh: 'Server酱',
      fields: [
        NotificationField(key: 'serverChanSendKey', labelEn: 'Send key', labelZh: 'SendKey', secret: true, required: true),
      ],
    ),
    NotificationProviderSpec(
      type: 'pushplus',
      labelEn: 'PushPlus',
      labelZh: 'PushPlus',
      fields: [
        NotificationField(key: 'pushPlusToken', labelEn: 'Token', labelZh: 'Token', secret: true, required: true),
      ],
    ),
    NotificationProviderSpec(
      type: 'smtp',
      labelEn: 'Email (SMTP)',
      labelZh: '邮件 (SMTP)',
      fields: [
        NotificationField(key: 'smtpHost', labelEn: 'SMTP host', labelZh: 'SMTP 主机', required: true),
        NotificationField(key: 'smtpPort', labelEn: 'Port', labelZh: '端口', hint: '465 / 587'),
        NotificationField(key: 'smtpSecure', labelEn: 'TLS', labelZh: '启用 TLS', hint: 'true / false'),
        NotificationField(key: 'smtpUsername', labelEn: 'Username', labelZh: '用户名'),
        NotificationField(key: 'smtpPassword', labelEn: 'Password', labelZh: '密码', secret: true),
        NotificationField(key: 'smtpFrom', labelEn: 'From', labelZh: '发件人'),
        NotificationField(key: 'smtpTo', labelEn: 'To', labelZh: '收件人', required: true),
      ],
    ),
  ];

  static NotificationProviderSpec? byType(String? type) {
    for (final spec in all) {
      if (spec.type == type) return spec;
    }
    return null;
  }
}
