import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../data/api/uk_api.dart';
import '../../data/cache/cache_store.dart';
import '../../data/cache/image_cache.dart';
import '../../data/net/uk_http.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';

/// One line of the report: a label, a value and whether it looks healthy.
class _Check {
  _Check(this.label, this.value, {this.ok = true});

  final String label;
  final String value;
  final bool ok;

  String get line => '$label: $value';
}

/// "Help with debugging": runs every subsystem once and produces a pasteable
/// report. Built for remote support — no logs, just state.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const DiagnosticsPage(),
      );

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  final List<_Check> _rows = [];
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _rows.clear();
    });
    final app = context.read<AppState>();

    void add(_Check check) {
      if (!mounted) return;
      setState(() => _rows.add(check));
    }

    // --- app & system ---
    try {
      final info = await PackageInfo.fromPlatform();
      add(_Check('App', '${info.version} (${info.buildNumber})'));
      add(_Check('Package', info.packageName));
    } catch (e) {
      add(_Check('App', 'unavailable: $e', ok: false));
    }
    add(_Check('System', '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'));

    // --- notifications ---
    await NotificationService.instance.refreshPermission();
    final granted = NotificationService.instance.permissionGranted;
    add(_Check('Notifications', granted ? 'granted' : 'denied', ok: granted));
    for (final line in await NotificationService.instance.diagnose(app.sound)) {
      add(_Check('Notify', line));
    }

    // --- network ---
    if (app.dohEnabled) {
      final endpoint = app.dohUrl.trim().isEmpty ? DohResolver.defaults.first : app.dohUrl.trim();
      final result = await DohResolver.probe(endpoint);
      add(_Check(
        'DoH',
        result.ok
            ? 'OK · ${result.address}'
            : (result.status != null ? 'HTTP ${result.status}' : (result.error ?? 'failed')),
        ok: result.ok,
      ));
    } else {
      add(_Check('DoH', 'disabled'));
    }

    // --- instances ---
    for (final server in app.servers) {
      final api = UkApi(
        doh: app.dohEnabled,
        dohEndpoint: app.dohUrl,
        userAgent: app.userAgent,
      );
      final watch = Stopwatch()..start();
      try {
        final probe = await api.probe(server);
        add(_Check(
          server.name,
          probe.ok
              ? 'OK · ${probe.monitorCount} monitors · ${watch.elapsedMilliseconds} ms'
              : (probe.message ?? 'failed'),
          ok: probe.ok,
        ));
      } catch (e) {
        add(_Check(server.name, 'error: $e', ok: false));
      } finally {
        api.dispose();
      }
    }

    // --- storage ---
    try {
      final snapshotBytes = await CacheStore.instance.sizeBytes();
      final images = await ImageDiskCache.instance.stats();
      add(_Check('Snapshot cache', CacheStore.humanSize(snapshotBytes)));
      add(_Check(
        'Image cache',
        '${images.files} files · ${CacheStore.humanSize(images.bytes)}',
      ));
    } catch (e) {
      add(_Check('Cache', 'unavailable: $e', ok: false));
    }

    // --- settings ---
    add(_Check('Poll interval', '${app.pollSeconds}s'));
    add(_Check('Background', app.backgroundChecks ? '${app.backgroundInterval} min' : 'off'));
    add(_Check('Persistent notification', app.persistentNotification ? 'on' : 'off'));
    add(_Check('Silent sign-in', app.silentLogin ? 'on' : 'off'));
    add(_Check('SLA column', app.showSla ? 'on' : 'off'));
    add(_Check('Theme', '${app.uiStyle.name} · opacity ${(app.uiOpacity * 100).round()}%'));

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l.assistTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          tk.pagePadding.left,
          8,
          tk.pagePadding.right,
          MediaQuery.viewPaddingOf(context).bottom + 28,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.assistBody, style: context.txt.bodySmall?.copyWith(
                  color: tk.muted,
                  height: 1.5,
                )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _running ? null : _run,
                      icon: _running
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(l.runAllChecks),
                    ),
                    const Spacer(),
                    if (_rows.isNotEmpty)
                      TextButton.icon(
                        onPressed: () async {
                          final text = _rows.map((r) => r.line).join('\n');
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.exportedToClipboard)),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: Text(l.copyReport),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final row in _rows) ...[
            _CheckRow(check: row),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final _Check check;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            check.ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 15,
            color: check.ok ? tk.statusUp : tk.statusDown,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: context.txt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tk.textStrong,
                  ),
                ),
                Text(
                  check.value,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
