import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_background.dart';
import '../../state/app_state.dart';
import '../admin/admin_page.dart';
import '../dashboard/dashboard_page.dart';
import '../servers/servers_page.dart';
import '../settings/settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _TabSpec {
  const _TabSpec({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
    required this.key,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;
  final String key;
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final app = context.watch<AppState>();
    final manage = app.activeServer?.isManage ?? false;

    final tabs = <_TabSpec>[
      _TabSpec(
        key: 'status',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: l.navStatus,
        page: const DashboardPage(),
      ),
      if (manage)
        _TabSpec(
          key: 'manage',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: l.navManage,
          page: const AdminPage(),
        ),
      _TabSpec(
        key: 'servers',
        icon: Icons.dns_outlined,
        selectedIcon: Icons.dns_rounded,
        label: l.navServers,
        page: const ServersPage(),
      ),
      _TabSpec(
        key: 'settings',
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune_rounded,
        label: l.navSettings,
        page: const SettingsPage(),
      ),
    ];

    final index = _index.clamp(0, tabs.length - 1);
    final navBottom = MediaQuery.viewPaddingOf(context).bottom;

    // The photo sits *behind* the Scaffold rather than inside its body: when the
    // keyboard resizes the body, a `BoxFit.cover` image inside it re-scales,
    // which looked like the whole background jumping. Positioned outside, it
    // keeps its size and the keyboard only moves the content.
    return Stack(
      fit: StackFit.expand,
      children: [
        AppBackground(
          imagePath: app.hasBackground ? app.bgImagePath : null,
          opacity: app.bgOpacity,
          blur: app.bgBlur,
          child: const SizedBox.expand(),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: index,
            children: [
              for (final tab in tabs) KeyedSubtree(key: ValueKey(tab.key), child: tab.page),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: tk.surfaceCard,
          border: Border(top: BorderSide(color: tk.hairline)),
          boxShadow: tk.style.isSharp
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
        ),
        // Filling the gesture inset keeps the bar anchored to the screen edge
        // instead of floating over the background after a route pop.
        child: Padding(
          padding: EdgeInsets.only(bottom: navBottom),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: index == i ? tabs[i].selectedIcon : tabs[i].icon,
                      label: tabs[i].label,
                      selected: index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
    final color = selected ? tk.accentInk : tk.muted;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? tk.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 10),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.txt.labelSmall?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
