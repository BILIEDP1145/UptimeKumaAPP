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

  /// Only the two formats people actually use. Anything else was dead weight:
  /// Android's channel sound accepts them but every extra codec needs its own
  /// decoder path and nobody has ever picked one.
  static const _allowed = {'wav', 'mp3'};

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

  /// Copies a media-store tone back into app storage.
  ///
  /// `MediaPlayer` cannot open a `content://media/...` URI through audioplayers
  /// (it throws `setDataSource failed: status=0x80000000`), and older builds
  /// never stored a private copy, so previews had nothing to play. This restores
  /// a real file and the caller persists the new path.
  static Future<String?> recover(String contentUri) async {
    if (!Platform.isAndroid) return null;
    if (!contentUri.startsWith('content://')) return null;
    try {
      final path = await _channel.invokeMethod<String>('recoverSound', {
        'uri': contentUri,
      });
      if (path == null || path.isEmpty) return null;
      return path;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
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
