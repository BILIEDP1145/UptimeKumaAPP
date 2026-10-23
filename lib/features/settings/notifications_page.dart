import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../services/background_checks.dart';
import '../../services/notification_service.dart';
import '../../services/custom_sound_store.dart';
import '../../services/foreground_service.dart';
import '../../services/sound_library.dart';
import '../../state/app_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;
  bool _uploading = false;
  bool _permission = false;
  bool _channelSilent = false;
  String? _checkedSoundId;
  String? _diagnostics;

  Future<void> _runDiagnose() async {
    final sound = context.read<AppState>().sound;
    final lines = await NotificationService.instance.diagnose(sound);
    if (!mounted) return;
    setState(() => _diagnostics = lines.join('\n'));
  }

  @override
  void initState() {
    super.initState();
    _configureAudio();
    _refreshPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) => _repairCustomSound());
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  /// Explicit Android audio attributes.
  ///
  /// audioplayers defaults to a focus-less context, and Android 16 will not
  /// start an AudioTrack for an app that never requested focus — the preview
  /// then fails silently. `media` + `gain` is what an alarm tone needs.
  Future<void> _configureAudio() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            audioMode: AndroidAudioMode.normal,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
    } catch (e) {
      debugPrint('audio context: $e');
    }
  }

  /// Older installs stored only the media-store URI. Pull the file back once so
  /// previews and in-app playback have something real to open.
  Future<void> _repairCustomSound() async {
    if (!mounted) return;
    final app = context.read<AppState>();
    if (!app.sound.isCustom) return;
    if (app.customSoundPath.isNotEmpty) return;
    final uri = app.customSoundUri;
    if (uri.isEmpty) return;
    final recovered = await CustomSoundStore.recover(uri);
    if (recovered == null || !mounted) return;
    app.setCustomSound(uri: uri, path: recovered);
  }

  Future<void> _refreshChannel(SoundOption sound) async {
    final silent = await NotificationService.instance.channelIsSilent(sound);
    if (!mounted) return;
    if (silent != _channelSilent) setState(() => _channelSilent = silent);
  }

  Future<void> _refreshPermission() async {
    await NotificationService.instance.refreshPermission();
    if (!mounted) return;
    setState(() => _permission = NotificationService.instance.permissionGranted);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(SoundOption sound) async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_playingId == sound.id) {
        await _player.stop();
        setState(() => _playingId = null);
        return;
      }
      await _player.stop();

      if (sound.isCustom) {
        // A custom tone has no bundled asset — falling through to AssetSource
        // produced `assets/sounds/.wav` and an unreadable error. MediaPlayer
        // also cannot open a media-store URI (`setDataSource failed`), so the
        // file is restored from the store first.
        var path = sound.localPath;
        var hasLocal = path != null && path.isNotEmpty && File(path).existsSync();
        if (!hasLocal && (sound.contentUri ?? '').isNotEmpty) {
          final recovered = await CustomSoundStore.recover(sound.contentUri!);
          if (recovered != null) {
            path = recovered;
            hasLocal = true;
            if (mounted) {
              context.read<AppState>().setCustomSound(
                    uri: sound.contentUri!,
                    path: recovered,
                  );
            }
          }
        }
        if (!hasLocal || path == null) {
          messenger.showSnackBar(SnackBar(content: Text(l.previewFileMissing)));
          return;
        }
        await _player.play(DeviceFileSource(path));
      } else {
        await _player.play(AssetSource(sound.assetPath.replaceFirst('assets/', '')));
      }
      if (!mounted) return;
      setState(() => _playingId = sound.id);
    } catch (e) {
      // Never swallow this again: a silent failure looked like a dead button.
      if (!mounted) return;
      setState(() => _playingId = null);
      messenger.showSnackBar(SnackBar(content: Text('${l.previewFailed}: $e')));
    }
  }

  Future<void> _uploadSound() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppState>();

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'ogg', 'm4a', 'aac', 'flac'],
    );
    final source = picked.isEmpty ? null : picked.first.path;
    if (source == null) return;

    setState(() => _uploading = true);
    final installed = await CustomSoundStore.install(source);
    if (!mounted) return;
    setState(() => _uploading = false);

    if (installed == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.soundInstallFailed)));
      return;
    }
    app.setCustomSound(uri: installed.uri, path: installed.path);
    app.setSound(SoundOption.customId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          installed.uri.isEmpty ? l.soundPreviewOnly : l.soundInstalled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);

    // Re-check the channel whenever the selected tone changes.
    if (_checkedSoundId != app.sound.id) {
      _checkedSoundId = app.sound.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshChannel(app.sound));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l.settingsNotifications)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(tk.pagePadding.left, 4, tk.pagePadding.right, 28),
        children: [
          AppCard(
            child: Column(
              children: [
                _SwitchRow(
                  title: l.enableNotifications,
                  subtitle: l.enableNotificationsHint,
                  value: app.notificationsEnabled,
                  onChanged: (v) {
                    app.setNotificationsEnabled(v);
                    if (Platform.isAndroid) BackgroundChecks.syncSchedule(app);
                  },
                ),
                if (app.notificationsEnabled) ...[
                  Divider(height: 20, color: tk.hairline),
                  _SwitchRow(
                    title: l.notifyOnDown,
                    value: app.notifyOnDown,
                    onChanged: app.setNotifyDown,
                  ),
                  Divider(height: 20, color: tk.hairline),
                  _SwitchRow(
                    title: l.notifyOnUp,
                    value: app.notifyOnUp,
                    onChanged: app.setNotifyUp,
                  ),
                  Divider(height: 20, color: tk.hairline),
                  _SwitchRow(
                    title: l.inAppSoundTitle,
                    subtitle: l.inAppSoundBody,
                    value: app.inAppSound,
                    onChanged: app.setInAppSound,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bug_report_outlined, size: 17, color: tk.accentInk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.diagnosticsTitle, style: context.txt.titleSmall),
                    ),
                    TextButton(
                      onPressed: _runDiagnose,
                      child: Text(l.diagnosticsRun),
                    ),
                  ],
                ),
                Text(
                  l.diagnosticsHint,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
                ),
                if (_diagnostics != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tk.surfaceSunken,
                      borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 10),
                    ),
                    child: Text(
                      _diagnostics!,
                      style: context.txt.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        height: 1.5,
                        color: tk.textStrong,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _diagnostics!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.exportedToClipboard)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: Text(l.copyDiagnostics),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_channelSilent) ...[
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.volume_off_rounded, size: 18, color: tk.statusPending),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.channelSilentTitle, style: context.txt.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          l.channelSilentBody,
                          style: context.txt.labelSmall?.copyWith(
                            color: tk.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Permission
          AppCard(
            child: Row(
              children: [
                Icon(
                  _permission ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                  size: 18,
                  color: _permission ? tk.statusUp : tk.statusPending,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.notificationPermission, style: context.txt.titleSmall),
                      Text(
                        _permission ? l.permissionGranted : l.permissionDenied,
                        style: context.txt.labelSmall?.copyWith(
                          color: _permission ? tk.statusUp : tk.statusPending,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_permission)
                  TextButton(
                    onPressed: () async {
                      await NotificationService.instance.requestPermission();
                      await _refreshPermission();
                    },
                    child: Text(l.grantPermission),
                  )
                else
                  Icon(Icons.verified_rounded, size: 18, color: tk.statusUp),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sound
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.notifySound, style: context.txt.titleSmall),
                const SizedBox(height: 4),
                Text(
                  l.alertDetail,
                  style: context.txt.labelSmall?.copyWith(color: tk.muted),
                ),
                const SizedBox(height: 10),
                for (final s in SoundOption.all)
                  _SoundRow(
                    sound: s,
                    selected: app.sound.id == s.id,
                    playing: _playingId == s.id,
                    onSelect: () => app.setSound(s.id),
                    onPreview: () => _preview(s),
                  ),
                if (SoundOption.custom(app.customSoundUri) case final uploaded?)
                  _SoundRow(
                    sound: uploaded,
                    selected: app.sound.id == uploaded.id,
                    playing: false,
                    onSelect: () => app.setSound(uploaded.id),
                    onPreview: () => _preview(uploaded),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadSound,
                    icon: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded, size: 16),
                    label: Text(l.soundUpload),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.soundUploadHint,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await NotificationService.instance.showTest(
                        l10n: l,
                        sound: app.sound,
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text(l.testNotification),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Polling
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.pollInterval, style: context.txt.titleSmall),
                    const Spacer(),
                    Text(
                      l.pollIntervalValue(app.pollSeconds),
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final sec in const [30, 60, 120, 300]) ...[
                      Expanded(
                        child: _Chip(
                          label: l.pollIntervalValue(sec),
                          selected: app.pollSeconds == sec,
                          onTap: () => app.setPollSeconds(sec),
                        ),
                      ),
                      if (sec != 300) const SizedBox(width: 7),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Background checks
          AppCard(
            child: Column(
              children: [
                _SwitchRow(
                  title: l.backgroundCheck,
                  subtitle: Platform.isAndroid ? l.backgroundCheckHint : l.backgroundUnsupported,
                  value: app.backgroundChecks && Platform.isAndroid,
                  enabled: Platform.isAndroid,
                  onChanged: (v) {
                    app.setBackgroundChecks(v);
                    BackgroundChecks.syncSchedule(app);
                  },
                ),
                Divider(height: 20, color: tk.hairline),
                _SwitchRow(
                  title: l.persistentSwitch,
                  subtitle: l.persistentSwitchBody,
                  value: app.persistentNotification,
                  onChanged: (v) async {
                    app.setPersistentNotification(v);
                    if (!v) {
                      await NotificationService.instance.hidePersistent();
                      return;
                    }
                    final granted = NotificationService.instance.permissionGranted ||
                        await NotificationService.instance.requestPermission();
                    if (!granted) {
                      app.setPersistentNotification(false);
                      return;
                    }
                    await NotificationService.instance.showPersistent(l10n: l);
                  },
                ),
                Divider(height: 20, color: tk.hairline),
                _SwitchRow(
                  title: l.foregroundServiceTitle,
                  subtitle: l.foregroundServiceBody,
                  value: app.foregroundService,
                  onChanged: (v) async {
                    app.setForegroundService(v);
                    if (v) {
                      final granted = NotificationService.instance.permissionGranted ||
                          await NotificationService.instance.requestPermission();
                      if (!granted) {
                        app.setForegroundService(false);
                        return;
                      }
                      // The service owns the entry from now on, so drop the
                      // plain one instead of showing two.
                      await NotificationService.instance.hidePersistent();
                      await ForegroundService.start(
                        title: l.persistentTitle,
                        body: l.persistentBody,
                      );
                    } else {
                      await ForegroundService.stop();
                      if (app.persistentNotification) {
                        await NotificationService.instance.showPersistent(l10n: l);
                      }
                    }
                  },
                ),
                if (app.backgroundChecks && Platform.isAndroid) ...[
                  Divider(height: 18, color: tk.hairline),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l.bgIntervalTitle,
                      style: context.txt.bodySmall?.copyWith(color: tk.textStrong),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final minutes in const [5, 10, 15])
                        ChoiceChip(
                          label: Text(l.bgMinutes(minutes)),
                          selected: app.backgroundInterval == minutes,
                          onSelected: (_) {
                            app.setBackgroundInterval(minutes);
                            BackgroundChecks.syncSchedule(app);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l.bgIntervalBody,
                      style: context.txt.labelSmall?.copyWith(
                        color: tk.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.txt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled ? tk.textStrong : tk.muted,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: context.txt.labelSmall?.copyWith(
                      color: tk.muted,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.sound,
    required this.selected,
    required this.playing,
    required this.onSelect,
    required this.onPreview,
  });

  final SoundOption sound;
  final bool selected;
  final bool playing;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(tk.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 17,
              color: selected ? tk.accent : tk.muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                sound.label(l.zh),
                style: context.txt.bodySmall?.copyWith(
                  color: selected ? tk.accentInk : tk.textStrong,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onPreview,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
              icon: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 15,
              ),
              label: Text(
                playing ? '—' : l.preview,
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tk.accent : tk.surfaceSunken,
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 10),
          border: Border.all(color: selected ? tk.accent : tk.hairline),
        ),
        child: Text(
          label,
          style: context.txt.labelSmall?.copyWith(
            color: selected ? Colors.white : tk.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 10.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
