import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders an instance-provided icon.
///
/// Uptime Kuma stores the status page icon as a server-relative path
/// (`/upload/logo.png`), a data URI, or occasionally an SVG — none of which
/// work with a naive `Image.network`. Resolution happens in
/// [ServerConfig.resolveAsset]; this widget just picks the right decoder.
class RemoteIcon extends StatelessWidget {
  const RemoteIcon({
    super.key,
    required this.path,
    required this.size,
    required this.fallback,
    this.radius,
  });

  /// Fully qualified URL, data URI, or null.
  final String? path;
  final double size;
  final Widget fallback;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final source = path?.trim();
    Widget child;
    if (source == null || source.isEmpty) {
      child = fallback;
    } else if (source.startsWith('data:')) {
      child = _fromDataUri(source);
    } else if (_looksLikeSvg(source)) {
      child = SvgPicture.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
      );
    } else {
      child = Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    if (radius == null) return SizedBox(width: size, height: size, child: child);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius!),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  static bool _looksLikeSvg(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.svg');
  }

  Widget _fromDataUri(String uri) {
    final comma = uri.indexOf(',');
    if (comma < 0) return fallback;
    final meta = uri.substring(5, comma);
    final payload = uri.substring(comma + 1);
    if (!meta.contains('base64')) return fallback;
    try {
      final bytes = base64Decode(payload);
      if (meta.contains('svg')) {
        return SvgPicture.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      }
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }
}
