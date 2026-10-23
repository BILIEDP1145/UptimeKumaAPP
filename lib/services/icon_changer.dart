import 'dart:io';

import 'package:flutter/services.dart';

/// Switches the Android launcher icon at runtime.
///
/// Built-in icons are `activity-alias` components: toggling them re-points the
/// launcher without reinstalling. Android cannot replace the launcher icon of
/// an installed package with a runtime bitmap, so user uploads are not offered.
class IconChanger {
  IconChanger._();

  static const MethodChannel _channel = MethodChannel('com.zakoflare.uptimekuma/icon');

  static bool get supported => Platform.isAndroid;

  static const List<IconVariant> variants = [
    IconVariant('default', 'Default', '默认', 'icon_default'),
    IconVariant('official', 'Official', '官方', 'icon_official'),
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
