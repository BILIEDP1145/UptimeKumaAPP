import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../state/app_state.dart';
import '../servers/server_edit_page.dart';

/// First-run screen. The app ships with no instances at all — everything the
/// user sees later comes from their own server.
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            tk.pagePadding.left,
            topPad + 40,
            tk.pagePadding.right,
            bottomPad + 28,
          ),
          children: [
            _Mark(size: 64),
            const SizedBox(height: 22),
            Text(l.guideHeadline, style: context.txt.headlineSmall),
            const SizedBox(height: 8),
            Text(
              l.guideLead,
              style: context.txt.bodyMedium?.copyWith(color: tk.muted, height: 1.5),
            ),
            const SizedBox(height: 26),
            _Step(
              index: 1,
              icon: Icons.dns_outlined,
              title: l.guideStep1Title,
              body: l.guideStep1Body,
            ),
            const SizedBox(height: 12),
            _Step(
              index: 2,
              icon: Icons.tune_outlined,
              title: l.guideStep2Title,
              body: l.guideStep2Body,
            ),
            const SizedBox(height: 12),
            _Step(
              index: 3,
              icon: Icons.monitor_heart_outlined,
              title: l.guideStep3Title,
              body: l.guideStep3Body,
            ),
            const SizedBox(height: 28),
            _PrimaryButton(
              label: l.guideAddNow,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const ServerEditPage()),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: tk.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l.guideNoPreset,
                    style: context.txt.labelSmall?.copyWith(
                      color: tk.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The official Uptime Kuma mark, drawn from the bundled asset.
class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tk.style.isSharp ? 4 : size * 0.26),
        boxShadow: tk.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/icon_official.png',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: tk.accent,
          child: Icon(Icons.monitor_heart, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int index;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tk.accentSoft,
              borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 10),
            ),
            child: Icon(icon, size: 17, color: tk.accentInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$index.',
                      style: context.txt.labelSmall?.copyWith(
                        color: tk.accentInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        title,
                        style: context.txt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tk.textStrong,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: tk.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 14),
          ),
        ),
        child: Text(
          label,
          style: context.txt.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Convenience used by the servers page too.
void openAddServer(BuildContext context) {
  final app = context.read<AppState>();
  if (app.servers.isEmpty) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ServerEditPage()),
    );
    return;
  }
  Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const ServerEditPage()),
  );
}
