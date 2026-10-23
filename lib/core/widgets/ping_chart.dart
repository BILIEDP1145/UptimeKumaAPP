import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/status_page.dart';
import '../theme/app_tokens.dart';

/// Response-time sparkline. Hand painted to avoid pulling in a chart package
/// for a single visualisation. Tap or drag to read individual samples.
class PingChart extends StatefulWidget {
  const PingChart({
    super.key,
    required this.heartbeats,
    this.height = 130,
    this.maxPoints = 80,
  });

  final List<Heartbeat> heartbeats;
  final double height;
  final int maxPoints;

  @override
  State<PingChart> createState() => _PingChartState();
}

class _PingChartState extends State<PingChart> {
  static const double _rightGutter = 34;

  int? _selected;

  List<Heartbeat> get _samples {
    final points = widget.heartbeats
        .where((h) => h.ping != null && h.ping! > 0)
        .toList(growable: false);
    if (points.length <= widget.maxPoints) return points;
    return points.sublist(points.length - widget.maxPoints);
  }

  void _selectAt(double dx, double width) {
    final samples = _samples;
    if (samples.length < 2) return;
    final chartW = math.max(1.0, width - _rightGutter);
    final ratio = (dx / chartW).clamp(0.0, 1.0);
    final index = (ratio * (samples.length - 1)).round();
    if (index == _selected) return;
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final samples = _samples;

    if (samples.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            '—',
            style: context.txt.bodySmall?.copyWith(color: tk.muted),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _selectAt(d.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _selectAt(d.localPosition.dx, constraints.maxWidth),
            onHorizontalDragEnd: (_) => setState(() => _selected = null),
            child: CustomPaint(
              painter: _PingPainter(
                points: samples.map((e) => e.ping!).toList(growable: false),
                downFlags:
                    samples.map((e) => e.status == MonitorStatus.down).toList(growable: false),
                times: samples.map((e) => e.time).toList(growable: false),
                selected: _selected,
                line: tk.accent,
                fill: tk.accentSoft,
                grid: tk.hairline,
                downMark: tk.statusDown,
                label: tk.muted,
                sharp: tk.style.isSharp,
                textStyle: context.txt.labelSmall ?? const TextStyle(fontSize: 10),
                bubbleText: context.txt.labelSmall ?? const TextStyle(fontSize: 10),
                bubbleBg: tk.surfaceCard,
                bubbleBorder: tk.hairline,
                bubbleInk: tk.textStrong,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PingPainter extends CustomPainter {
  _PingPainter({
    required this.points,
    required this.downFlags,
    required this.times,
    required this.selected,
    required this.line,
    required this.fill,
    required this.grid,
    required this.downMark,
    required this.label,
    required this.sharp,
    required this.textStyle,
    required this.bubbleText,
    required this.bubbleBg,
    required this.bubbleBorder,
    required this.bubbleInk,
  });

  final List<double> points;
  final List<bool> downFlags;
  final List<DateTime> times;
  final int? selected;
  final Color line;
  final Color fill;
  final Color grid;
  final Color downMark;
  final Color label;
  final bool sharp;
  final TextStyle textStyle;
  final TextStyle bubbleText;
  final Color bubbleBg;
  final Color bubbleBorder;
  final Color bubbleInk;

  @override
  void paint(Canvas canvas, Size size) {
    const rightGutter = 34.0;
    const topPad = 12.0;
    const bottomPad = 18.0;
    final chartW = math.max(0.0, size.width - rightGutter);
    final chartH = math.max(0.0, size.height - topPad - bottomPad);
    if (chartW <= 0 || chartH <= 0) return;

    final maxV = points.reduce(math.max);
    final minV = points.reduce(math.min);
    final span = math.max(1.0, maxV - minV);
    final top = maxV + span * 0.18;
    final bottom = math.max(0.0, minV - span * 0.18);
    final range = math.max(1.0, top - bottom);

    double dx(int i) => points.length == 1 ? chartW : chartW * (i / (points.length - 1));
    double dy(double v) => topPad + chartH * (1 - (v - bottom) / range);

    // Grid
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + chartH * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(chartW, y), gridPaint);
    }

    // Area
    final path = Path()..moveTo(dx(0), dy(points[0]));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(dx(i), dy(points[i]));
    }

    final area = Path.from(path)
      ..lineTo(dx(points.length - 1), topPad + chartH)
      ..lineTo(dx(0), topPad + chartH)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill, fill.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(0, topPad, chartW, chartH)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Down markers
    final downPaint = Paint()..color = downMark;
    for (var i = 0; i < downFlags.length; i++) {
      if (!downFlags[i]) continue;
      canvas.drawCircle(Offset(dx(i), dy(points[i])), 2.6, downPaint);
    }

    // Last point halo
    final lastX = dx(points.length - 1);
    final lastY = dy(points.last);
    canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = line.withValues(alpha: 0.18));
    canvas.drawCircle(Offset(lastX, lastY), 2.4, Paint()..color = line);

    // Y labels
    void drawLabel(String text, double y) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: textStyle.copyWith(color: label, fontSize: 9.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height / 2));
    }

    drawLabel('${top.round()}', topPad);
    drawLabel('${((top + bottom) / 2).round()}', topPad + chartH / 2);
    drawLabel('${bottom.round()}', topPad + chartH);

    final index = selected;
    if (index == null || index < 0 || index >= points.length) return;

    // Crosshair + sample bubble
    final x = dx(index);
    final y = dy(points[index]);
    canvas.drawLine(
      Offset(x, topPad),
      Offset(x, topPad + chartH),
      Paint()
        ..color = line.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(x, y), 6, Paint()..color = line.withValues(alpha: 0.2));
    canvas.drawCircle(Offset(x, y), 3, Paint()..color = line);

    final time = times[index].toLocal();
    final stamp = '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';
    final text = '$stamp  ${points[index].round()} ms';
    final tp = TextPainter(
      text: TextSpan(text: text, style: bubbleText.copyWith(color: bubbleInk, fontSize: 10.5)),
      textDirection: TextDirection.ltr,
    )..layout();

    final bw = tp.width + 14;
    final bh = tp.height + 8;
    final bx = (x - bw / 2).clamp(0.0, math.max(0.0, chartW - bw)).toDouble();
    final by = math.max(0.0, y - bh - 8).toDouble();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bw, bh),
      Radius.circular(sharp ? 1 : 6),
    );
    canvas.drawRRect(rect, Paint()..color = bubbleBg.withValues(alpha: 0.97));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = bubbleBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(canvas, Offset(bx + 7, by + 4));
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  bool shouldRepaint(covariant _PingPainter old) =>
      old.points != points ||
      old.line != line ||
      old.sharp != sharp ||
      old.selected != selected;
}
