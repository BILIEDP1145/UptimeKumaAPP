import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/l10n/l10n.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_background.dart';
import 'data/models/server_config.dart';
import 'data/net/uk_http.dart';
import 'data/models/status_page.dart';
import 'features/guide/guide_page.dart';
import 'features/shell/home_shell.dart';
import 'services/background_checks.dart';
import 'state/admin_controller.dart';
import 'state/app_state.dart';
import 'state/status_controller.dart';

class UptimeKumaApp extends StatefulWidget {
  const UptimeKumaApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<UptimeKumaApp> createState() => _UptimeKumaAppState();
}

class _UptimeKumaAppState extends State<UptimeKumaApp> {
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
      // Answers cached against the old resolver must not leak into the new one.
      DohResolver.clearCache();
      _status.onNetworkPrefsChanged();
    }
    if (app.userAgent != _lastUa) {
      _lastUa = app.userAgent;
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

  @override
  void dispose() {
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
            ),
            darkTheme: AppTheme.build(
              brightness: Brightness.dark,
              palette: app.accent,
              style: app.uiStyle,
            ),
            themeMode: app.resolvedThemeMode,
            locale: app.localeOverride,
            supportedLocales: L10n.supported,
            localizationsDelegates: L10n.delegates(),
            builder: (context, child) {
              return AppBackground(
                imagePath: app.hasBackground ? app.bgImagePath : null,
                opacity: app.bgOpacity,
                blur: app.bgBlur,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: app.servers.isEmpty ? const GuidePage() : const HomeShell(),
          );
        },
      ),
    );
  }
}
