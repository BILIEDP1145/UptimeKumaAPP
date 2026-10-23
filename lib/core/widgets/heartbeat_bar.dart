import 'package:flutter/material.dart';

import '../../data/models/status_page.dart';
import '../theme/app_tokens.dart';

/// Uptime Kuma's signature heartbeat strip: one thin bar per check, coloured by
/// status. Newest on the right.
class HeartbeatBar extends StatelessWidget {
  const HeartbeatBar({
    super.key,
    required this.heartbeats,
    this.maxBars = 60,
    this.height = 30,
    this.showTail = true,
  });

  final List<Heartbeat> heartbeats;
  final int maxBars;
  final double height;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final samples = heartbeats.length > maxBars
        ? heartbeats.sublist(heartbeats.length - maxBars)
        : heartbeats;

    if (samples.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tk.surfaceSunken,
          borderRadius: BorderRadius.circular(tk.radiusXs),
        ),
        child: Text(
          '—',
          style: context.txt.labelSmall?.copyWith(color: tk.muted),
        ),
      );
    }

    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _HeartbeatPainter(
        samples: samples,
        sharp: tk.style.isSharp,
        empty: tk.hairline,
        colors: {
          MonitorStatus.up: tk.statusUp,
          MonitorStatus.down: tk.statusDown,
          MonitorStatus.pending: tk.statusPending,
          MonitorStatus.maintenance: tk.statusMaintenance,
          MonitorStatus.unknown: tk.statusUnknown.withValues(alpha: 0.35),
        },
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  _HeartbeatPainter({
    required this.samples,
    required this.sharp,
    required this.empty,
    required this.colors,
  });

  final List<Heartbeat> samples;
  final bool sharp;
  final Color empty;
  final Map<MonitorStatus, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 1.6;
    final count = samples.length;
    final totalGap = gap * (count - 1);
    final barWidth = ((size.width - totalGap) / count).clamp(0.8, 60.0);
    final radius = Radius.circular(sharp ? 0 : barWidth / 2.6);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final status = samples[i].status;
      final color = colors[status] ?? colors[MonitorStatus.unknown]!;
      // Down checks always get full height so they are visible at a glance.
      final h = status == MonitorStatus.down ? size.height : size.height * 0.86;
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barWidth, h),
        radius,
      );
      paint.color = color;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter old) =>
      old.samples != samples || old.colors != colors || old.sharp != sharp;
}

/// Compact horizontal probability bar for 24h/7d/30d uptime.
class UptimeBar extends StatelessWidget {
  const UptimeBar({
    super.key,
    required this.ratio,
    this.height = 5,
  });

  final double? ratio;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final value = ratio ?? 0;
    final color = ratio == null
        ? tk.hairline
        : value >= 0.995
            ? tk.statusUp
            : value >= 0.97
                ? tk.statusPending
                : tk.statusDown;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tk.style.isSharp ? 0 : height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: tk.surfaceSunken),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
