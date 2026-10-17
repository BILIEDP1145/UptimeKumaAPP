import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../data/net/uk_http.dart';
import '../../state/app_state.dart';

/// Privacy switches: the opt-in usage ping, DoH resolution and a custom UA.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  late final TextEditingController _ua;
  late final TextEditingController _doh;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _ua = TextEditingController(text: app.userAgent);
    _doh = TextEditingController(text: app.dohUrl);
  }

  @override
  void dispose() {
    _ua.dispose();
    _doh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l.settingsPrivacy)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          tk.pagePadding.left,
          8,
          tk.pagePadding.right,
          MediaQuery.viewPaddingOf(context).bottom + 28,
        ),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: app.uxReport,
                  onChanged: app.setUxReport,
                  title: Text(
                    l.privacyUxTitle,
                    style: context.txt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tk.textStrong,
                    ),
                  ),
                  subtitle: Text(
                    l.privacyUxBody,
                    style: context.txt.labelSmall?.copyWith(
                      color: tk.muted,
                      height: 1.4,
                    ),
                  ),
                  isThreeLine: true,
                ),
                Divider(height: 1, color: tk.hairline, indent: 16, endIndent: 16),
                SwitchListTile(
                  value: app.dohEnabled,
                  onChanged: app.setDohEnabled,
                  title: Text(
                    l.privacyDohTitle,
                    style: context.txt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tk.textStrong,
                    ),
                  ),
                  subtitle: Text(
                    l.privacyDohBody,
                    style: context.txt.labelSmall?.copyWith(
                      color: tk.muted,
                      height: 1.4,
                    ),
                  ),
                  isThreeLine: true,
                ),
              ],
            ),
          ),
          if (app.dohEnabled) ...[
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.dohEndpointTitle,
                    style: context.txt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tk.textStrong,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l.dohEndpointBody,
                    style: context.txt.labelSmall?.copyWith(
                      color: tk.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _doh,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    onChanged: app.setDohUrl,
                    decoration: InputDecoration(
                      hintText: l.dohEndpointHint,
                      helperText: l.dohEndpointHint,
                      helperMaxLines: 2,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _doh.clear();
                        app.setDohUrl('');
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 15),
                      label: Text(l.resetDefault),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.privacyUaTitle,
                  style: context.txt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tk.textStrong,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l.privacyUaBody,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ua,
                  autocorrect: false,
                  onChanged: app.setUserAgent,
                  decoration: InputDecoration(
                    hintText: UkHttp.defaultUserAgent,
                    helperText: l.privacyUaHint,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      _ua.clear();
                      app.setUserAgent('');
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 15),
                    label: Text(l.resetDefault),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: tk.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.privacyDataNote,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
