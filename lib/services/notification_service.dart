import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
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

  bool _ready = false;
  bool _permission = false;

  bool get ready => _ready;
  bool get permissionGranted => _permission;

  Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      category: AndroidNotificationCategory.alarm,
      playSound: !silent,
      sound: silent
          ? null
          : (sound.contentUri != null
              ? UriAndroidNotificationSound(sound.contentUri!)
              : RawResourceAndroidNotificationSound(sound.rawName)),
      enableVibration: !silent,
      enableLights: true,
      color: isDown ? const Color(0xFFDC2626) : const Color(0xFF15A66A),
      styleInformation: const BigTextStyleInformation(''),
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
  }) async {
    if (!_ready) await init();
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
  }) async {
    if (!_ready) await init();
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
