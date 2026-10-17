import 'package:flutter/material.dart';

/// Curated accent colours. The first entry is the ZAKOFLARE terminal blue
/// that the project standardises on.
class AccentPalette {
  const AccentPalette(this.id, this.labelEn, this.labelZh, this.color);

  final String id;
  final String labelEn;
  final String labelZh;
  final Color color;

  String label(bool zh) => zh ? labelZh : labelEn;

  static const List<AccentPalette> all = [
    AccentPalette('terminal', 'Terminal Blue', '终端蓝', Color(0xFF1670F5)),
    AccentPalette('azure', 'Azure', '天青', Color(0xFF0EA5E9)),
    AccentPalette('teal', 'Deep Teal', '深青', Color(0xFF0D9488)),
    AccentPalette('emerald', 'Emerald', '翡翠', Color(0xFF10B981)),
    AccentPalette('amber', 'Amber', '琥珀', Color(0xFFE08A00)),
    AccentPalette('crimson', 'Crimson', '朱红', Color(0xFFE23D3D)),
    AccentPalette('violet', 'Violet', '紫罗兰', Color(0xFF7C5CFC)),
    AccentPalette('magenta', 'Magenta', '品红', Color(0xFFD6459B)),
    AccentPalette('graphite', 'Graphite', '石墨', Color(0xFF5A6B84)),
  ];

  static AccentPalette byId(String? id) {
    return all.firstWhere((p) => p.id == id, orElse: () => all.first);
  }
}
