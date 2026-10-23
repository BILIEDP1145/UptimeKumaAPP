import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/net_image.dart';
import '../../data/cache/cache_store.dart';
import '../../data/cache/image_cache.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../state/status_controller.dart';

/// Storage breakdown. Each cache is listed with its own size and its own
/// "clear" action — wiping snapshots should not cost you the downloaded logos,
/// and vice versa.
class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  int _snapshotBytes = 0;
  int _imageBytes = 0;
  int _imageFiles = 0;
  int _pending = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final snapshot = await CacheStore.instance.sizeBytes();
    final images = await ImageDiskCache.instance.stats();
    final pending = await NotificationService.instance.pending();
    if (!mounted) return;
    setState(() {
      _snapshotBytes = snapshot;
      _imageBytes = images.bytes;
      _imageFiles = images.files;
      _pending = pending.length;
    });
  }

  int get _total => _snapshotBytes + _imageBytes;

  Future<void> _run(Future<void> Function() action) async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    await action();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.cacheCleared)),
    );
  }

  Future<void> _clearSnapshots() async {
    final ctl = context.read<StatusController>();
    final app = context.read<AppState>();
    await _run(CacheStore.instance.clearAll);
    if (!mounted) return;
    // Reload from the network so the dashboard is not left blank.
    await ctl.attach(app.activeServer);
  }

  Future<void> _clearImages() => _run(() async {
        NetImage.clearMemoryCache();
        await ImageDiskCache.instance.clear();
      });

  Future<void> _clearEverything() async {
    final ctl = context.read<StatusController>();
    final app = context.read<AppState>();
    await _run(() async {
      await CacheStore.instance.clearAll();
      NetImage.clearMemoryCache();
      await ImageDiskCache.instance.clear();
      await NotificationService.instance.cancelAll();
    });
    if (!mounted) return;
    await ctl.attach(app.activeServer);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l.settingsData)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(tk.pagePadding.left, 4, tk.pagePadding.right, 28),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tk.accentSoft,
                        borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 13),
                      ),
                      child: Icon(Icons.sd_storage_outlined, color: tk.accentInk, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.cacheSize, style: context.txt.labelSmall?.copyWith(color: tk.muted)),
                        Text(
                          CacheStore.humanSize(_total),
                          style: context.txt.headlineSmall?.copyWith(
                            fontFeatures: tk.tabular,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: tk.hairline),
                const SizedBox(height: 12),
                _InfoRow(label: l.navServers, value: '${app.servers.length}'),
                const SizedBox(height: 6),
                _InfoRow(label: l.notifications, value: '$_pending'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Snapshots
          _CacheTile(
            icon: Icons.dashboard_customize_outlined,
            title: l.cacheSnapshots,
            body: l.cacheSnapshotsBody,
            detail: CacheStore.humanSize(_snapshotBytes),
            action: l.clear,
            enabled: !_busy && _snapshotBytes > 0,
            onClear: _clearSnapshots,
          ),
          const SizedBox(height: 10),

          // Downloaded logos / icons
          _CacheTile(
            icon: Icons.image_outlined,
            title: l.cacheImages,
            body: l.cacheImagesBody,
            detail: '${l.filesCount(_imageFiles)} · ${CacheStore.humanSize(_imageBytes)}',
            action: l.clear,
            enabled: !_busy && _imageBytes > 0,
            onClear: _clearImages,
          ),
          const SizedBox(height: 14),

          Text(
            l.clearCacheConfirm,
            style: context.txt.labelSmall?.copyWith(
              color: tk.muted,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _clearEverything,
            style: FilledButton.styleFrom(backgroundColor: tk.statusDown),
            icon: _busy
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cleaning_services_rounded, size: 17),
            label: Text(l.clearCache),
          ),
        ],
      ),
    );
  }
}

class _CacheTile extends StatelessWidget {
  const _CacheTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.detail,
    required this.action,
    required this.enabled,
    required this.onClear,
  });

  final IconData icon;
  final String title;
  final String body;
  final String detail;
  final String action;
  final bool enabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tk.accentInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: context.txt.titleSmall),
              ),
              Text(
                detail,
                style: context.txt.labelSmall?.copyWith(
                  color: tk.muted,
                  fontFeatures: tk.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: context.txt.labelSmall?.copyWith(
              color: tk.muted,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: Text(action),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: enabled ? tk.statusDown : tk.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.txt.bodySmall?.copyWith(color: tk.muted),
          ),
        ),
        Text(
          value,
          style: context.txt.bodySmall?.copyWith(
            color: tk.textStrong,
            fontWeight: FontWeight.w600,
            fontFeatures: tk.tabular,
          ),
        ),
      ],
    );
  }
}
