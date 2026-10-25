import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/l10n/l10n.dart';
import 'core/theme/app_theme.dart';
import 'data/models/server_config.dart';
import 'data/models/share_code.dart';
import 'data/net/uk_http.dart';
import 'data/models/status_page.dart';
import 'features/guide/guide_page.dart';
import 'features/shell/home_shell.dart';
import 'services/background_checks.dart';
import 'services/deep_links.dart';
import 'state/admin_controller.dart';
import 'state/app_state.dart';
import 'state/status_controller.dart';

class UptimeKumaApp extends StatefulWidget {
  const UptimeKumaApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<UptimeKumaApp> createState() => _UptimeKumaAppState();
}

class _UptimeKumaAppState extends State<UptimeKumaApp>
    with WidgetsBindingObserver {
  late final StatusController _status;
  late final AdminController _admin;

  /// Snapshot of the settings that actually affect background scheduling, so
  /// dragging a slider does not re-register a WorkManager job 60 times a second.
  String _scheduleSignature = '';
  int _lastPollSeconds = 0;
  bool _lastDoh = false;
  String _lastDohUrl = '';
  String _lastUa = '';
  Timer? _uaDebounce;
  StreamSubscription<String>? _linkSub;

  /// Used by deep-link handling to show a dialog without a page context.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _admin = AdminController(widget.appState);
    _status = StatusController(
      widget.appState,
      snapshotBuilder: _buildAdminSnapshot,
    );
    _lastPollSeconds = widget.appState.pollSeconds;
    _lastDoh = widget.appState.dohEnabled;
    _lastDohUrl = widget.appState.dohUrl;
    _lastUa = widget.appState.userAgent;
    widget.appState.addListener(_onPrefsChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initDeepLinks());
    // Defer until the first frame so navigation/pages exist before data lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final active = widget.appState.activeServer;
      _admin.attach(active);
      _status.attach(active);
      _syncSchedule();
    });
  }

  /// Management-mode instances are driven by the authenticated session: they
  /// often have no published status page to read.
  Future<StatusSnapshot?> _buildAdminSnapshot(ServerConfig server) async {
    if (!server.isManage) return null;
    if (!_admin.signedIn) {
      if (server.hasSession) return null;
      return null;
    }
    if (_admin.data == null) await _admin.refresh();
    return _admin.buildSnapshot();
  }

  void _onPrefsChanged() {
    final app = widget.appState;
    final active = app.activeServer;
    final switched = active?.id != _status.server?.id || active?.mode != _status.server?.mode;
    if (switched) {
      _admin.attach(active);
      _status.attach(active);
      _lastPollSeconds = app.pollSeconds;
    } else if (app.pollSeconds != _lastPollSeconds) {
      _lastPollSeconds = app.pollSeconds;
      _status.onPollIntervalChanged();
    }

    if (app.dohEnabled != _lastDoh || app.dohUrl != _lastDohUrl) {
      _lastDoh = app.dohEnabled;
      _lastDohUrl = app.dohUrl;
      // Answers cached against the old resolver must not leak into the new one,
      // and pooled connections were opened with the previous settings.
      DohResolver.clearCache();
      UkHttp.resetShared();
      _status.onNetworkPrefsChanged();
    }
    if (app.userAgent != _lastUa) {
      _lastUa = app.userAgent;
      UkHttp.resetShared();
      // The UA field reports every keystroke; wait for the user to stop typing
      // before tearing down the HTTP client and refetching.
      _uaDebounce?.cancel();
      _uaDebounce = Timer(
        const Duration(milliseconds: 900),
        _status.onNetworkPrefsChanged,
      );
    }
    _syncSchedule();
  }

  void _syncSchedule() {
    if (!Platform.isAndroid) return;
    final app = widget.appState;
    final signature = '${app.backgroundChecks}|${app.notificationsEnabled}|${app.servers.length}';
    if (signature == _scheduleSignature) return;
    _scheduleSignature = signature;
    BackgroundChecks.syncSchedule(app);
  }

  /// Shared configuration links land here, whether the app was cold-started by
  /// one or was already running.
  Future<void> _initDeepLinks() async {
    await DeepLinks.init();
    _linkSub = DeepLinks.stream.listen(_handleLink);
    final initial = await DeepLinks.initial();
    if (initial != null) await _handleLink(initial);
  }

  Future<void> _handleLink(String url) async {
    final payload = ShareCode.parse(url);
    if (payload == null) return;
    final result = await widget.appState.importPayloads([payload]);
    if (result.added == 0 && result.skipped == 0) return;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l = L10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.skipped > 0
              ? l.importedCountSkipped(result.added, result.skipped)
              : l.importedCount(result.added),
        ),
      ),
    );
  }

  /// Coming back from the background: the socket may have died and the session
  /// with it, so re-authenticate before the user hits "save" and sees
  /// "You are not logged in.".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_admin.ensureSession());
    unawaited(_status.attach(widget.appState.activeServer));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _uaDebounce?.cancel();
    widget.appState.removeListener(_onPrefsChanged);
    _status.dispose();
    _admin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: widget.appState),
        ChangeNotifierProvider<StatusController>.value(value: _status),
        ChangeNotifierProvider<AdminController>.value(value: _admin),
      ],
      child: Consumer<AppState>(
        builder: (context, app, _) {
          return MaterialApp(
            title: 'Uptime Kuma',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(
              brightness: Brightness.light,
              palette: app.accent,
              style: app.uiStyle,
              flatGradients: app.flatGradients,
              glass: app.glass,
              uiOpacity: app.uiOpacity,
              statusUpColor: app.statusUpColor,
              statusDownColor: app.statusDownColor,
            ),
            darkTheme: AppTheme.build(
              brightness: Brightness.dark,
              palette: app.accent,
              style: app.uiStyle,
              flatGradients: app.flatGradients,
              glass: app.glass,
              uiOpacity: app.uiOpacity,
              statusUpColor: app.statusUpColor,
              statusDownColor: app.statusDownColor,
            ),
            themeMode: app.resolvedThemeMode,
            locale: app.localeOverride,
            supportedLocales: L10n.supported,
            localizationsDelegates: L10n.delegates(),
            // The photo lives behind the tab shell, not behind every route.
            // Painting it here meant each push/pop re-composited a full-screen
            // blur under a transparent page, which is exactly what flickered.
            builder: (context, child) => ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child ?? const SizedBox.shrink(),
            ),
            home: app.servers.isEmpty ? const GuidePage() : const HomeShell(),
          );
        },
      ),
    );
  }
}
