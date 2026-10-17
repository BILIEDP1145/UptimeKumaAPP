import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Persists a user-chosen alert tone and registers it with the Android media
/// store so the notification channel can play it.
///
/// Android refuses to play a channel sound that lives in app-private storage:
/// the audio is opened by `system_server`, which has no access to
/// `/data/data/<pkg>`. Publishing the file into the shared *Notifications*
/// collection gives us a `content://media/…` URI that the system can read.
class CustomSoundStore {
  CustomSoundStore._();

  static const MethodChannel _channel = MethodChannel('com.zakoflare.uptimekuma/media');

  static const _allowed = {'wav', 'mp3', 'ogg', 'm4a', 'aac', 'flac'};

  static bool isSupportedExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _allowed.contains(ext);
  }

  /// Copies [sourcePath] into app storage, publishes it and returns the
  /// `content://` URI to hand to the notification channel.
  static Future<({String uri, String path})?> install(String sourcePath) async {
    if (!Platform.isAndroid) return null;
    if (!isSupportedExtension(sourcePath)) return null;

    final dir = await getApplicationSupportDirectory();
    final target = Directory('${dir.path}/sounds');
    if (!await target.exists()) await target.create(recursive: true);

    final ext = sourcePath.split('.').last.toLowerCase();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${target.path}/custom_$stamp.$ext');
    await File(sourcePath).copy(file.path);

    try {
      final uri = await _channel.invokeMethod<String>('publishSound', {
        'path': file.path,
        'name': 'UptimeKumaAlert_$stamp',
      });
      if (uri != null && uri.isNotEmpty) {
        return (uri: uri, path: file.path);
      }
    } on PlatformException {
      // fall through
    } on MissingPluginException {
      // fall through
    }

    // Publishing failed (no media-store access). Keep the local copy for
    // previewing, but leave the URI empty so notifications fall back to the
    // bundled tone instead of pointing at an unreadable `file://` path.
    return (uri: '', path: file.path);
  }

  /// Removes a previously installed tone from the media store.
  static Future<void> remove(String? contentUri) async {
    if (!Platform.isAndroid || contentUri == null || contentUri.isEmpty) return;
    if (!contentUri.startsWith('content://')) return;
    try {
      await _channel.invokeMethod<void>('deleteSound', {'uri': contentUri});
    } catch (_) {}
  }
}
