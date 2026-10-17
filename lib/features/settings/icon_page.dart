import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../services/icon_changer.dart';
import '../../state/app_state.dart';

/// Launcher icon picker. Only the icons baked into the APK are offered:
/// Android cannot replace the launcher icon of an installed package with a
/// runtime bitmap, and the pinned-shortcut workaround confused more people
/// than it helped, so user uploads were dropped.
class IconPage extends StatefulWidget {
  const IconPage({super.key});

  @override
  State<IconPage> createState() => _IconPageState();
}

class _IconPageState extends State<IconPage> {
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

  Future<void> _applyVariant(IconVariant variant) async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    final ok = await IconChanger.apply(variant.id);
    if (!mounted) return;
    if (ok) app.setIconVariant(variant.id);
    setState(() {
      _busy = false;
      if (ok) _active = variant.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                const SizedBox(height: 14),
                Text(
                  l.iconPresetOnly,
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
