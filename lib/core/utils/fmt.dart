import '../l10n/l10n.dart';

class Fmt {
  static String two(int v) => v.toString().padLeft(2, '0');

  /// `2026-10-17 12:08:42`
  static String dateTime(DateTime t, {bool utc = false}) {
    final v = utc ? t.toUtc() : t.toLocal();
    return '${v.year}-${two(v.month)}-${two(v.day)} ${two(v.hour)}:${two(v.minute)}:${two(v.second)}';
  }

  /// `10-17 12:08`
  static String shortDateTime(DateTime t) {
    final v = t.toLocal();
    return '${two(v.month)}-${two(v.day)} ${two(v.hour)}:${two(v.minute)}';
  }

  /// `12:08:42`
  static String clock(DateTime t) {
    final v = t.toLocal();
    return '${two(v.hour)}:${two(v.minute)}:${two(v.second)}';
  }

  static String relative(DateTime t, L10n l) {
    final diff = DateTime.now().difference(t.toLocal());
    if (diff.inSeconds < 10) return l.justNow;
    if (diff.inSeconds < 60) return l.secondsAgo(diff.inSeconds);
    if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
    return l.daysAgo(diff.inDays);
  }

  /// `99.97%`
  static String percent(double? ratio, {int digits = 2}) {
    if (ratio == null) return '—';
    return '${(ratio * 100).toStringAsFixed(digits)}%';
  }

  /// `128 ms`
  static String ping(double? ms) {
    if (ms == null || ms <= 0) return '—';
    if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(2)} s';
    return '${ms.round()} ms';
  }

  static String duration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d ${d.inHours % 24}h';
  }

  /// Normalises the myriad monitor type strings Uptime Kuma uses.
  static String monitorType(String raw) {
    switch (raw) {
      case 'http':
        return 'HTTP(s)';
      case 'keyword':
        return 'Keyword';
      case 'ping':
        return 'Ping';
      case 'port':
        return 'TCP Port';
      case 'dns':
        return 'DNS';
      case 'grpc':
        return 'gRPC';
      case 'push':
        return 'Push';
      case 'steam':
        return 'Steam';
      case 'mqtt':
        return 'MQTT';
      case 'sqlserver':
        return 'SQL Server';
      case 'postgres':
        return 'PostgreSQL';
      case 'mysql':
        return 'MySQL';
      case 'mongodb':
        return 'MongoDB';
      case 'radius':
        return 'Radius';
      case 'redis':
        return 'Redis';
      case 'group':
        return 'Group';
      case 'docker':
        return 'Docker';
      case 'system':
        return 'System';
      default:
        return raw.isEmpty ? '—' : raw[0].toUpperCase() + raw.substring(1);
    }
  }
}
