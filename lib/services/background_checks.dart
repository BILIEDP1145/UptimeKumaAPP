import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../core/l10n/l10n.dart';
import '../data/api/uk_api.dart';
import '../data/cache/cache_store.dart';
import '../data/models/server_config.dart';
import '../data/models/status_page.dart';
import '../services/settings_store.dart';
import '../services/sound_library.dart';
import '../state/app_state.dart';

const _taskName = 'ukStatusCheck';
const _uniqueName = 'ukStatusCheckPeriodic';
const _chainName = 'ukStatusCheckChain';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await BackgroundChecks.runOnce();
      return true;
    } catch (e) {
      debugPrint('background check failed: $e');
      return false;
    } finally {
      // Queue the next run in `finally`: a thrown check must not break the
      // chain, or background alerts stop permanently after one bad response.
      await BackgroundChecks.scheduleNext();
    }
  });
}

/// Periodic background polling so alerts keep arriving with the app closed.
class BackgroundChecks {
  static bool _initialised = false;

  static Future<void> ensureInitialised() async {
    if (_initialised || !Platform.isAndroid) return;
    try {
      await Workmanager().initialize(backgroundCallbackDispatcher);
      _initialised = true;
    } catch (e) {
      debugPrint('Workmanager init failed: $e');
    }
  }

  /// Registers or cancels the background work to match current settings.
  ///
  /// WorkManager refuses periodic intervals under 15 minutes, which is far too
  /// coarse for uptime monitoring. Below that threshold the work is scheduled as
  /// a chain of one-shot tasks; the system may still defer them while dozing,
  /// but in normal use they fire on time.
  static Future<void> syncSchedule(AppState app) async {
    if (!Platform.isAndroid) return;
    await ensureInitialised();
    if (!_initialised) return;

    try {
      if (!app.backgroundChecks || !app.notificationsEnabled || app.servers.isEmpty) {
        await Workmanager().cancelByUniqueName(_uniqueName);
        await Workmanager().cancelByUniqueName(_chainName);
        return;
      }

      final minutes = app.backgroundInterval;
      if (minutes >= 15) {
        await Workmanager().cancelByUniqueName(_chainName);
        await Workmanager().registerPeriodicTask(
          _uniqueName,
          _taskName,
          frequency: Duration(minutes: minutes),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          backoffPolicy: BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(minutes: 5),
        );
      } else {
        await Workmanager().cancelByUniqueName(_uniqueName);
        await _enqueueOnce(minutes);
      }
    } catch (e) {
      debugPrint('background schedule failed: $e');
    }
  }

  /// Queues the next chained run. Safe to call from the background isolate.
  static Future<void> scheduleNext() async {
    if (!Platform.isAndroid) return;
    await ensureInitialised();
    if (!_initialised) return;
    try {
      final store = await SettingsStore.open();
      if (!store.notificationsEnabled || !store.backgroundChecks) return;
      final minutes = store.backgroundInterval;
      if (minutes >= 15) {
        // A periodic task already exists; nothing to chain.
        return;
      }
      await _enqueueOnce(minutes);
    } catch (e) {
      debugPrint('reschedule failed: $e');
    }
  }

