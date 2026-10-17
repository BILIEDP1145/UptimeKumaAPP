/// Uptime Kuma heartbeat status codes, as published by
/// `/api/status-page/heartbeat/:slug`.
enum MonitorStatus {
  down(0),
  up(1),
  pending(2),
  maintenance(3),
  unknown(-1);

  const MonitorStatus(this.code);

  final int code;

  static MonitorStatus fromCode(int? code) {
    switch (code) {
      case 0:
        return MonitorStatus.down;
      case 1:
        return MonitorStatus.up;
      case 2:
        return MonitorStatus.pending;
      case 3:
        return MonitorStatus.maintenance;
      default:
        return MonitorStatus.unknown;
    }
  }

  bool get isBad => this == MonitorStatus.down;

  bool get isHealthy => this == MonitorStatus.up || this == MonitorStatus.maintenance;
}

/// One heartbeat sample.
class Heartbeat {
  const Heartbeat({
    required this.status,
    required this.time,
    this.msg = '',
    this.ping,
  });

  final MonitorStatus status;
  final DateTime time;
  final String msg;
  final double? ping;

  factory Heartbeat.fromJson(Map<String, dynamic> json) {
    return Heartbeat(
      status: MonitorStatus.fromCode((json['status'] as num?)?.toInt()),
      time: parseKumaTime(json['time'] as String?),
      msg: (json['msg'] as String?) ?? '',
      ping: (json['ping'] as num?)?.toDouble(),
    );
  }

  /// Uptime Kuma serialises timestamps as `yyyy-MM-dd HH:mm:ss.SSS` in UTC,
  /// without any timezone marker.
  static DateTime parseKumaTime(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now().toUtc();
    final normalised = raw.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalised);
    if (parsed == null) return DateTime.now().toUtc();
    return parsed.isUtc ? parsed : DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.code,
        'time': time.toIso8601String(),
        'msg': msg,
        'ping': ping,
      };
}

/// A monitor as exposed by the public status page.
class Monitor {
  const Monitor({
    required this.id,
    required this.name,
    required this.type,
    this.sendUrl = false,
    this.certExpiryDays,
    this.certValid,
  });

  final int id;
  final String name;
  final String type;
  final bool sendUrl;
  final int? certExpiryDays;
  final bool? certValid;

  /// Uptime Kuma publishes group headers inside `monitorList` with
  /// `type == 'group'`. They are rendered as dividers, not as monitors.
  bool get isGroupHeader => type == 'group';

  bool get hasCertIssue {
    final days = certExpiryDays;
    if (days == null) return false;
    return certValid == false || days <= 14;
  }

  factory Monitor.fromJson(Map<String, dynamic> json) {
    return Monitor(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '—',
      type: (json['type'] as String?) ?? 'http',
      sendUrl: ((json['sendUrl'] as num?)?.toInt() ?? 0) == 1,
      certExpiryDays: (json['certExpiryDaysRemaining'] as num?)?.toInt(),
      certValid: json['validCert'] as bool?,
    );
  }
}

class MonitorGroup {
  const MonitorGroup({required this.id, required this.name, required this.monitors});

  final int id;
  final String name;
  final List<Monitor> monitors;

  List<Monitor> get realMonitors => monitors.where((m) => !m.isGroupHeader).toList(growable: false);

  factory MonitorGroup.fromJson(Map<String, dynamic> json) {
    final list = (json['monitorList'] as List?) ?? const [];
    return MonitorGroup(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Group',
      monitors: list
          .whereType<Map<String, dynamic>>()
          .map(Monitor.fromJson)
          .toList(growable: false),
    );
  }
}

class StatusPageConfig {
  const StatusPageConfig({
    required this.slug,
    required this.title,
    this.description = '',
    this.iconPath,
    this.theme = 'auto',
    this.published = true,
    this.footerText,
    this.showCertificateExpiry = true,
  });

  final String slug;
  final String title;
  final String description;
  final String? iconPath;
  final String theme;
  final bool published;
  final String? footerText;
  final bool showCertificateExpiry;

  factory StatusPageConfig.fromJson(Map<String, dynamic> json) {
    return StatusPageConfig(
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Uptime Kuma',
      description: (json['description'] as String?) ?? '',
      iconPath: json['icon'] as String?,
      theme: (json['theme'] as String?) ?? 'auto',
      published: (json['published'] as bool?) ?? true,
      footerText: json['footerText'] as String?,
      showCertificateExpiry: (json['showCertificateExpiry'] as bool?) ?? true,
    );
  }
}

/// Active incident as published on the status page.
class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.content,
    required this.style,
    required this.createdDate,
    this.pinned = false,
  });

  final int id;
  final String title;
  final String content;

  /// `info` | `warning` | `danger` | `primary` | `light` | `dark`
  final String style;
  final DateTime createdDate;
  final bool pinned;

  bool get isDanger => style == 'danger' || style == 'warning';

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      style: (json['style'] as String?) ?? 'info',
      createdDate: Heartbeat.parseKumaTime(json['createdDate'] as String?),
      pinned: (json['pin'] as num?)?.toInt() == 1,
    );
  }
}

class MaintenanceWindow {
  const MaintenanceWindow({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
  });

  final int id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;

  bool get isActive {
    final now = DateTime.now().toUtc();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  factory MaintenanceWindow.fromJson(Map<String, dynamic> json) {
    return MaintenanceWindow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      startDate: Heartbeat.parseKumaTime(json['start_date'] as String? ?? json['startDate'] as String?),
      endDate: Heartbeat.parseKumaTime(json['end_date'] as String? ?? json['endDate'] as String?),
    );
  }
}

