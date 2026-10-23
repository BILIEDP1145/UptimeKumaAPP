import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/app_card.dart';
import '../../services/settings_store.dart';
import '../../state/app_state.dart';
import 'appearance_preview_page.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool _picking = false;

  Future<void> _pickStatusColor({required bool isUp}) async {
    final app = context.read<AppState>();
    final choice = await showModalBottomSheet<_ColorChoice>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _ColorSheet(
        initial: isUp ? app.statusUpColor : app.statusDownColor,
        title: isUp ? L10n.of(context).statusColorUp : L10n.of(context).statusColorDown,
      ),
    );
    if (choice == null || !mounted) return;
    if (isUp) {
      app.setStatusUpColor(choice.color);
    } else {
      app.setStatusDownColor(choice.color);
    }
  }

  Future<void> _pickBackground() async {
    final l = L10n.of(context);
    final app = context.read<AppState>();
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2200,
        imageQuality: 88,
      );
      if (file != null) {
        final saved = await app.persistBackground(file.path);
        app.setBgImage(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.imagePickerUnavailable}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l.settingsAppearance)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(tk.pagePadding.left, 4, tk.pagePadding.right, 28),
        children: [
          // Theme mode
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.themeMode, style: context.txt.titleSmall),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ChoiceTile(
                      icon: Icons.brightness_auto_rounded,
                      label: l.themeSystem,
                      selected: app.themeMode == ThemeModeChoice.system,
                      onTap: () => app.setThemeMode(ThemeModeChoice.system),
                    ),
                    const SizedBox(width: 8),
                    _ChoiceTile(
                      icon: Icons.light_mode_rounded,
                      label: l.themeLight,
                      selected: app.themeMode == ThemeModeChoice.light,
                      onTap: () => app.setThemeMode(ThemeModeChoice.light),
                    ),
                    const SizedBox(width: 8),
                    _ChoiceTile(
                      icon: Icons.dark_mode_rounded,
                      label: l.themeDark,
                      selected: app.themeMode == ThemeModeChoice.dark,
                      onTap: () => app.setThemeMode(ThemeModeChoice.dark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Accent colour
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.accentColor, style: context.txt.titleSmall),
                    const Spacer(),
                    Text(
                      app.accent.label(l.zh),
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in AccentPalette.all)
                      _Swatch(
                        palette: p,
                        selected: p.id == app.accent.id,
                        onTap: () => app.setAccent(p),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // UI style
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.uiStyle, style: context.txt.titleSmall),
                const SizedBox(height: 10),
                _StyleOption(
                  title: l.uiStyleKuma,
                  hint: l.uiStyleKumaHint,
                  selected: app.uiStyle == UiStyle.kuma,
                  sharp: false,
                  onTap: () => app.setUiStyle(UiStyle.kuma),
                ),
                const SizedBox(height: 8),
                _StyleOption(
                  title: l.uiStyleTencent,
                  hint: l.uiStyleTencentHint,
                  selected: app.uiStyle == UiStyle.tencentCloud,
                  sharp: true,
                  onTap: () => app.setUiStyle(UiStyle.tencentCloud),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Language
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.language, style: context.txt.titleSmall),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LangTile(
                        label: l.languageZh,
                        selected: app.localeOverride?.languageCode == 'zh',
                        onTap: () => app.setLocale(const Locale('zh')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LangTile(
                        label: l.languageEn,
                        selected: app.localeOverride?.languageCode == 'en',
                        onTap: () => app.setLocale(const Locale('en')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Flat colours
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(l.flatTitle, style: context.txt.titleSmall),
                    ),
                    Switch(
                      value: app.flatGradients,
                      onChanged: app.setFlatGradients,
                    ),
                  ],
                ),
                Text(
                  l.flatBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Long monitor names
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(l.nameClampTitle, style: context.txt.titleSmall),
                    ),
                    Switch(
                      value: app.nameClamp,
                      onChanged: app.setNameClamp,
                    ),
                  ],
                ),
                Text(
                  l.nameClampBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
                if (app.nameClamp) ...[
                  const SizedBox(height: 8),
                  _SliderRow(
                    label: l.nameClampChars,
                    value: app.nameClampChars.toDouble(),
                    min: 8,
                    max: 40,
                    display: '${app.nameClampChars}',
                    onChanged: (v) => app.setNameClampChars(v.round()),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // SLA / uptime percentages
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(l.showSlaTitle, style: context.txt.titleSmall),
                    ),
                    Switch(
                      value: app.showSla,
                      onChanged: app.setShowSla,
                    ),
                  ],
                ),
                Text(
                  l.showSlaBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Status colours + UI effects
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(l.uiEffectsTitle, style: context.txt.titleSmall),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(AppearancePreviewPage.route()),
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: Text(l.previewTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const SizedBox(height: 3),
                Text(
                  l.statusColorsBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                _ColorRow(
                  label: l.statusColorUp,
                  color: app.statusUpColor ?? tk.statusUp,
                  overridden: app.statusUpColor != null,
                  onTap: () => _pickStatusColor(isUp: true),
                ),
                const SizedBox(height: 8),
                _ColorRow(
                  label: l.statusColorDown,
                  color: app.statusDownColor ?? tk.statusDown,
                  overridden: app.statusDownColor != null,
                  onTap: () => _pickStatusColor(isUp: false),
                ),
                if (app.statusUpColor != null || app.statusDownColor != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        app.setStatusUpColor(null);
                        app.setStatusDownColor(null);
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 15),
                      label: Text(l.statusColorReset),
                    ),
                  ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(l.glassTitle, style: context.txt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tk.textStrong,
                      )),
                    ),
                    Switch(value: app.glass, onChanged: app.setGlass),
                  ],
                ),
                Text(
                  l.glassBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  l.uiOpacityTitle,
                  style: context.txt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tk.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.uiOpacityBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
                _SliderRow(
                  label: '${(app.uiOpacity * 100).round()}%',
                  value: app.uiOpacity,
                  min: 0.4,
                  max: 1.0,
                  display: '${(app.uiOpacity * 100).round()}%',
                  onChanged: app.setUiOpacity,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dashboard header
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.headerSectionTitle, style: context.txt.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(l.headerFull),
                      selected: !app.headerCompact,
                      onSelected: (_) => app.setHeaderCompact(false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(l.headerCompact),
                      selected: app.headerCompact,
                      onSelected: (_) => app.setHeaderCompact(true),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l.headerLayoutBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.headerGlassTitle,
                        style: context.txt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tk.textStrong,
                        ),
                      ),
                    ),
                    Switch(value: app.headerGlass, onChanged: app.setHeaderGlass),
                  ],
                ),
                Text(
                  l.headerGlassBody,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Background image
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.backgroundImage, style: context.txt.titleSmall),
                    const Spacer(),
                    if (app.hasBackground)
                      TextButton(
                        onPressed: () => app.setBgImage(null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 30),
                          foregroundColor: tk.statusDown,
                        ),
                        child: Text(l.removeImage, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                Text(
                  l.backgroundImageHint,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted),
                ),
                const SizedBox(height: 10),
                if (app.hasBackground)
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).push(AppearancePreviewPage.route()),
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
                    child: SizedBox(
                      height: 116,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(app.bgImagePath!), fit: BoxFit.cover),
                          Container(
                            color: Colors.black.withValues(alpha: 0.28),
                            alignment: Alignment.center,
                            child: Text(
                              '${(app.bgOpacity * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _picking ? null : _pickBackground,
                    icon: _picking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined, size: 17),
                    label: Text(l.pickImage),
                  ),
                ),
                if (app.hasBackground) ...[
                  const SizedBox(height: 12),
                  _SliderRow(
                    label: l.bgOpacity,
                    value: app.bgOpacity,
                    min: 0.15,
                    max: 1.0,
                    onChanged: app.setBgOpacity,
                    display: '${(app.bgOpacity * 100).round()}%',
                  ),
                  _SliderRow(
                    label: l.bgBlur,
                    value: app.bgBlur,
                    min: 0,
                    max: 24,
                    onChanged: app.setBgBlur,
                    display: app.bgBlur.round().toString(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? tk.accentSoft : tk.surfaceSunken,
            borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
            border: Border.all(
              color: selected ? tk.accent.withValues(alpha: 0.55) : tk.hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 19, color: selected ? tk.accentInk : tk.muted),
              const SizedBox(height: 5),
              Text(
                label,
                style: context.txt.labelSmall?.copyWith(
                  color: selected ? tk.accentInk : tk.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette, required this.selected, required this.onTap});

  final AccentPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: palette.color,
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 11),
          border: Border.all(
            color: selected ? tk.textStrong : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.title,
    required this.hint,
    required this.selected,
    required this.sharp,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool selected;
  final bool sharp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final radius = BorderRadius.circular(sharp ? 1 : 10);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? tk.accentSoft : tk.surfaceSunken,
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
          border: Border.all(
            color: selected ? tk.accent.withValues(alpha: 0.55) : tk.hairline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            // Miniature preview of the style
            SizedBox(
              width: 46,
              height: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 7,
                    width: 46,
                    decoration: BoxDecoration(color: tk.accent, borderRadius: radius),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 6,
                    width: 38,
                    decoration: BoxDecoration(
                      color: tk.hairline,
                      borderRadius: radius,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 6,
                    width: 30,
                    decoration: BoxDecoration(
                      color: tk.hairline,
                      borderRadius: radius,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.txt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? tk.accentInk : tk.textStrong,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hint,
                    style: context.txt.labelSmall?.copyWith(
                      color: tk.muted,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: tk.accent),
          ],
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? tk.accentSoft : tk.surfaceSunken,
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
          border: Border.all(
            color: selected ? tk.accent.withValues(alpha: 0.55) : tk.hairline,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: context.txt.labelMedium?.copyWith(
                color: selected ? tk.accentInk : tk.muted,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_rounded, size: 14, color: tk.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.display,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String display;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: context.txt.labelMedium?.copyWith(color: tk.muted)),
            const Spacer(),
            Text(
              display,
              style: context.txt.labelMedium?.copyWith(
                color: tk.textStrong,
                fontFeatures: tk.tabular,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Result of the colour sheet: `null` means "use the theme default".
class _ColorChoice {
  const _ColorChoice(this.color);

  final Color? color;
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.overridden,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool overridden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.txt.bodySmall?.copyWith(color: tk.textStrong),
              ),
            ),
            if (overridden)
              Text(
                'custom',
                style: context.txt.labelSmall?.copyWith(color: tk.muted, fontSize: 10),
              ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 13),
                border: Border.all(color: tk.hairline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSheet extends StatelessWidget {
  const _ColorSheet({required this.initial, required this.title});

  final Color? initial;
  final String title;

  static const List<Color> _swatches = [
    Color(0xFF15A66A),
    Color(0xFF34D399),
    Color(0xFF0D9488),
    Color(0xFF0EA5E9),
    Color(0xFF1670F5),
    Color(0xFF1D6FE0),
    Color(0xFFC2760A),
    Color(0xFFE08A00),
    Color(0xFFDC2626),
    Color(0xFFE23D3D),
    Color(0xFFD6459B),
    Color(0xFF7C5CFC),
    Color(0xFF5A6B84),
    Color(0xFF101827),
  ];

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: tk.surfaceCard,
        borderRadius: BorderRadius.circular(tk.style.isSharp ? 4 : 20),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.txt.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in _swatches)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(_ColorChoice(color)),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: initial?.toARGB32() == color.toARGB32()
                              ? tk.accent
                              : tk.hairline,
                          width: initial?.toARGB32() == color.toARGB32() ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(const _ColorChoice(null)),
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: Text(l.statusColorReset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
