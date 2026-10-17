import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../data/net/uk_http.dart';
import '../../services/icon_changer.dart';
import '../../state/app_state.dart';

/// Launcher icon picker: bundled variants plus a user-supplied image.
class IconPage extends StatefulWidget {
  const IconPage({super.key});

  @override
  State<IconPage> createState() => _IconPageState();
}

class _IconPageState extends State<IconPage> {
  final _url = TextEditingController();
  String _active = 'default';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _active = context.read<AppState>().iconVariant;
    IconChanger.current().then((id) {
      if (mounted) setState(() => _active = id);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _applyVariant(IconVariant variant) async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    final ok = await IconChanger.apply(variant.id);
    if (!mounted) return;
    if (ok) {
      app.setIconVariant(variant.id);
      // A built-in variant means the uploaded bitmap no longer applies.
      if (app.customIconPath != null) {
        app.setCustomIconPath(null);
        await IconChanger.clearTaskIcon();
      }
    }
    setState(() {
      _busy = false;
      if (ok) _active = variant.id;
    });
  }

  Future<String?> _persist(File source) async {
    final dir = await getApplicationSupportDirectory();
    final target = Directory('${dir.path}/icons');
    if (!await target.exists()) await target.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ext = source.path.split('.').last.toLowerCase();
    final file = File('${target.path}/icon_$stamp.$ext');
    await source.copy(file.path);
    return file.path;
  }

  Future<void> _pickFile() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;
    final path = await _persist(File(picked.path));
    if (path == null || !mounted) return;
    await _applyCustom(path, messenger: messenger, l: l);
  }

  Future<void> _fromUrl() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppState>();
    final raw = _url.text.trim();
    if (raw.isEmpty) return;
    setState(() => _busy = true);
    // Honour the privacy switches: the same DoH resolver and User-Agent the
    // status-page requests use.
    final client = UkHttp.build(
      doh: app.dohEnabled,
      dohEndpoint: app.dohUrl,
      userAgent: app.userAgent,
    );
    try {
      final uri = Uri.parse(raw.contains('://') ? raw : 'https://$raw');
      final res = await client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final dir = await getTemporaryDirectory();
      final tmp = File('${dir.path}/icon_dl_${DateTime.now().millisecondsSinceEpoch}.img');
      await tmp.writeAsBytes(res.bodyBytes);
      final path = await _persist(tmp);
      await tmp.delete();
      if (path == null || !mounted) return;
      await _applyCustom(path, messenger: messenger, l: l);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final reason = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(
        SnackBar(content: Text('${l.iconDownloadFailed} · $reason')),
      );
    } finally {
      client.close();
    }
  }

  Future<void> _applyCustom(
    String path, {
    required ScaffoldMessengerState messenger,
    required L10n l,
  }) async {
    final app = context.read<AppState>();
    app.setCustomIconPath(path);
    final pinned = await IconChanger.pinCustom(path);
    // The recents card is the only system-drawn surface that takes a runtime
    // bitmap, so always apply it as a visible fallback.
    final taskIcon = await IconChanger.applyTaskIcon(path);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          pinned
              ? l.iconPinStarted
              : (taskIcon ? l.iconTaskApplied : l.iconPinHint),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);
    final customPath = app.customIconPath;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.appIcon)),
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
                Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 15, color: tk.accentInk),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.iconOfficialNote,
                        style: context.txt.labelSmall?.copyWith(
                          color: tk.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                  children: [
                    for (final variant in IconChanger.variants)
                      _VariantTile(
                        variant: variant,
                        selected: _active == variant.id,
                        onTap: _busy ? null : () => _applyVariant(variant),
                      ),
                  ],
                ),
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
                    Text(l.iconCustomTitle, style: context.txt.titleSmall),
                    const Spacer(),
                    if (customPath != null)
                      AppChip(label: l.iconCustomActive, color: tk.accent, dense: true),
                  ],
                ),
                const SizedBox(height: 8),
                if (customPath != null && File(customPath).existsSync())
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tk.style.isSharp ? 3 : 20),
                        boxShadow: tk.cardShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(File(customPath), fit: BoxFit.cover),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFile,
                    icon: const Icon(Icons.image_outlined, size: 17),
                    label: Text(l.iconPickFile),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _url,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(hintText: l.iconUrlHint),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _fromUrl,
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 17),
                    label: Text(_busy ? l.iconApplying : l.iconFromUrl),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.iconPinHint,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
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

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final IconVariant variant;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tk.style.isSharp ? 3 : 18),
                border: Border.all(
                  color: selected ? tk.accent : Colors.transparent,
                  width: 2,
                ),
                boxShadow: tk.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                variant.assetPreview,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: tk.accentSoft,
                  child: Icon(Icons.apps_rounded, size: 20, color: tk.accentInk),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            variant.label(L10n.of(context).zh),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.txt.labelSmall?.copyWith(
              color: selected ? tk.accentInk : tk.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
