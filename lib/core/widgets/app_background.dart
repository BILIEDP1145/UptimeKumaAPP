import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Paints the optional user background image behind everything, with blur and
/// opacity, plus a scrim that guarantees text contrast in both themes.
///
/// Two rules keep route transitions from flashing:
///
/// 1. the widget tree has **one fixed shape** — the photo layer always occupies
///    the same child slot, it is merely empty until the bitmap is ready. An
///    earlier version returned a `ColoredBox` while decoding and a `Stack`
///    afterwards, which swapped the whole subtree (including the Navigator) and
///    blinked the screen;
/// 2. decoded bitmaps live in a static cache and are read synchronously while
///    building, so a rebuilt `AppBackground` still paints the photo on its very
///    first frame instead of starting from nothing.
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
  /// Decoded bitmaps keyed by `path|mtime|size`, shared across instances.
  static final Map<String, ui.Image> _cache = {};

  String? _loadedKey;

  ui.Image? get _image {
    final key = _loadedKey;
    return key == null ? null : _cache[key];
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _sync();
  }

  void _sync() {
    final path = widget.imagePath;
    if (path == null) {
      _loadedKey = null;
      return;
    }
    String? key;
    try {
      final stat = File(path).statSync();
      key = '$path|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
    } catch (_) {
      key = null;
    }
    _loadedKey = key;
    if (key == null || _cache.containsKey(key)) return;
    _decode(path, key);
  }

  Future<void> _decode(String path, String key) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _cache[key] = frame.image;
      _cache.removeWhere((k, _) => k.startsWith('$path|') && k != key);
      if (!mounted || _loadedKey != key) return;
      setState(() {});
    } catch (_) {
      // Unreadable image: the flat scrim stays.
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final image = _image;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        // Fixed slot, empty while there is no photo. Keeping it means the
        // Navigator below is never re-parented.
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Opacity(
              opacity: image == null ? 0 : widget.opacity.clamp(0.0, 1.0),
              child: image == null
                  ? const SizedBox.expand()
                  : RawImage(
                      image: image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      filterQuality: FilterQuality.medium,
                    ),
            ),
          ),
        ),
        // Scrim keeps contrast usable over arbitrary photos. Its gradient is a
        // readability device, not decoration, so it ignores the flat theme.
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
