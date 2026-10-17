import 'package:flutter/material.dart';

/// The two visual languages the app can render.
///
/// [kuma] follows Uptime Kuma's own status page: generous radii, soft cards,
/// pill shaped badges, airy spacing.
/// [tencentCloud] follows the console look: square corners, hairline borders,
/// dense spacing and flat surfaces with a left accent stripe.
enum UiStyle {
  kuma,
  tencentCloud;

  bool get isSharp => this == UiStyle.tencentCloud;

  static UiStyle fromName(String? value, UiStyle fallback) {
    for (final s in UiStyle.values) {
      if (s.name == value) return s;
    }
    return fallback;
  }
}

/// Design tokens that change with [UiStyle]. Everything visual that differs
/// between the two layouts lives here so widgets never branch on style
/// directly.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.style,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.badgeRadius,
    required this.cardPadding,
    required this.cardGap,
    required this.pagePadding,
    required this.cardShadow,
    required this.cardBorder,
    required this.statusUp,
    required this.statusDown,
    required this.statusPending,
    required this.statusMaintenance,
    required this.statusUnknown,
    required this.statusUpSoft,
    required this.statusDownSoft,
    required this.statusPendingSoft,
    required this.statusMaintenanceSoft,
    required this.surfaceCard,
    required this.surfaceSunken,
    required this.hairline,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.headerFrom,
    required this.headerTo,
    required this.muted,
    required this.textStrong,
    required this.tabular,
  });

  final UiStyle style;

  // Geometry ----------------------------------------------------------------
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final BorderRadius badgeRadius;
  final EdgeInsets cardPadding;
  final double cardGap;
  final EdgeInsets pagePadding;

  // Surfaces ----------------------------------------------------------------
  final List<BoxShadow> cardShadow;
  final Color cardBorder;
  final Color surfaceCard;
  final Color surfaceSunken;
  final Color hairline;

  // Status semantics --------------------------------------------------------
  final Color statusUp;
  final Color statusDown;
  final Color statusPending;
  final Color statusMaintenance;
  final Color statusUnknown;
  final Color statusUpSoft;
  final Color statusDownSoft;
  final Color statusPendingSoft;
  final Color statusMaintenanceSoft;

  // Brand -------------------------------------------------------------------
  final Color accent;
  final Color accentSoft;
  final Color accentInk;
  final Color headerFrom;
  final Color headerTo;

  // Text --------------------------------------------------------------------
  final Color muted;
  final Color textStrong;
  final List<FontFeature> tabular;

  static AppTokens of(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>();
    assert(t != null, 'AppTokens missing from ThemeData.extensions');
    return t!;
  }

  /// Derives the full token set from a palette + style + brightness.
  factory AppTokens.build({
    required UiStyle style,
    required Color accent,
    required Brightness brightness,
  }) {
    final dark = brightness == Brightness.dark;
    final sharp = style.isSharp;

    final up = dark ? const Color(0xFF34D399) : const Color(0xFF15A66A);
    final down = dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final pending = dark ? const Color(0xFFFBBF24) : const Color(0xFFC2760A);
    final maint = dark ? const Color(0xFF60A5FA) : const Color(0xFF1D6FE0);
    final unknown = dark ? const Color(0xFF8794A9) : const Color(0xFF7C8899);

    Color soft(Color c) => c.withValues(alpha: dark ? 0.18 : 0.10);

    final surfaceCard = dark ? const Color(0xFF121A2A) : Colors.white;
    final surfaceSunken = dark ? const Color(0xFF0D1421) : const Color(0xFFF1F4F9);
    final hairline = dark ? const Color(0xFF233149) : const Color(0xFFE2E8F2);

    return AppTokens(
      style: style,
      radiusXs: sharp ? 0 : 6,
      radiusSm: sharp ? 2 : 10,
      radiusMd: sharp ? 2 : 14,
      radiusLg: sharp ? 2 : 20,
      badgeRadius: BorderRadius.circular(sharp ? 2 : 999),
      cardPadding: sharp
          ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
          : const EdgeInsets.fromLTRB(16, 16, 16, 16),
      cardGap: sharp ? 8 : 12,
      pagePadding: sharp
          ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
          : const EdgeInsets.fromLTRB(16, 12, 16, 12),
      cardShadow: (sharp || dark)
          ? const <BoxShadow>[]
          : [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
      cardBorder: sharp ? hairline : (dark ? hairline.withValues(alpha: 0.7) : const Color(0xFFEDF1F7)),
      surfaceCard: surfaceCard,
      surfaceSunken: surfaceSunken,
      hairline: hairline,
      statusUp: up,
      statusDown: down,
      statusPending: pending,
      statusMaintenance: maint,
      statusUnknown: unknown,
      statusUpSoft: soft(up),
      statusDownSoft: soft(down),
      statusPendingSoft: soft(pending),
      statusMaintenanceSoft: soft(maint),
      accent: accent,
      accentSoft: accent.withValues(alpha: dark ? 0.22 : 0.10),
      accentInk: dark ? Color.alphaBlend(accent.withValues(alpha: 0.55), Colors.white) : accent,
      headerFrom: accent,
      headerTo: Color.alphaBlend(
        accent.withValues(alpha: dark ? 0.52 : 0.62),
        dark ? const Color(0xFF05090F) : const Color(0xFF081326),
      ),
      muted: dark ? const Color(0xFF93A1B8) : const Color(0xFF69778C),
      textStrong: dark ? const Color(0xFFE9EFFA) : const Color(0xFF101827),
      tabular: const [FontFeature.tabularFigures()],
    );
  }

  @override
  AppTokens copyWith({UiStyle? style}) => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}

extension TokensContext on BuildContext {
  AppTokens get tk => AppTokens.of(this);
  TextTheme get txt => Theme.of(this).textTheme;
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
