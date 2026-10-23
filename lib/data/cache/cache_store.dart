import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/status_page.dart';

/// Disk backed snapshot cache. Each instance gets its own JSON file so the
/// dashboard can render instantly (and offline) before the network answers.
class CacheStore {
  CacheStore._();

  static final CacheStore instance = CacheStore._();

  Directory? _root;
  int _bytes = 0;

  Future<Directory> _dir() async {
    final existing = _root;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/status_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  Future<File> _fileFor(String serverId, String kind) async {
    final dir = await _dir();
    final safe = serverId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return File('${dir.path}/${safe}_$kind.json');
  }

  Future<void> writeSnapshot(String serverId, StatusSnapshot snapshot) async {
    try {
      final file = await _fileFor(serverId, 'snapshot');
      await file.writeAsString(jsonEncode(snapshot.toJson()), flush: false);
      await invalidateSize();
    } catch (_) {
      // Caching is best effort; never break the UI because of a disk issue.
    }
  }

  Future<StatusSnapshot?> readSnapshot(String serverId) async {
    try {
      final file = await _fileFor(serverId, 'snapshot');
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return StatusSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Persists the last observed status per monitor so a background task can
  /// detect transitions after a cold start.
  Future<void> writeStatusMap(String serverId, Map<int, int> statuses) async {
    try {
      final file = await _fileFor(serverId, 'state');
      await file.writeAsString(jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'statuses': statuses.map((k, v) => MapEntry(k.toString(), v)),
      }));
    } catch (_) {}
  }

  Future<Map<int, int>> readStatusMap(String serverId) async {
    try {
      final file = await _fileFor(serverId, 'state');
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return {};
      final raw = decoded['statuses'];
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<int> sizeBytes() async {
    try {
      final dir = await _dir();
      var total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      _bytes = total;
      return total;
    } catch (_) {
      return _bytes;
    }
  }

  Future<int> invalidateSize() => sizeBytes();

  /// Removes every cached artifact. Settings are stored elsewhere and survive.
  Future<void> clearAll() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
      _root = null;
      _bytes = 0;
    } catch (_) {}
  }

  /// Drops only the artifacts belonging to one instance.
  Future<void> clearServer(String serverId) async {
    for (final kind in const ['snapshot', 'state']) {
      try {
        final file = await _fileFor(serverId, kind);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await invalidateSize();
  }

  Future<bool> exists(String serverId) async {    try {
      return await (await _fileFor(serverId, 'snapshot')).exists();
    } catch (_) {
      return false;
    }
  }

  static String humanSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }
}
