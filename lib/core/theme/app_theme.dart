import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'palettes.dart';

class AppTheme {
  static ThemeData build({
    required Brightness brightness,
    required AccentPalette palette,
    required UiStyle style,
  }) {
    final dark = brightness == Brightness.dark;
    final tokens = AppTokens.build(style: style, accent: palette.color, brightness: brightness);

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.color,
      brightness: brightness,
    ).copyWith(
      primary: tokens.accentInk,
      secondary: tokens.accent,
      surface: tokens.surfaceCard,
      error: tokens.statusDown,
      onPrimary: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF080E19) : const Color(0xFFF4F6FB),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: style.isSharp ? VisualDensity.compact : VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[tokens],
    );

    final text = _textTheme(base.textTheme, tokens, dark);

    return base.copyWith(
      textTheme: text,
      dividerTheme: DividerThemeData(
        color: tokens.hairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: tokens.textStrong,
        ),
        iconTheme: IconThemeData(color: tokens.textStrong, size: 22),
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: text.bodyMedium?.copyWith(color: tokens.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.statusDown),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.statusDown, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.isSharp ? 2 : 12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textStrong,
          minimumSize: const Size(0, 46),
          side: BorderSide(color: tokens.hairline),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.isSharp ? 2 : 12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accentInk,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.isSharp ? 2 : 10),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return Colors.white;
          return dark ? const Color(0xFF9AA8BE) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return tokens.accent;
          return dark ? const Color(0xFF2A3852) : const Color(0xFFD7DEEA);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.accent,
        inactiveTrackColor: tokens.hairline,
        thumbColor: Colors.white,
        overlayColor: tokens.accentSoft,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1B2740) : const Color(0xFF17233A),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.isSharp ? 2 : 12),
        ),
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(style.isSharp ? 0 : 22),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.isSharp ? 2 : 18),
        ),
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: tokens.textStrong,
        ),
        contentTextStyle: text.bodyMedium?.copyWith(color: tokens.textStrong),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.muted,
        textColor: tokens.textStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.accentSoft,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final on = s.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? tokens.accentInk : tokens.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final on = s.contains(WidgetState.selected);
          return IconThemeData(size: 22, color: on ? tokens.accentInk : tokens.muted);
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF22304A) : const Color(0xFF17233A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.hairline,
        circularTrackColor: tokens.hairline,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.isSharp ? 2 : 12),
          side: BorderSide(color: tokens.cardBorder),
        ),
        textStyle: text.bodyMedium?.copyWith(color: tokens.textStrong),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppTokens tokens, bool dark) {
    TextStyle? mk(TextStyle? s, double size, FontWeight w, {double? h, Color? c}) {
      return s?.copyWith(
        fontSize: size,
        fontWeight: w,
        height: h,
        color: c ?? tokens.textStrong,
        letterSpacing: -0.01 * size,
      );
    }

    return base.copyWith(
      displaySmall: mk(base.displaySmall, 30, FontWeight.w700, h: 1.15),
      headlineSmall: mk(base.headlineSmall, 22, FontWeight.w700, h: 1.2),
      titleLarge: mk(base.titleLarge, 18, FontWeight.w700, h: 1.25),
      titleMedium: mk(base.titleMedium, 15.5, FontWeight.w700, h: 1.3),
      titleSmall: mk(base.titleSmall, 13.5, FontWeight.w600, h: 1.35),
      bodyLarge: mk(base.bodyLarge, 15, FontWeight.w400, h: 1.45),
      bodyMedium: mk(base.bodyMedium, 13.5, FontWeight.w400, h: 1.45),
      bodySmall: mk(base.bodySmall, 12, FontWeight.w400, h: 1.4),
      labelLarge: mk(base.labelLarge, 14, FontWeight.w600),
      labelMedium: mk(base.labelMedium, 12, FontWeight.w600),
      labelSmall: mk(base.labelSmall, 11, FontWeight.w600),
    ).apply(
      bodyColor: tokens.textStrong,
      displayColor: tokens.textStrong,
    );
  }
}
