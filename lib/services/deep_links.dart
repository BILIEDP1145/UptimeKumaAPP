import 'dart:async';

import 'package:flutter/services.dart';

/// Receives `uptimekuma://…` links.
///
/// Two entry points on the native side: the intent that cold-started the app
/// (`getInitialLink`) and `onNewIntent` for a running one. Both funnel into one
/// stream so the UI only has to listen once.
class DeepLinks {
  DeepLinks._();

  static const MethodChannel _channel =
      MethodChannel('com.zakoflare.uptimekuma/links');

  static final StreamController<String> _controller =
      StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        _controller.add(call.arguments as String);
      }
      return null;
    });
  }

  /// The link that launched the process, if any.
  static Future<String?> initial() async {
    try {
      return await _channel.invokeMethod<String>('getInitialLink');
    } catch (_) {
      return null;
    }
  }
}
