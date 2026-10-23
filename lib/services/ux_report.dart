import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/net/uk_http.dart';
import 'settings_store.dart';

/// The one and only outbound telemetry call, gated behind an explicit switch
/// in Settings → Privacy. It is a bare GET: no identifiers, no payload.
class UxReport {
  UxReport._();

  static const String endpoint =
      'https://api.2409178.xyz/data/zakoflare/web.php?add=1';

  /// Cold-start ping. Never awaited by the UI, never throws.
  static Future<void> pingOnColdStart(SettingsStore store) async {
    if (!store.uxReport) return;
    final client = UkHttp.build(
      doh: store.dohEnabled,
      dohEndpoint: store.dohEndpoint,
      userAgent: store.userAgent,
    );
    try {
      await client
          .get(Uri.parse(endpoint), headers: const {'Accept': '*/*'})
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('ux report skipped: $e');
    } finally {
      client.close();
    }
  }
}