  static Future<void> _enqueueOnce(int minutes) async {
    await Workmanager().registerOneOffTask(
      _chainName,
      _taskName,
      initialDelay: Duration(minutes: minutes),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 2),
    );
  }

  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    await ensureInitialised();
    if (!_initialised) return;
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
      await Workmanager().cancelByUniqueName(_chainName);
    } catch (_) {}
  }

  /// Executed inside the background isolate as well as on demand from the UI
  /// ("run a check now").
  static Future<void> runOnce() async {
    final store = await SettingsStore.open();
    if (!store.notificationsEnabled) return;

    final servers = ServerConfig.decodeList(store.serversJson);
    if (servers.isEmpty) return;

    final activeId = store.activeServerId;
    final active = servers.firstWhere(
      (s) => s.id == activeId,
      orElse: () => servers.first,
    );

    // A collection is one board on screen, so it has to be one board here too:
    // checking only the active member silently ignored every sibling instance.
    final members = active.inCollection
        ? servers
            .where((s) =>
                s.collectionId == active.collectionId &&
                !s.isManage &&
                s.hasPublicPage)
            .toList(growable: false)
        : const <ServerConfig>[];
    final targets = members.length > 1 ? members : <ServerConfig>[active];

    final locale =
        store.localeCode == null ? const Locale('zh') : Locale(store.localeCode!);
    final l10n = L10n(locale);
    final sound = SoundOption.byId(
      store.soundId,
      customUri: store.customSoundUriValue,
      customLocalPath: store.customSoundPath,
    );

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        // Same monochrome icon as the in-app path; adaptive launcher icons are
        // rejected as small icons on API 36.
        android: AndroidInitializationSettings('ic_stat_uk'),
      ),
    );

    for (final server in targets) {
      await _checkServer(
        store: store,
        server: server,
        plugin: plugin,
        l10n: l10n,
        sound: sound,
      );
    }
  }

  static Future<void> _checkServer({
    required SettingsStore store,
    required ServerConfig server,
    required FlutterLocalNotificationsPlugin plugin,
    required L10n l10n,
    required SoundOption sound,
  }) async {
    final api = UkApi();
    StatusSnapshot snapshot;
    try {
      snapshot = await api.fetchSnapshot(server);
    } catch (_) {
      api.dispose();
      return;
    }
    api.dispose();

    final previous = await CacheStore.instance.readStatusMap(server.id);
    final isFirstRun = previous.isEmpty;
    final muted = _mutedFor(store, server.id);

    final next = <int, int>{};
    final now = DateTime.now();

    for (final monitor in snapshot.allMonitors) {
      final status = snapshot.statusOf(monitor.id);
      if (status == MonitorStatus.unknown) continue;
      next[monitor.id] = status.code;

      final prev = previous[monitor.id];
      // Never fire on a cold start where we have no baseline yet.
      if (isFirstRun || prev == null || prev == status.code) continue;

      if (muted.contains(monitor.id)) continue;

      if (status == MonitorStatus.down && store.notifyOnDown) {
        final since = _firstDownTime(snapshot, monitor.id) ?? now;
        await _notify(
          plugin: plugin,
          id: _idFor(server.name, monitor.id),
          title: l10n.notifDownTitle(monitor.name),
          body: l10n.notifDownBody(
            status: l10n.statusDown,
            startTime: _fmt(since),
            instance: server.name,
            detail: _lastMsg(snapshot, monitor.id),
          ),
          sound: sound,
          isDown: true,
        );
      } else if (prev == MonitorStatus.down.code &&
          status != MonitorStatus.down &&
          store.notifyOnUp) {
        await _notify(
          plugin: plugin,
          id: _idFor(server.name, monitor.id),
          title: l10n.notifUpTitle(monitor.name),
          body: l10n.notifUpBody(
            status: l10n.statusUp,
            startTime: _fmt(now),
            instance: server.name,
            detail: _lastMsg(snapshot, monitor.id),
          ),
          sound: sound,
          isDown: false,
        );
      }
    }

    await CacheStore.instance.writeStatusMap(server.id, next);
    await CacheStore.instance.writeSnapshot(server.id, snapshot);
  }

  /// Muted monitor ids for one instance, read from the shared preference blob.
  static Set<int> _mutedFor(SettingsStore store, String serverId) {
    final raw = store.mutedMonitorsJson;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final list = decoded[serverId];
      if (list is! List) return const {};
      return list.whereType<num>().map((n) => n.toInt()).toSet();
    } catch (_) {
      return const {};
    }
  }

  static Future<void> _notify({
    required FlutterLocalNotificationsPlugin plugin,
    required int id,
    required String title,
    required String body,
    required SoundOption sound,
    required bool isDown,
  }) async {
    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          sound.channelId(),
          sound.labelEn,
          channelDescription: 'Uptime Kuma monitor state changes',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_stat_uk',
          category: AndroidNotificationCategory.reminder,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          // A user tone lives in the media store; a bundled one is a raw
          // resource. Using rawName for a custom tone produced an empty id and
          // therefore a silent notification.
          sound: sound.contentUri != null
              ? UriAndroidNotificationSound(sound.contentUri!)
              : RawResourceAndroidNotificationSound(sound.rawName),
          enableVibration: true,
          color: isDown ? const Color(0xFFDC2626) : const Color(0xFF15A66A),
          styleInformation: const BigTextStyleInformation(''),
          groupKey: 'uk_alerts',
        ),
      ),
    );
  }

  static String _fmt(DateTime t) {
    final v = t.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${v.year}-${two(v.month)}-${two(v.day)} ${two(v.hour)}:${two(v.minute)}:${two(v.second)}';
  }

  static DateTime? _firstDownTime(StatusSnapshot snapshot, int monitorId) {
    final list = snapshot.heartbeatsOf(monitorId);
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].status == MonitorStatus.up) return null;
      if (list[i].status == MonitorStatus.down) {
        if (i == 0 || list[i - 1].status != MonitorStatus.down) {
          return list[i].time.toLocal();
        }
      }
    }
    return null;
  }

  static String? _lastMsg(StatusSnapshot snapshot, int monitorId) {
    final list = snapshot.heartbeatsOf(monitorId);
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].msg.trim().isNotEmpty) return list[i].msg.trim();
    }
    return null;
  }

  static int _idFor(String instance, int monitorId) =>
      (instance.hashCode ^ (monitorId * 7919)) & 0x7FFFFFFF;
}