/// Everything the dashboard needs for one instance, in one immutable snapshot.
class StatusSnapshot {
  const StatusSnapshot({
    required this.config,
    required this.groups,
    required this.heartbeats,
    required this.uptime,
    this.incident,
    this.maintenances = const [],
    required this.fetchedAt,
    this.fromCache = false,
  });

  final StatusPageConfig config;
  final List<MonitorGroup> groups;
  final Map<int, List<Heartbeat>> heartbeats;

  /// Keys are `<monitorId>_<hours>`, e.g. `12_24`, `12_720`.
  final Map<String, double> uptime;
  final Incident? incident;
  final List<MaintenanceWindow> maintenances;
  final DateTime fetchedAt;
  final bool fromCache;

  List<Monitor> get allMonitors =>
      groups.expand((g) => g.realMonitors).toList(growable: false);

  MonitorStatus statusOf(int monitorId) {
    final list = heartbeats[monitorId];
    if (list == null || list.isEmpty) return MonitorStatus.unknown;
    return list.last.status;
  }

  List<Heartbeat> heartbeatsOf(int monitorId) => heartbeats[monitorId] ?? const [];

  /// Uptime ratio in 0..1 for the given window, or null when unpublished.
  double? uptimeOf(int monitorId, int hours) {
    final v = uptime['${monitorId}_$hours'];
    if (v == null) return null;
    return v.clamp(0.0, 1.0);
  }

  double? responseTimeOf(int monitorId) {
    final list = heartbeats[monitorId];
    if (list == null) return null;
    for (var i = list.length - 1; i >= 0; i--) {
      final ping = list[i].ping;
      if (ping != null && ping > 0) return ping;
    }
    return null;
  }

  int get upCount => allMonitors.where((m) => statusOf(m.id) == MonitorStatus.up).length;
  int get downCount => allMonitors.where((m) => statusOf(m.id) == MonitorStatus.down).length;
  int get pendingCount => allMonitors.where((m) => statusOf(m.id) == MonitorStatus.pending).length;
  int get maintenanceCount =>
      allMonitors.where((m) => statusOf(m.id) == MonitorStatus.maintenance).length;

  /// Aggregate health used by the header banner.
  MonitorStatus get overallStatus {
    final all = allMonitors;
    if (all.isEmpty) return MonitorStatus.unknown;
    if (downCount > 0) {
      return downCount > (all.length / 2) ? MonitorStatus.down : MonitorStatus.pending;
    }
    if (upCount == 0 && maintenanceCount == 0) return MonitorStatus.unknown;
    return MonitorStatus.up;
  }

  StatusSnapshot copyWith({DateTime? fetchedAt, bool? fromCache}) => StatusSnapshot(
        config: config,
        groups: groups,
        heartbeats: heartbeats,
        uptime: uptime,
        incident: incident,
        maintenances: maintenances,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        fromCache: fromCache ?? this.fromCache,
      );

  Map<String, dynamic> toJson() => {
        'config': {
          'slug': config.slug,
          'title': config.title,
          'description': config.description,
          'icon': config.iconPath,
          'theme': config.theme,
          'published': config.published,
          'footerText': config.footerText,
          'showCertificateExpiry': config.showCertificateExpiry,
        },
        'groups': groups
            .map((g) => {
                  'id': g.id,
                  'name': g.name,
                  'monitorList': g.monitors
                      .map((m) => {
                            'id': m.id,
                            'name': m.name,
                            'type': m.type,
                            'sendUrl': m.sendUrl ? 1 : 0,
                            'certExpiryDaysRemaining': m.certExpiryDays,
                            'validCert': m.certValid,
                          })
                      .toList(),
                })
            .toList(),
        'heartbeats': heartbeats.map(
          (k, v) => MapEntry(k.toString(), v.map((h) => h.toJson()).toList()),
        ),
        'uptime': uptime,
        'incident': incident == null
            ? null
            : {
                'id': incident!.id,
                'title': incident!.title,
                'content': incident!.content,
                'style': incident!.style,
                'createdDate': incident!.createdDate.toIso8601String(),
                'pin': incident!.pinned ? 1 : 0,
              },
        'maintenances': maintenances
            .map((m) => {
                  'id': m.id,
                  'title': m.title,
                  'description': m.description,
                  'start_date': m.startDate.toIso8601String(),
                  'end_date': m.endDate.toIso8601String(),
                })
            .toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory StatusSnapshot.fromJson(Map<String, dynamic> json) {
    final groupsJson = (json['groups'] as List?) ?? const [];
    final hbJson = (json['heartbeats'] as Map?) ?? const {};
    final uptimeJson = (json['uptime'] as Map?) ?? const {};
    final incidentJson = json['incident'];
    final maintJson = (json['maintenances'] as List?) ?? const [];

    return StatusSnapshot(
      config: StatusPageConfig.fromJson((json['config'] as Map?)?.cast<String, dynamic>() ?? {}),
      groups: groupsJson
          .whereType<Map>()
          .map((g) => MonitorGroup.fromJson(g.cast<String, dynamic>()))
          .toList(growable: false),
      heartbeats: hbJson.map((k, v) {
        final id = int.tryParse(k.toString()) ?? 0;
        final list = (v as List?) ?? const [];
        return MapEntry(
          id,
          list
              .whereType<Map>()
              .map((h) => Heartbeat.fromJson(h.cast<String, dynamic>()))
              .toList(growable: false),
        );
      }),
      uptime: uptimeJson.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
      incident: incidentJson is Map
          ? Incident.fromJson(incidentJson.cast<String, dynamic>())
          : null,
      maintenances: maintJson
          .whereType<Map>()
          .map((m) => MaintenanceWindow.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fromCache: true,
    );
  }
}
