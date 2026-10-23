import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/core/l10n/l10n.dart';
import 'package:uptime_kuma_app/core/theme/app_theme.dart';
import 'package:uptime_kuma_app/core/theme/app_tokens.dart';
import 'package:uptime_kuma_app/core/theme/palettes.dart';
import 'package:uptime_kuma_app/core/utils/status_ui.dart';
import 'package:uptime_kuma_app/core/widgets/app_card.dart';
import 'package:uptime_kuma_app/core/widgets/heartbeat_bar.dart';
import 'package:uptime_kuma_app/core/widgets/ping_chart.dart';
import 'package:uptime_kuma_app/data/models/status_page.dart';

/// Renders the shared widgets under every combination of theme, style and
/// locale. This is the cheapest way to catch token/extension mistakes without a
/// device.
void main() {
  final samples = <Heartbeat>[
    for (var i = 0; i < 60; i++)
      Heartbeat(
        status: i == 12 || i == 13
            ? MonitorStatus.down
            : i == 40
                ? MonitorStatus.pending
                : MonitorStatus.up,
        time: DateTime.utc(2026, 10, 17, 0, i),
        ping: 80.0 + (i % 7) * 12,
      ),
  ];

  Widget harness({
    required Brightness brightness,
    required UiStyle style,
    required Locale locale,
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: L10n.supported,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(
        brightness: brightness,
        palette: AccentPalette.all.first,
        style: style,
      ),
      home: Builder(
        builder: (context) {
          final tk = context.tk;
          return Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    accentStripe: true,
                    child: Row(
                      children: [
                        StatusDot(status: MonitorStatus.down),
                        const SizedBox(width: 8),
                        StatusBadge(status: MonitorStatus.up),
                        const SizedBox(width: 8),
                        StatusBadge(status: MonitorStatus.pending, dense: true),
                        const SizedBox(width: 8),
                        StatusBadge(status: MonitorStatus.maintenance, dense: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(title: 'Group', trailing: AppChip(label: '3', dense: true)),
                        HeartbeatBar(heartbeats: samples, height: 30),
                        const SizedBox(height: 10),
                        UptimeBar(ratio: 0.998),
                        const SizedBox(height: 10),
                        SizedBox(height: 120, child: PingChart(heartbeats: samples)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Text(
                      '${tk.style.name} ${Theme.of(context).brightness.name}',
                      style: TextStyle(color: tk.textStrong, fontFeatures: tk.tabular),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  for (final brightness in Brightness.values) {
    for (final style in UiStyle.values) {
      for (final locale in const [Locale('zh'), Locale('en')]) {
        testWidgets(
          'renders $style / ${brightness.name} / ${locale.languageCode}',
          (tester) async {
            await tester.pumpWidget(
              harness(brightness: brightness, style: style, locale: locale),
            );
            await tester.pump(const Duration(milliseconds: 60));
            expect(tester.takeException(), isNull);
            // Sanity: the style marker text actually rendered.
            expect(find.textContaining(style.name), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('empty heartbeat list degrades gracefully', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(
          brightness: Brightness.light,
          palette: AccentPalette.all.first,
          style: UiStyle.kuma,
        ),
        home: const Scaffold(body: HeartbeatBar(heartbeats: [])),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // Regression: a pulsing ring used to grow the dot from 8 to 22 px every
  // frame, so a failing monitor shifted its whole row. The dot must own the
  // same footprint in every state, animated or not.
  testWidgets('status dot keeps a fixed footprint in every state', (tester) async {
    for (final status in MonitorStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(
            brightness: Brightness.light,
            palette: AccentPalette.all.first,
            style: UiStyle.kuma,
          ),
          home: Scaffold(
            body: Row(
              children: [
                StatusDot(status: status, size: 7),
                StatusDot(status: status, size: 9),
              ],
            ),
          ),
        ),
      );
      // Let any (unwanted) animation advance and re-measure.
      await tester.pump(const Duration(milliseconds: 800));

      final dots = find.byType(StatusDot);
      expect(dots, findsNWidgets(2));
      expect(tester.getSize(dots.at(0)), const Size(7, 7), reason: status.name);
      expect(tester.getSize(dots.at(1)), const Size(9, 9), reason: status.name);
    }
  });
}
