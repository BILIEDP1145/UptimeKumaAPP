import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/l10n/l10n.dart';
import '../data/models/status_page.dart';
import 'sound_library.dart';

/// Wraps `flutter_local_notifications` and owns the alert presentation rules
/// (dedupe, channel-per-sound, fault payload).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Plays the tone ourselves while the app is in the foreground.
  ///
  /// Some Android 16 builds simply never start the channel sound, and no amount
  /// of channel configuration fixes that. Playing locally guarantees the user
  /// hears the alert while they are looking at the app.
  final AudioPlayer _inAppPlayer = AudioPlayer();

  Future<void> _playInApp(SoundOption sound) async {
    if (sound.isSilent) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      await _inAppPlayer.stop();
      if (sound.isCustom) {
        final path = sound.localPath;
        if (path == null || path.isEmpty || !File(path).existsSync()) return;
        await _inAppPlayer.play(DeviceFileSource(path));
      } else {
        await _inAppPlayer.play(
          AssetSource(sound.assetPath.replaceFirst('assets/', '')),
        );
      }
    } catch (e) {
      debugPrint('in-app tone failed: $e');
    }
  }

  bool _ready = false;
  bool _permission = false;

  bool get ready => _ready;
  bool get permissionGranted => _permission;

  Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      // A flat white vector, not the launcher icon: since API 36 Android
      // rejects adaptive icons as notification small icons, and a rejected
      // icon means the notification never appears at all.
      android: AndroidInitializationSettings('ic_stat_uk'),
    );
    try {
      await _plugin.initialize(settings: settings);
      _ready = true;
      await refreshPermission();
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
    }
  }

  Future<bool> refreshPermission() async {
    if (!Platform.isAndroid) {
      _permission = false;
      return false;
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      _permission = await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      _permission = false;
    }
    return _permission;
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      _permission = granted;
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Channels are created explicitly instead of lazily on first `show`.
  ///
  /// A channel that was created silently (or rewritten by an OS upgrade) can
  /// never get its sound back, so we make sure the one we are about to use
  /// exists with the right audio and, when it does not, say so through
  /// [channelIsSilent] instead of pretending everything is fine.
  final Set<String> _channelsReady = {};

  Future<void> ensureChannel(SoundOption sound, {bool silent = false}) async {
    final id = sound.channelId();
    if (_channelsReady.contains(id)) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          id,
          sound.labelEn,
          description: 'Uptime Kuma monitor state changes',
          importance: Importance.max,
          playSound: !silent && !sound.isSilent,
          sound: _soundFor(sound, silent: silent),
          enableVibration: !silent,
        ),
      );
      _channelsReady.add(id);
    } catch (e) {
      debugPrint('ensureChannel failed: $e');
    }
  }

  AndroidNotificationSound? _soundFor(SoundOption sound, {bool silent = false}) {
    if (silent || sound.isSilent) return null;
    return sound.contentUri != null
        ? UriAndroidNotificationSound(sound.contentUri!)
        : RawResourceAndroidNotificationSound(sound.rawName);
  }

  /// Plain-text snapshot of what Android actually reports. When a tone stops
  /// working there is nothing to guess: either the permission is off, the
  /// channel is missing, or its importance/sound is wrong — this prints which.
  Future<List<String>> diagnose(SoundOption sound) async {
    final lines = <String>[];
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      lines.add('plugin ready: $_ready');
      lines.add('notifications enabled: ${await android?.areNotificationsEnabled() ?? false}');
      lines.add('wanted channel: ${sound.channelId()}');
      lines.add('wanted sound: ${sound.contentUri ?? sound.rawName}');
      final channels = await android?.getNotificationChannels() ?? const [];
      lines.add('channels: ${channels.length}');
      for (final channel in channels) {
        if (!channel.id.startsWith('uk_alerts')) continue;
        lines.add(
          '· ${channel.id} | importance=${channel.importance.name} '
          '| playSound=${channel.playSound} | sound=${channel.sound ?? 'null'}',
        );
      }
      final pending = await _plugin.pendingNotificationRequests();
      lines.add('pending: ${pending.length}');
    } catch (e) {
      lines.add('diagnose failed: $e');
    }
    return lines;
  }

  /// True when the system reports no audio for the channel we would use — the
  /// usual symptom of a channel that was silenced by the OS.
  Future<bool> channelIsSilent(SoundOption sound) async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final channels = await android?.getNotificationChannels();
      if (channels == null) return false;
      for (final channel in channels) {
        if (channel.id == sound.channelId()) {
          return channel.sound == null;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  AndroidNotificationDetails _details({
    required SoundOption sound,
    required bool isDown,
    bool silent = false,
  }) {
    return AndroidNotificationDetails(
      sound.channelId(),
      sound.labelEn,
      channelDescription: 'Uptime Kuma monitor state changes',
      importance: Importance.max,
      priority: Priority.high,
      // Deliberately NOT CATEGORY_ALARM: since Android 15 that category wants
      // exact-alarm permission we do not ask for, and without it the system
      // keeps the notification but drops its sound. `reminder` is the correct
      // semantic for "this monitor changed state".
      category: AndroidNotificationCategory.reminder,
      // `notification` is what Android expects here; `alarm` made the system
      // refuse to play on devices whose DND rules only whitelist real alarms.
      audioAttributesUsage: AudioAttributesUsage.notification,
      playSound: !silent && !sound.isSilent,
      sound: _soundFor(sound, silent: silent),
      enableVibration: !silent,
      enableLights: true,
      color: isDown ? const Color(0xFFDC2626) : const Color(0xFF15A66A),
      styleInformation: const BigTextStyleInformation(''),
      icon: 'ic_stat_uk',
      ticker: 'Uptime Kuma',
      autoCancel: true,
      ongoing: false,
      groupKey: 'uk_alerts',
    );
  }

  Future<void> showFault({
    required L10n l10n,
    required Monitor monitor,
    required String instanceName,
    required DateTime startedAt,
    required SoundOption sound,
    String? detail,
    String? downtime,
    int? notificationId,
    bool inApp = false,
  }) async {
    if (!_ready) await init();
    await ensureChannel(sound);
    if (inApp) unawaited(_playInApp(sound));
    final body = l10n.notifDownBody(
      status: l10n.statusDown,
      startTime: _formatTime(startedAt),
      instance: instanceName,
      detail: detail,
      downtime: downtime,
    );
    await _show(
      id: notificationId ?? _idFor(instanceName, monitor.id),
      title: l10n.notifDownTitle(monitor.name),
      body: body,
      details: _details(sound: sound, isDown: true),
      payload: '${monitor.id}|down',
    );
  }

  Future<void> showRecovery({
    required L10n l10n,
    required Monitor monitor,
    required String instanceName,
    required DateTime recoveredAt,
    required SoundOption sound,
    String? downtime,
    String? detail,
    int? notificationId,
    bool inApp = false,
  }) async {
    if (!_ready) await init();
    await ensureChannel(sound);
    if (inApp) unawaited(_playInApp(sound));
    final body = l10n.notifUpBody(
      status: l10n.statusUp,
      startTime: _formatTime(recoveredAt),
      instance: instanceName,
      downtime: downtime,
      detail: detail,
    );
    await _show(
      id: notificationId ?? _idFor(instanceName, monitor.id),
      title: l10n.notifUpTitle(monitor.name),
      body: body,
      details: _details(sound: sound, isDown: false),
      payload: '${monitor.id}|up',
    );
  }

  Future<void> showTest({
    required L10n l10n,
    required SoundOption sound,
  }) async {
    if (!_ready) await init();
    await ensureChannel(sound);
    // The test button must produce sound even when the system swallows the
    // notification audio, otherwise it is impossible to tell the two apart.
    unawaited(_playInApp(sound));
    await _show(
      id: 900001,
      title: l10n.testNotifTitle,
      body: l10n.testNotifBody,
      details: _details(sound: sound, isDown: true),
      payload: 'test',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
        payload: payload,
      );
    } catch (e) {
      debugPrint('show notification failed: $e');
    }
  }

  // Persistent status notification -----------------------------------------

  static const int persistentId = 900000;
  static const String _persistentChannelId = 'uk_status_idle';

  /// A silent, non-dismissible "monitoring" entry in the shade.
  ///
  /// It is a plain ongoing notification, not a foreground service: Android 15
  /// caps `dataSync` foreground services at six hours a day, and a real always-on
  /// service is a much bigger trade than this switch deserves. The entry lives
  /// as long as the app process does.
  Future<void> showPersistent({required L10n l10n}) async {
    if (!_ready) await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _persistentChannelId,
          'Monitoring',
          description: 'Silent status entry while the app is open',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
      await _plugin.show(
        id: persistentId,
        title: l10n.persistentTitle,
        body: l10n.persistentBody,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _persistentChannelId,
            'Monitoring',
            channelDescription: 'Silent status entry while the app is open',
            importance: Importance.low,
            priority: Priority.low,
            icon: 'ic_stat_uk',
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            showWhen: false,
            category: AndroidNotificationCategory.service,
          ),
        ),
      );
    } catch (e) {
      debugPrint('persistent notification failed: $e');
    }
  }

  Future<void> hidePersistent() async {
    try {
      await _plugin.cancel(id: persistentId);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<List<PendingNotificationRequest>> pending() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }

  static int _idFor(String instance, int monitorId) {
    return (instance.hashCode ^ (monitorId * 7919)) & 0x7FFFFFFF;
  }

  static String _formatTime(DateTime t) {
    final local = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
