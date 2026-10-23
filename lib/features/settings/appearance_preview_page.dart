import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/status_ui.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/heartbeat_bar.dart';
import '../../data/models/status_page.dart';
import '../../state/app_state.dart';

/// Live preview of the appearance settings, on top of the user's own photo.
///
/// Settings pages are deliberately opaque (so route transitions never
/// flickered), which left no way to judge the opacity / frosted-glass sliders.
/// This sheet paints the real widgets over the real background and exposes the
/// three relevant controls, so the decision is made by looking at it.
class AppearancePreviewPage extends StatelessWidget {
  const AppearancePreviewPage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => const AppearancePreviewPage(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);

    final headerAlpha =
        (app.uiOpacity * (app.headerGlass ? 0.62 : 1.0)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.previewTitle)),
      body: AppBackground(
        imagePath: app.hasBackground ? app.bgImagePath : null,
        opacity: app.bgOpacity,
        blur: app.bgBlur,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  tk.pagePadding.left,
                  10,
                  tk.pagePadding.right,
                  16,
                ),
                children: [
                  // Stand-in for the dashboard header.
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tk.headerFrom.withValues(alpha: headerAlpha),
                          tk.headerTo.withValues(alpha: headerAlpha),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 20),
                      border: app.headerGlass
                          ? Border.all(color: Colors.white.withValues(alpha: 0.18))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.previewInstance,
                          style: context.txt.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.previewSubtitle,
                          style: context.txt.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            StatusDot(status: MonitorStatus.up, size: 9),
                            const SizedBox(width: 8),
                            Text(
                              l.overallOperational,
                              style: context.txt.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _PreviewRow(name: l.previewMonitorA, status: MonitorStatus.up),
                        Divider(height: 1, color: tk.hairline, indent: 14, endIndent: 14),
                        _PreviewRow(name: l.previewMonitorB, status: MonitorStatus.down),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Text(
                      l.previewHint,
                      style: context.txt.labelSmall?.copyWith(
                        color: tk.muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Controls(app: app),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.name, required this.status});

  final String name;
  final MonitorStatus status;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final samples = <Heartbeat>[
      for (var i = 0; i < 24; i++)
        Heartbeat(
          status: i == 9 && status == MonitorStatus.down
              ? MonitorStatus.down
              : MonitorStatus.up,
          time: DateTime.utc(2026, 10, 18, 0, i),
          ping: 60 + (i % 5) * 8,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(status: status, size: 7),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: context.txt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tk.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          HeartbeatBar(heartbeats: samples, height: 18, maxBars: 24),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tk.pagePadding.left,
        0,
        tk.pagePadding.right,
        MediaQuery.viewPaddingOf(context).bottom + 10,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l.uiOpacityTitle, style: context.txt.bodySmall),
                const Spacer(),
                Text(
                  '${(app.uiOpacity * 100).round()}%',
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.textStrong,
                    fontFeatures: tk.tabular,
                  ),
                ),
              ],
            ),
            Slider(
              value: app.uiOpacity,
              min: 0.4,
              max: 1.0,
              onChanged: app.setUiOpacity,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(l.glassTitle, style: context.txt.bodySmall),
                ),
                Switch(value: app.glass, onChanged: app.setGlass),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(l.headerGlassTitle, style: context.txt.bodySmall),
                ),
                Switch(value: app.headerGlass, onChanged: app.setHeaderGlass),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
