import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uptime_kuma_app/core/l10n/l10n.dart';
import 'package:uptime_kuma_app/core/theme/app_theme.dart';
import 'package:uptime_kuma_app/core/theme/app_tokens.dart';
import 'package:uptime_kuma_app/core/theme/palettes.dart';
import 'package:uptime_kuma_app/data/models/server_config.dart';
import 'package:uptime_kuma_app/data/models/status_page.dart';
import 'package:uptime_kuma_app/features/dashboard/dashboard_page.dart';
import 'package:uptime_kuma_app/services/settings_store.dart';
import 'package:uptime_kuma_app/state/app_state.dart';
import 'package:uptime_kuma_app/state/status_controller.dart';

/// Renders the real dashboard against a fixed snapshot. Catches layout
/// overflows on narrow screens and breaks the theme permutations, without
/// touching the network.
void main() {
  StatusSnapshot buildSnapshot() {
    final now = DateTime.now().toUtc();
    List<Heartbeat> beats({int downAt = -1, double base = 90}) => [
          for (var i = 0; i < 50; i++)
            Heartbeat(
              // A real outage runs to the end of the strip, so the last sample
              // decides the monitor's current state.
              status: downAt >= 0 && i >= downAt
                  ? MonitorStatus.down
                  : i == 20
                      ? MonitorStatus.pending
                      : MonitorStatus.up,
              time: now.subtract(Duration(minutes: 50 - i)),
              msg: i == downAt ? 'connect ECONNREFUSED 10.0.0.4:443' : '',
              ping: base + (i % 5) * 11,
            ),
        ];

    return StatusSnapshot(
      config: const StatusPageConfig(
        slug: 'main',
        title: 'ZAKOFLARE & MILLENNIUMIC Operation Status',
        footerText: 'Infrastructure by ZAKOFLARE',
      ),
      groups: [
        // Kuma publishes a parent group as a list of `type == 'group'` headers;
        // it must not render as an empty card.
        const MonitorGroup(
          id: 99,
          name: 'Overview',
          monitors: [
            Monitor(id: 90, name: 'Public service', type: 'group'),
            Monitor(id: 91, name: 'ServiceNodeCN', type: 'group'),
          ],
        ),
        MonitorGroup(
          id: 1,
          name: 'Public service',
          monitors: const [
            Monitor(id: 1, name: '官网[LNTL]', type: 'http', certExpiryDays: 24, certValid: true),
            Monitor(id: 2, name: 'ZFC & MICC Public DoH', type: 'http', certExpiryDays: 8, certValid: true),
            Monitor(id: 3, name: 'United States/California/Los Angeles/Monterey Park/ZFC', type: 'ping'),
          ],
        ),
        MonitorGroup(
          id: 2,
          name: 'ServiceNodeCN',
          monitors: const [
            Monitor(id: 4, name: '中国/北京/阿里云计算/ZFC', type: 'ping'),
            Monitor(id: 5, name: '中国/陕西/西安/北经济技术开发区/未央区凤城/电信', type: 'ping'),
          ],
        ),
      ],
      heartbeats: {
        1: beats(),
        2: beats(downAt: 47),
        3: beats(base: 210),
        4: beats(base: 38),
        5: beats(base: 150),
      },
      uptime: const {
        '1_24': 0.9997,
        '2_24': 0.9412,
        '3_24': 1.0,
        '4_24': 0.9998,
        '5_24': 0.9971,
      },
      fetchedAt: now,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required UiStyle style,
    required Brightness brightness,
    required Size size,
    required Locale locale,
    bool showSla = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final app = AppState(store);
    // The dashboard refuses to render without an active instance, so register
    // one up front. Nothing in this test touches the network.
    await app.addServer(
      const ServerConfig(
        id: 'test',
        name: 'ZAKOFLARE',
        baseUrl: 'https://status.example.com',
        slug: 'main',
      ),
    );
    if (showSla) app.setShowSla(true);
    final controller = StatusController(app, seedSnapshot: buildSnapshot());

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          ChangeNotifierProvider<StatusController>.value(value: controller),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: L10n.supported,
          localizationsDelegates: L10n.delegates(),
          theme: AppTheme.build(
            brightness: brightness,
            palette: AccentPalette.all.first,
            style: style,
          ),
          home: const Scaffold(body: DashboardPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    for (final style in UiStyle.values) {
      testWidgets(
        'dashboard ${style.name} ${size.width.toInt()}px',
        (tester) async {
          await pumpDashboard(
            tester,
            style: style,
            brightness: Brightness.light,
            size: size,
            locale: const Locale('zh'),
          );
          expect(tester.takeException(), isNull);
          // Real content must be on screen, not an empty/error state.
          expect(find.text('官网[LNTL]'), findsOneWidget);
          expect(find.text('Public service'), findsOneWidget);
        },
      );
    }
  }

  testWidgets('dashboard survives dark theme and English', (tester) async {
    await pumpDashboard(
      tester,
      style: UiStyle.kuma,
      brightness: Brightness.dark,
      size: const Size(360, 640),
      locale: const Locale('en'),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('monitors'), findsWidgets);
  });

  testWidgets('a group collapses to its name, count and average SLA', (tester) async {
    await pumpDashboard(
      tester,
      style: UiStyle.kuma,
      brightness: Brightness.light,
      size: const Size(412, 915),
      locale: const Locale('zh'),
      showSla: true,
    );
    expect(find.text('官网[LNTL]'), findsOneWidget);

    // Collapse the first group by tapping its header.
    await tester.tap(find.text('Public service').first);
    await tester.pumpAndSettle();

    expect(find.text('官网[LNTL]'), findsNothing);
    // The group header keeps a percentage for the group as a whole.
    final percents = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => RegExp(r'^\d+\.\d{2}%$').hasMatch(s))
        .toList();
    expect(percents, isNotEmpty, reason: 'average SLA missing from the header');

    // Expanding brings the rows back.
    await tester.tap(find.text('Public service').first);
    await tester.pumpAndSettle();
    expect(find.text('官网[LNTL]'), findsOneWidget);
  });

  testWidgets('a group with no real monitors is not rendered', (tester) async {
    await pumpDashboard(
      tester,
      style: UiStyle.kuma,
      brightness: Brightness.light,
      size: const Size(412, 915),
      locale: const Locale('zh'),
    );
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Public service'), findsOneWidget);
  });

  testWidgets('a failing monitor is surfaced in the header', (tester) async {
    await pumpDashboard(
      tester,
      style: UiStyle.tencentCloud,
      brightness: Brightness.light,
      size: const Size(412, 915),
      locale: const Locale('zh'),
    );
    expect(tester.takeException(), isNull);
    // One monitor is down in the fixture, so the partial-outage headline shows.
    expect(find.text('部分服务异常'), findsOneWidget);
  });
}
