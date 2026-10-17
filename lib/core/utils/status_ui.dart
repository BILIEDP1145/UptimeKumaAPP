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
  const StatusDot({super.key, required this.status, this.size = 8});

  final MonitorStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final color = status.color(tk);
    final isDown = status == MonitorStatus.down;

    // Deliberately never animates or changes size. The previous "pulse" ring
    // grew the dot from 8 to 22 px every frame, which shifted the whole row and
    // read as jitter. A static halo marks an outage without moving anything.
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: isDown
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.38),
                    blurRadius: size * 1.7,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
      ),
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
