import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Paints the optional user background image behind everything, with blur and
/// opacity, plus a scrim that guarantees text contrast in both themes.
///
/// The decoded image is cached across rebuilds (and route transitions) so
/// leaving a pushed page never flashes an empty background.
class AppBackground extends StatefulWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.imagePath,
    this.opacity = 0.85,
    this.blur = 6,
  });

  final Widget child;
  final String? imagePath;
  final double opacity;
  final double blur;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  static final Map<String, ImageProvider> _providers = {};

  ImageProvider? _provider;
  String? _resolvedFor;

  ImageProvider _providerFor(String path) {
    final stat = File(path).statSync();
    final key = '$path|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
    final cached = _providers[key];
    if (cached != null) return cached;
    final provider = FileImage(File(path));
    _providers[key] = provider;
    // Drop stale entries for the same file.
    _providers.removeWhere((k, _) => k.startsWith('$path|') && k != key);
    return provider;
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final path = widget.imagePath;

    if (path == null) {
      _provider = null;
      _resolvedFor = null;
      return ColoredBox(color: base, child: widget.child);
    }

    if (path != _resolvedFor) {
      _resolvedFor = path;
      _provider = File(path).existsSync() ? _providerFor(path) : null;
    }

    final provider = _provider;
    if (provider == null) return ColoredBox(color: base, child: widget.child);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Opacity(
              opacity: widget.opacity.clamp(0.0, 1.0),
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        // Scrim keeps contrast usable over arbitrary photos.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [
                      base.withValues(alpha: 0.78),
                      base.withValues(alpha: 0.88),
                      base.withValues(alpha: 0.95),
                    ]
                  : [
                      base.withValues(alpha: 0.72),
                      base.withValues(alpha: 0.86),
                      base.withValues(alpha: 0.94),
                    ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
