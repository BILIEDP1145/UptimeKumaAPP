import 'dart:async';

import 'package:flutter/material.dart';

import 'core/l10n/l10n.dart';

import 'app.dart';
import 'data/cache/image_cache.dart';
import 'services/foreground_service.dart';
import 'services/notification_service.dart';
import 'services/settings_store.dart';
import 'services/ux_report.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warms the image-cache directory handle, so logos can be read synchronously
  // on the first frame instead of flashing an empty badge.
  await ImageDiskCache.instance.warmUp();

  final store = await SettingsStore.open();
  final appState = AppState(store);

  await NotificationService.instance.init();

  // Neither the pinned entry nor the service survives a process restart.
  final startupL10n = L10n(Locale(store.localeCode ?? 'zh'));
  if (NotificationService.instance.permissionGranted) {
    if (appState.foregroundService) {
      unawaited(ForegroundService.start(
        title: startupL10n.persistentTitle,
        body: startupL10n.persistentBody,
      ));
    } else if (appState.persistentNotification) {
      unawaited(NotificationService.instance.showPersistent(l10n: startupL10n));
    }
  }

  runApp(UptimeKumaApp(appState: appState));

  // Fire-and-forget: only runs when the user opted in.
  unawaited(UxReport.pingOnColdStart(store));
}
