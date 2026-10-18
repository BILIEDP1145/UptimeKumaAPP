import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../data/api/uk_api.dart';
import '../../data/api/uk_socket.dart';
import '../../data/models/server_config.dart';
import '../../services/credential_store.dart';
import '../../state/app_state.dart';

class ServerEditPage extends StatefulWidget {
  const ServerEditPage({super.key, this.server});

  final ServerConfig? server;

  @override
  State<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _slug;
  late final TextEditingController _apiKey;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _otp;

  late ServerMode _mode;

  bool _busy = false;
  String? _feedback;
  bool _feedbackOk = false;
  bool _otpRequired = false;
  bool _slugTouched = false;

  bool get _isEdit => widget.server != null;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _name = TextEditingController(text: server?.name ?? '');
    _url = TextEditingController(text: server?.baseUrl ?? '');
    _slug = TextEditingController(text: server?.slug ?? '');
    _apiKey = TextEditingController(text: server?.apiKey ?? '');
    _username = TextEditingController(text: server?.username ?? '');
    _password = TextEditingController();
    unawaited(_restorePassword());
    _otp = TextEditingController();
    _mode = server?.mode ?? ServerMode.monitor;
    _slugTouched = (server?.slug ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _slug.dispose();
    _apiKey.dispose();
    _username.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _onUrlChanged(String raw) {
    // Pasting a full status page link fills the slug for the user.
    if (raw.contains('/status/')) {
      final parsed = ServerConfig.parseInput(raw);
      if (parsed.slug.isNotEmpty) {
        _slug.text = parsed.slug;
        _slugTouched = true;
      }
    }
    setState(() {
      _feedback = null;
      _feedbackOk = false;
    });
  }

  /// The URL the user typed may carry a `/status/<slug>` tail; strip it for
  /// the API base and keep the slug separate.
  ({String baseUrl, String slug}) get _parsed {
    final parsed = ServerConfig.parseInput(_url.text, slugOverride: _slug.text.trim());
    if (parsed.baseUrl.isNotEmpty) return parsed;
    final raw = _url.text.trim();
    return (baseUrl: raw, slug: _slug.text.trim());
  }

  ServerConfig _buildDraft({String token = ''}) {
    final parsed = _parsed;
    final host = Uri.tryParse(parsed.baseUrl)?.host ?? '';
    return ServerConfig(
      id: widget.server?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty
          ? (host.isEmpty ? 'Uptime Kuma' : host)
          : _name.text.trim(),
      baseUrl: parsed.baseUrl,
      slug: parsed.slug,
      mode: _mode,
      apiKey: _apiKey.text.trim(),
      username: _username.text.trim(),
      token: token.isNotEmpty ? token : (widget.server?.token ?? ''),
      colorTag: widget.server?.colorTag ?? 'terminal',
    );
  }

  /// Management mode must prove the credentials work before we save anything,
  /// so a typo does not leave a broken instance in the list.
  Future<void> _verifyAndMaybeSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = L10n.of(context);
    setState(() {
      _busy = true;
      _feedback = null;
    });

    final draft = _buildDraft();

    if (_mode == ServerMode.manage) {
      final admin = UkAdmin(draft, userAgent: context.read<AppState>().userAgent);
      final result = await admin.signIn(
        username: _username.text.trim(),
        password: _password.text,
        otp: _otp.text.trim(),
      );
      await admin.dispose();
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _busy = false;
          _otpRequired = result.requires2fa;
          _feedbackOk = false;
          _feedback = result.requires2fa
              ? l.fieldOtp
              : (result.message ?? l.connectionFailed);
        });
        return;
      }
      await _persist(draft.copyWith(token: result.token ?? ''));
      return;
    }

    final app = context.read<AppState>();
    final api = UkApi(
      doh: app.dohEnabled,
      dohEndpoint: app.dohUrl,
      userAgent: app.userAgent,
    );
    final probe = await api.probe(draft);
    api.dispose();
    if (!mounted) return;
    if (!probe.ok) {
      setState(() {
        _busy = false;
        _feedbackOk = false;
        _feedback = probe.message ?? l.connectionFailed;
      });
      return;
    }
    await _persist(draft);
  }

  Future<void> _test() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = L10n.of(context);
    setState(() {
      _busy = true;
      _feedback = null;
    });

    if (_mode == ServerMode.manage) {
      final admin = UkAdmin(_buildDraft(), userAgent: context.read<AppState>().userAgent);
      final result = await admin.signIn(
        username: _username.text.trim(),
        password: _password.text,
        otp: _otp.text.trim(),
      );
      await admin.dispose();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedbackOk = result.ok;
        _otpRequired = result.requires2fa;
        _feedback = result.ok
            ? l.connectionOk
            : (result.requires2fa ? l.fieldOtp : (result.message ?? l.connectionFailed));
      });
      return;
    }

    final app = context.read<AppState>();
    final api = UkApi(
      doh: app.dohEnabled,
      dohEndpoint: app.dohUrl,
      userAgent: app.userAgent,
    );
    final probe = await api.probe(_buildDraft());
    api.dispose();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedbackOk = probe.ok;
      _feedback = probe.ok
          ? '${l.connectionOk} · ${probe.title ?? ''} · ${l.monitorsCount(probe.monitorCount)}'
          : (probe.message ?? l.connectionFailed);
    });
  }

  /// Shows the saved password instead of an empty box.
  Future<void> _restorePassword() async {
    final server = widget.server;
    if (server == null || !server.isManage) return;
    final stored = await CredentialStore.read(server.id);
    if (stored == null || stored.isEmpty || !mounted) return;
    setState(() => _password.text = stored);
  }

  Future<void> _persist(ServerConfig draft) async {
    final app = context.read<AppState>();
    if (_isEdit) {
      await app.updateServer(draft);
    } else {
      await app.addServer(draft);
      await app.setActiveServer(draft.id);
    }
    // Keep the password for silent re-authentication — or drop it when the
    // feature is off, so disabling the switch really forgets it.
    if (draft.isManage) {
      if (app.silentLogin && _password.text.isNotEmpty) {
        await CredentialStore.save(draft.id, _password.text);
      } else if (!app.silentLogin) {
        await CredentialStore.delete(draft.id);
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final isManage = _mode == ServerMode.manage;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEdit ? l.editInstance : l.addInstance),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            tk.pagePadding.left,
            6,
            tk.pagePadding.right,
            MediaQuery.of(context).padding.bottom + 28,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    icon: Icons.visibility_outlined,
                    title: l.modeMonitorTitle,
                    body: l.modeMonitorBody,
                    selected: !isManage,
                    onTap: () => setState(() => _mode = ServerMode.monitor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: l.modeManageTitle,
                    body: l.modeManageBody,
                    selected: isManage,
                    onTap: () => setState(() => _mode = ServerMode.manage),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(text: l.instanceName),
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(hintText: l.instanceNameHint),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(text: isManage ? l.fieldServerUrl : l.fieldStatusUrl),
                  TextFormField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: _onUrlChanged,
                    decoration: InputDecoration(hintText: l.baseUrlHint),
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      if (raw.isEmpty) return l.requiredField;
                      final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
                      if (uri == null || uri.host.isEmpty) return l.invalidUrl;
                      if (uri.scheme != 'http' && uri.scheme != 'https') return l.invalidUrl;
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel(text: l.fieldSlug),
                  TextFormField(
                    controller: _slug,
                    autocorrect: false,
                    onChanged: (_) => setState(() => _slugTouched = true),
                    decoration: InputDecoration(
                      hintText: isManage ? l.slugOptional : l.slugHint,
                    ),
                    validator: (v) {
                      if (isManage) return null;
                      return (v == null || v.trim().isEmpty) ? l.requiredField : null;
                    },
                  ),
                  if (!isManage) ...[
                    const SizedBox(height: 8),
                    Text(
                      l.slugHelp,
                      style: context.txt.labelSmall?.copyWith(
                        color: tk.muted,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  if (_slugTouched && _slug.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 13, color: tk.statusUp),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${l.detected}: /status/${_slug.text.trim()}',
                            style: context.txt.labelSmall?.copyWith(color: tk.statusUp),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isManage) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(text: l.fieldUsername),
                    TextFormField(
                      controller: _username,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'admin'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l.requiredField : null,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(text: l.fieldPassword),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: '••••••••'),
                      validator: (v) {
                        if (_isEdit && (widget.server?.hasSession ?? false)) return null;
                        return (v == null || v.isEmpty) ? l.requiredField : null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.passwordHint,
                      style: context.txt.labelSmall?.copyWith(
                        color: tk.muted,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (_otpRequired) ...[
                      const SizedBox(height: 14),
                      _FieldLabel(text: l.fieldOtp),
                      TextFormField(
                        controller: _otp,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '123456'),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _FieldLabel(text: l.fieldApiKey),
                    TextFormField(
                      controller: _apiKey,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: 'uk1_…'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.apiKeyHint,
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
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              AppCard(
                color: (_feedbackOk ? tk.statusUp : tk.statusDown).withValues(alpha: 0.09),
                borderColor:
                    (_feedbackOk ? tk.statusUp : tk.statusDown).withValues(alpha: 0.35),
                child: Row(
                  children: [
                    Icon(
                      _feedbackOk ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 17,
                      color: _feedbackOk ? tk.statusUp : tk.statusDown,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _feedback!,
                        style: context.txt.labelMedium?.copyWith(
                          color: _feedbackOk ? tk.statusUp : tk.statusDown,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _test,
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, size: 17),
                    label: Text(_busy ? l.testing : l.testConnection),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _verifyAndMaybeSave,
                    child: Text(isManage ? l.signInBtn : l.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      onTap: onTap,
      borderColor: selected ? tk.accent : null,
      color: selected ? tk.accentSoft.withValues(alpha: 0.55) : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: selected ? tk.accentInk : tk.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.txt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? tk.accentInk : tk.textStrong,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 14, color: tk.accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: context.txt.labelSmall?.copyWith(
              color: tk.muted,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: context.txt.labelMedium?.copyWith(color: context.tk.muted),
      ),
    );
  }
}
