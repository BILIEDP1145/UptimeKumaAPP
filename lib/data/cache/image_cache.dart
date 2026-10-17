import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../net/uk_http.dart';
import 'cache_store.dart';

/// Disk cache for instance-provided images (status page logos, icons).
///
/// Without it every cold start re-downloaded the logo, and switching instances
/// meant staring at an empty badge until a fresh TLS handshake finished. The
/// body is small (a few KB), so reads are synchronous: the first frame already
/// has the picture and nothing flashes.
class ImageDiskCache {
  ImageDiskCache._();

  static final ImageDiskCache instance = ImageDiskCache._();

  /// Keeps the cache bounded; oldest files are dropped first.
  static const int maxBytes = 8 * 1024 * 1024;
  static const int maxFiles = 120;

  Directory? _root;

  Future<Directory> _dir() async {
    final existing = _root;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/image_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  /// Warms the directory handle so [readSync] works from the first frame.
  Future<void> warmUp() async {
    try {
      await _dir();
    } catch (_) {}
  }

  static String _key(String url) {
    // FNV-1a, 64 bit — stable across processes without pulling in `crypto`.
    var hash = 0xcbf29ce484222325;
    for (final unit in url.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    final positive = hash & 0x7FFFFFFFFFFFFFFF;
    return positive.toRadixString(16).padLeft(16, '0');
  }

  File? _fileForSync(String url) {
    final dir = _root;
    if (dir == null) return null;
    return File('${dir.path}/${_key(url)}.img');
  }

  Future<File> _fileFor(String url) async {
    final dir = await _dir();
    return File('${dir.path}/${_key(url)}.img');
  }

  /// Synchronous read used from `build`; returns null until [warmUp] ran.
  Uint8List? readSync(String url) {
    try {
      final file = _fileForSync(url);
      if (file == null || !file.existsSync()) return null;
      return file.readAsBytesSync();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> read(String url) async {
    try {
      final file = await _fileFor(url);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Downloads [url] and stores it, unless it is already on disk.
  ///
  /// Called as soon as a snapshot arrives, so the logo is in the cache before
  /// the header even builds — switching instances then needs no network at all.
  Future<void> prefetch(
    String url, {
    bool doh = false,
    String? dohEndpoint,
    String? userAgent,
  }) async {
    if (readSync(url) != null) return;
    final client = UkHttp.shared(
      doh: doh,
      dohEndpoint: dohEndpoint,
      userAgent: userAgent,
    );
    try {
      final res = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;
      await write(url, res.bodyBytes);
    } catch (_) {
      // Prefetch is best-effort; the widget will try again when it mounts.
    }
  }

  Future<void> write(String url, List<int> bytes) async {
    try {
      final file = await _fileFor(url);
      await file.writeAsBytes(bytes, flush: false);
      await _trim();
    } catch (_) {}
  }

  /// Bounds the directory: drop the oldest files once either limit is passed.
  Future<void> _trim() async {
    try {
      final dir = await _dir();
      final files = <({File file, DateTime at, int size})>[];
      var total = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          final size = stat.size;
          total += size;
          files.add((file: entity, at: stat.modified, size: size));
        } catch (_) {}
      }
      if (files.length <= maxFiles && total <= maxBytes) return;
      files.sort((a, b) => a.at.compareTo(b.at));
      var count = files.length;
      for (final entry in files) {
        if (count <= maxFiles && total <= maxBytes) break;
        try {
          await entry.file.delete();
          count--;
          total -= entry.size;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<({int files, int bytes})> stats() async {
    try {
      final dir = await _dir();
      var files = 0;
      var bytes = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          bytes += await entity.length();
          files++;
        } catch (_) {}
      }
      return (files: files, bytes: bytes);
    } catch (_) {
      return (files: 0, bytes: 0);
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _dir();
      await for (final entity in dir.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static String humanSize(int bytes) => CacheStore.humanSize(bytes);
}
