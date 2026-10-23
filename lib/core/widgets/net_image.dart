import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/cache/image_cache.dart';
import '../../data/net/uk_http.dart';

/// Loads a remote image with the app's own HTTP client so it follows the same
/// DNS-over-HTTPS and User-Agent settings as the API calls.
///
/// `Image.network` uses the platform client, which is why a status page logo
/// that loads fine over the API can still fail in the header (Cloudflare and
/// friends reject requests without a UA).
///
/// Three layers keep it instant:
///
/// * [ImageDiskCache] — bytes on disk, read **synchronously** so a cold start or
///   an instance switch has the picture on the first frame;
/// * an in-memory byte map for the running session;
/// * a decoded [`ui.Image`] cache drawn with `RawImage`, so the bitmap never has
///   to be decoded again while the picture is on screen.
class NetImage extends StatefulWidget {
  const NetImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
    this.radius,
    this.doh = false,
    this.dohEndpoint,
    this.userAgent,
  });

  final String? url;
  final double size;
  final Widget fallback;
  final double? radius;
  final bool doh;
  final String? dohEndpoint;
  final String? userAgent;

  /// Drops the in-memory copies; the settings page calls this when the user
  /// clears the image cache so nothing keeps rendering from stale bytes.
  static void clearMemoryCache() {
    _NetImageState._bytesCache.clear();
    for (final image in _NetImageState._decoded.values) {
      image.dispose();
    }
    _NetImageState._decoded.clear();
  }

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  static const int _cacheLimit = 32;

  static final Map<String, Uint8List> _bytesCache = {};
  static final Map<String, ui.Image> _decoded = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  Uint8List? _bytes;
  ui.Image? _image;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(NetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _sync(notify: true);
  }

  void _sync({bool notify = false}) {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      _loadedUrl = null;
      _bytes = null;
      _image = null;
      if (notify && mounted) setState(() {});
      return;
    }
    if (url == _loadedUrl) return;
    _loadedUrl = url;
    _image = _decoded[url];

    final cached = _bytesCache[url] ?? ImageDiskCache.instance.readSync(url);
    if (cached != null) {
      _bytesCache[url] = cached;
      _bytes = cached;
      if (_image == null) unawaited(_decode(url, cached));
      if (notify && mounted) setState(() {});
      return;
    }

    _bytes = null;
    _image = null;
    if (notify && mounted) setState(() {});
    unawaited(_fetch(url));
  }

  Future<void> _fetch(String url) async {
    final future = _inflight[url] ??= _download(url);
    final bytes = await future;
    _inflight.remove(url);
    if (bytes == null) return;

    if (_bytesCache.length >= _cacheLimit) {
      _bytesCache.remove(_bytesCache.keys.first);
    }
    _bytesCache[url] = bytes;
    unawaited(ImageDiskCache.instance.write(url, bytes));
    if (!mounted || _loadedUrl != url) return;
    setState(() => _bytes = bytes);
    unawaited(_decode(url, bytes));
  }

  /// Decodes once per URL; every later paint uses the cached `ui.Image`.
  Future<void> _decode(String url, Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _decoded[url] = frame.image;
      if (!mounted || _loadedUrl != url) return;
      setState(() => _image = frame.image);
    } catch (_) {
      // Undecodable payload: keep the bytes-based fallback in place.
    }
  }

  Future<Uint8List?> _download(String url) async {
    // Shared client: reuses the TLS session instead of handshaking per image.
    final client = UkHttp.shared(
      doh: widget.doh,
      dohEndpoint: widget.dohEndpoint,
      userAgent: widget.userAgent,
    );
    try {
      final res = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final bytes = _bytes;

    Widget child;
    if (image != null) {
      child = RawImage(
        image: image,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    } else if (bytes != null) {
      // Decode in flight: paint through the normal pipeline so the picture
      // appears the moment the frame is ready.
      child = Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    } else {
      child = widget.fallback;
    }

    if (widget.radius != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius!),
        child: child,
      );
    }
    return SizedBox(width: widget.size, height: widget.size, child: child);
  }
}
