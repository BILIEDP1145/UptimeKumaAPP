import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/cache/image_cache.dart';
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

  runApp(UptimeKumaApp(appState: appState));

  // Fire-and-forget: only runs when the user opted in.
  unawaited(UxReport.pingOnColdStart(store));
}
