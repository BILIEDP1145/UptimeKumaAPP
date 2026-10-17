import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../state/app_state.dart';

/// Version, contact, project link and the signing hash of the installed APK.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const MethodChannel _channel =
      MethodChannel('com.zakoflare.uptimekuma/app');

  static const String projectUrl = 'https://www.zakoflare.com/app/UptimeKumaAPP';
  static const String contactMail = 'app@zakoflare.com';
  static const String businessMail = 'business@zakoflare.com';

  String _version = '—';
  String _hash = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String version = '—';
    String hash = '—';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    try {
      final result = await _channel.invokeMethod<String>('apkSigningHash');
      if (result != null && result.isNotEmpty) hash = result;
    } on PlatformException {
      hash = 'unavailable';
    } on MissingPluginException {
      hash = 'unavailable';
    }
    if (!mounted) return;
    setState(() {
      _version = version;
      _hash = hash;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    // A user-supplied icon replaces the bundled artwork here too, so the choice
    // is visibly in effect inside the app.
    final customIcon = context.watch<AppState>().customIconPath;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.settingsAbout)),
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
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tk.style.isSharp ? 4 : 18),
                    boxShadow: tk.cardShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (customIcon != null && File(customIcon).existsSync())
                      ? Image.file(
                          File(customIcon),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/images/icon_official.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/icon_official.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: tk.accent,
                            child: const Icon(Icons.monitor_heart, color: Colors.white),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text('Uptime Kuma Mobile', style: context.txt.titleMedium),
                const SizedBox(height: 3),
                Text(
                  'ZAKOFLARE & MILLENNIUMIC',
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.tag_rounded,
                  label: l.aboutVersion,
                  value: _version,
                ),
                _Divider(),
                _InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: l.aboutContact,
                  value: contactMail,
                  copyable: true,
                ),
                _Divider(),
                _InfoRow(
                  icon: Icons.business_center_outlined,
                  label: l.aboutBusiness,
                  value: businessMail,
                  copyable: true,
                ),
                _Divider(),
                _InfoRow(
                  icon: Icons.link_rounded,
                  label: l.aboutProject,
                  value: projectUrl,
                  copyable: true,
                  multiline: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fingerprint, size: 15, color: tk.accentInk),
                    const SizedBox(width: 6),
                    Text(
                      l.aboutHash,
                      style: context.txt.labelMedium?.copyWith(
                        color: tk.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.copy_rounded, size: 15, color: tk.muted),
                      onPressed: () => _copy(context, _hash),
                    ),
                  ],
                ),
                Text(
                  _hash,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.textStrong,
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.aboutHashHint,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.4,
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

  Future<void> _copy(BuildContext context, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = L10n.of(context).copyDone;
    await Clipboard.setData(ClipboardData(text: value));
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  /// Lets long values (URLs) wrap instead of being cut with an ellipsis.
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tk.accentInk),
          const SizedBox(width: 10),
          Text(
            label,
            style: context.txt.bodySmall?.copyWith(color: tk.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: multiline ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: context.txt.labelMedium?.copyWith(
                color: tk.textStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final done = L10n.of(context).copyDone;
                await Clipboard.setData(ClipboardData(text: value));
                messenger.showSnackBar(SnackBar(content: Text(done)));
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.copy_rounded, size: 14, color: tk.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Divider(height: 1, color: tk.hairline, indent: 39, endIndent: 14);
  }
}
