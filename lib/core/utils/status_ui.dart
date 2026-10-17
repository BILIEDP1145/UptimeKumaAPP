import 'package:flutter/material.dart';

import '../../data/models/status_page.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

extension MonitorStatusUi on MonitorStatus {
  Color color(AppTokens tk) => switch (this) {
        MonitorStatus.up => tk.statusUp,
        MonitorStatus.down => tk.statusDown,
        MonitorStatus.pending => tk.statusPending,
        MonitorStatus.maintenance => tk.statusMaintenance,
        MonitorStatus.unknown => tk.statusUnknown,
      };

  Color softColor(AppTokens tk) => switch (this) {
        MonitorStatus.up => tk.statusUpSoft,
        MonitorStatus.down => tk.statusDownSoft,
        MonitorStatus.pending => tk.statusPendingSoft,
        MonitorStatus.maintenance => tk.statusMaintenanceSoft,
        MonitorStatus.unknown => tk.statusUnknown.withValues(alpha: 0.12),
      };

  String label(L10n l) => switch (this) {
        MonitorStatus.up => l.statusUp,
        MonitorStatus.down => l.statusDown,
        MonitorStatus.pending => l.statusPending,
        MonitorStatus.maintenance => l.statusMaintenance,
        MonitorStatus.unknown => l.statusUnknown,
      };

  IconData get icon => switch (this) {
        MonitorStatus.up => Icons.check_circle_rounded,
        MonitorStatus.down => Icons.error_rounded,
        MonitorStatus.pending => Icons.hourglass_bottom_rounded,
        MonitorStatus.maintenance => Icons.build_circle_rounded,
        MonitorStatus.unknown => Icons.help_rounded,
      };
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 8, this.pulse = false});

  final MonitorStatus status;
  final double size;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final color = status.color(tk);
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: status == MonitorStatus.down
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: size, spreadRadius: 1)]
            : null,
      ),
    );
    if (!pulse) return dot;
    return _Pulsing(color: color, child: dot);
  }
}

class _Pulsing extends StatefulWidget {
  const _Pulsing({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_Pulsing> createState() => _PulsingState();
}

class _PulsingState extends State<_Pulsing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 8 + 14 * t,
              height: 8 + 14 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: (1 - t) * 0.35),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Simple rounded status badge with icon + label.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.dense = false});

  final MonitorStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final color = status.color(tk);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        color: status.softColor(tk),
        borderRadius: tk.badgeRadius,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: dense ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.label(l),
            style: (dense ? context.txt.labelSmall : context.txt.labelMedium)
                ?.copyWith(color: color, height: 1.1),
          ),
        ],
      ),
    );
  }
}
