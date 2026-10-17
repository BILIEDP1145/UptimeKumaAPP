import 'dart:io';

import 'package:flutter/services.dart';

/// Switches the Android launcher icon at runtime.
///
/// Built-in icons are `activity-alias` components: toggling them re-points the
/// launcher without reinstalling. A user-supplied image cannot replace the
/// installed bitmap (Android bakes `android:icon` into the APK), so it is
/// published as a home-screen shortcut carrying that exact bitmap instead.
class IconChanger {
  IconChanger._();

  static const MethodChannel _channel = MethodChannel('com.zakoflare.uptimekuma/icon');

  static bool get supported => Platform.isAndroid;

  static const List<IconVariant> variants = [
    IconVariant('default', 'Official', '官方', 'icon_official'),
    IconVariant('emerald', 'Emerald', '翡翠', 'icon_emerald'),
    IconVariant('midnight', 'Midnight', '午夜', 'icon_midnight'),
    IconVariant('crimson', 'Crimson', '朱红', 'icon_crimson'),
  ];

  static IconVariant variantById(String? id) =>
      variants.firstWhere((v) => v.id == id, orElse: () => variants.first);

  static Future<String> current() async {
    if (!supported) return 'default';
    try {
      final result = await _channel.invokeMethod<String>('getIcon');
      return result ?? 'default';
    } on PlatformException {
      return 'default';
    } on MissingPluginException {
      return 'default';
    }
  }

  static Future<bool> apply(String id) async {
    if (!supported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setIcon', {'variant': id});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Pins a shortcut whose icon is [imagePath]. Returns true when the launcher
  /// accepted the request (the user still has to confirm).
  static Future<bool> pinCustom(String imagePath) async {
    if (!supported) return false;
    if (!File(imagePath).existsSync()) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('pinIcon', {'path': imagePath});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Restores the default recents-card icon.
  static Future<void> clearTaskIcon() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('clearTaskIcon');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  /// Swaps the recents-card icon. This is the one system-drawn surface that can
  /// take a runtime bitmap, so a custom icon is visible even when the launcher
  /// refuses to pin shortcuts.
  static Future<bool> applyTaskIcon(String imagePath) async {
    if (!supported) return false;
    if (!File(imagePath).existsSync()) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setTaskIcon', {'path': imagePath});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class IconVariant {
  const IconVariant(this.id, this.labelEn, this.labelZh, this.assetName);

  final String id;
  final String labelEn;
  final String labelZh;

  /// Asset file (without extension) used for the in-app preview.
  final String assetName;

  String label(bool zh) => zh ? labelZh : labelEn;

  String get assetPreview => 'assets/images/$assetName.png';

  /// Suffix of the activity-alias component declared in AndroidManifest.xml.
  String get aliasSuffix => id;
}
