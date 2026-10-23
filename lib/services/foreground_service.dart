import 'package:flutter/services.dart';

/// Starts/stops the native foreground service that owns the pinned
/// notification.
///
/// `ongoing: true` alone is not enough: Android still lets users swipe a plain
/// persistent notification away. Only a foreground service makes it genuinely
/// non-dismissible, and it also keeps the polling process alive when the user
/// leaves the app.
class ForegroundService {
  ForegroundService._();

  static const MethodChannel _channel =
      MethodChannel('com.zakoflare.uptimekuma/service');

  static Future<void> start({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod<void>('start', {
        'title': title,
        'body': body,
      });
    } catch (_) {
      // Older builds without the native side simply keep the normal entry.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
