import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../state/app_state.dart';
import 'about_page.dart';
import 'appearance_page.dart';
import 'data_page.dart';
import 'icon_page.dart';
import 'notifications_page.dart';
import 'privacy_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tk.pagePadding.left + 2,
              topPad + 18,
              tk.pagePadding.right,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.navSettings, style: context.txt.headlineSmall),
                const SizedBox(height: 3),
                Text(
                  '${l.appTitle} · ${l.settingsAbout}',
                  style: context.txt.bodySmall?.copyWith(color: tk.muted),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            tk.pagePadding.left,
            0,
            tk.pagePadding.right,
            MediaQuery.viewPaddingOf(context).bottom + 28,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NavRow(
                      icon: Icons.palette_outlined,
                      title: l.settingsAppearance,
                      subtitle:
                          '${app.accent.label(l.zh)} · ${app.uiStyle.isSharp ? l.uiStyleTencent : l.uiStyleKuma}',
                      onTap: () => _push(context, const AppearancePage()),
                    ),
                    _Divider(),
                    _NavRow(
                      icon: Icons.notifications_active_outlined,
                      title: l.settingsNotifications,
                      subtitle: app.notificationsEnabled
                          ? '${l.enableNotifications} · ${app.sound.label(l.zh)}'
                          : l.notifications,
                      onTap: () => _push(context, const NotificationsPage()),
                      badge: app.notificationsEnabled ? null : 'OFF',
                    ),
                    _Divider(),
                    _NavRow(
                      icon: Icons.folder_outlined,
                      title: l.settingsData,
                      subtitle: '${l.cacheSize} · ${l.clearCache}',
                      onTap: () => _push(context, const DataPage()),
                    ),
                    _Divider(),
                    _NavRow(
                      icon: Icons.apps_rounded,
                      title: l.appIcon,
                      subtitle: l.appIconHint,
                      onTap: () => _push(context, const IconPage()),
                    ),
                    _Divider(),
                    _NavRow(
                      icon: Icons.shield_outlined,
                      title: l.settingsPrivacy,
                      subtitle: app.uxReport
                          ? '${l.privacyUxTitle} · ${l.privacyDohTitle}'
                          : l.privacyDataNote,
                      onTap: () => _push(context, const PrivacyPage()),
                    ),
                    _Divider(),
                    _NavRow(
                      icon: Icons.info_outline_rounded,
                      title: l.settingsAbout,
                      subtitle: l.aboutVersion,
                      onTap: () => _push(context, const AboutPage()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Uptime Kuma Mobile',
                      style: context.txt.labelMedium?.copyWith(color: tk.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ZAKOFLARE & MILLENNIUMIC',
                      style: context.txt.labelSmall?.copyWith(
                        color: tk.muted.withValues(alpha: 0.7),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Divider(height: 1, color: tk.hairline, indent: 52, endIndent: 14);
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tk.style.isSharp ? 12 : 14,
          vertical: tk.style.isSharp ? 11 : 13,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tk.accentSoft,
                borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 9),
              ),
              child: Icon(icon, size: 16, color: tk.accentInk),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: context.txt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tk.textStrong,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        AppChip(label: badge!, color: tk.muted, dense: true),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 19, color: tk.muted),
          ],
        ),
      ),
    );
  }
}
