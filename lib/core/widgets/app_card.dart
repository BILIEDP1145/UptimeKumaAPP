import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Card that adapts to the active [UiStyle]: soft rounded surface in Kuma mode,
/// hairline square panel in Tencent Cloud mode.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
    this.accentStripe = false,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final bool accentStripe;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final radius = BorderRadius.circular(tk.radiusMd);
    final surface = color ?? tk.surfaceCard.withValues(alpha: 0.96);

    Widget content = Padding(
      padding: padding ?? tk.cardPadding,
      child: child,
    );

    if (accentStripe && tk.style.isSharp) {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: tk.accent),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? tk.cardBorder),
        boxShadow: tk.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }
}

/// Small pill/label used for statuses, counts and metadata.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dense = false,
    this.solid = false,
    this.fg,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dense;
  final bool solid;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = color ?? tk.accent;
    final textColor = fg ?? (solid ? Colors.white : c);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: 0.12),
        borderRadius: tk.badgeRadius,
        border: Border.all(color: solid ? c : c.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (dense ? context.txt.labelSmall : context.txt.labelMedium)
                ?.copyWith(color: textColor, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 8, top: 4),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (tk.style.isSharp)
            Container(
              width: 3,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              color: tk.accent,
            ),
          Expanded(
            child: Text(
              title,
              style: context.txt.titleSmall?.copyWith(
                color: tk.textStrong,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
