import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../data/cache/cache_store.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../state/status_controller.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  int _bytes = 0;
  int _pending = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final size = await CacheStore.instance.sizeBytes();
    final pending = await NotificationService.instance.pending();
    if (!mounted) return;
    setState(() {
      _bytes = size;
      _pending = pending.length;
    });
  }

  Future<void> _clear() async {
    final l = L10n.of(context);
    final ctl = context.read<StatusController>();
    final app = context.read<AppState>();
    setState(() => _busy = true);
    await CacheStore.instance.clearAll();
    await NotificationService.instance.cancelAll();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.cacheCleared)),
    );
    // Reload from the network so the UI is not left blank.
    await ctl.attach(app.activeServer);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                          CacheStore.humanSize(_bytes),
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
                _InfoRow(
                  label: l.monitorsCount(app.servers.length),
                  value: l.navServers,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: l.notifications,
                  value: '$_pending',
                ),
                const SizedBox(height: 12),
                Text(
                  l.clearCacheConfirm,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _clear,
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
