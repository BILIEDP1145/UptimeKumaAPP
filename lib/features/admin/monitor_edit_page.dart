import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/admin_models.dart';
import '../../state/admin_controller.dart';

/// Create or edit a monitor. The whole field set the phone needs is here:
/// target, cadence, retries, accepted codes, keyword, group and notifications.
class MonitorEditPage extends StatefulWidget {
  const MonitorEditPage({super.key, this.draft});

  final MonitorDraft? draft;

  @override
  State<MonitorEditPage> createState() => _MonitorEditPageState();
}

class _MonitorEditPageState extends State<MonitorEditPage> {
  late MonitorDraft _draft;

  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _interval;
  late final TextEditingController _retries;
  late final TextEditingController _timeout;
  late final TextEditingController _codes;
  late final TextEditingController _keyword;
  late final TextEditingController _description;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? MonitorDraft();
    _name = TextEditingController(text: _draft.name);
    _url = TextEditingController(text: _draft.url);
    _host = TextEditingController(text: _draft.hostname);
    _port = TextEditingController(text: _draft.port?.toString() ?? '');
    _interval = TextEditingController(text: _draft.interval.toString());
    _retries = TextEditingController(text: _draft.maxretries.toString());
    _timeout = TextEditingController(text: _draft.timeout.toString());
    _codes = TextEditingController(text: _draft.acceptedCodes.join(', '));
    _keyword = TextEditingController(text: _draft.keyword);
    _description = TextEditingController(text: _draft.description);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _url,
      _host,
      _port,
      _interval,
      _retries,
      _timeout,
      _codes,
      _keyword,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _collect() {
    _draft
      ..name = _name.text.trim()
      ..url = _url.text.trim()
      ..hostname = _host.text.trim()
      ..port = int.tryParse(_port.text.trim())
      ..interval = int.tryParse(_interval.text.trim()) ?? 60
      ..maxretries = int.tryParse(_retries.text.trim()) ?? 0
      ..timeout = int.tryParse(_timeout.text.trim()) ?? 48
      ..keyword = _keyword.text.trim()
      ..description = _description.text.trim()
      ..acceptedCodes = _codes.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
  }

  Future<void> _save() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    _collect();
    if (_draft.name.isEmpty) {
      setState(() => _error = l.requiredField);
      return;
    }
    if (!_draft.kind.isGroup) {
      final target = _draft.kind.needsUrl ? _draft.url : _draft.hostname;
      if (target.isEmpty) {
        setState(() => _error = l.requiredField);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AdminController>().saveMonitor(_draft);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.monitorSaved)));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final admin = context.watch<AdminController>();
    final groups = admin.groups.where((g) => g.id != _draft.id).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_draft.isNew ? l.manageAddMonitor : l.manageEditMonitor),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.save),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          tk.pagePadding.left,
          6,
          tk.pagePadding.right,
          MediaQuery.of(context).padding.bottom + 28,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(text: l.monitorType),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final kind in MonitorKind.values)
                      ChoiceChip(
                        label: Text(kind.label(l.zh)),
                        selected: _draft.kind == kind,
                        onSelected: (_) => setState(() => _draft.kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _Label(text: l.monitorName),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(hintText: l.monitorName),
                ),
                const SizedBox(height: 14),
                if (_draft.kind.needsUrl) ...[
                  _Label(text: l.monitorUrl),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: 'https://example.com/health'),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_draft.kind.needsHostname) ...[
                  _Label(text: l.monitorHostname),
                  TextField(
                    controller: _host,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: 'example.com'),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_draft.kind.needsPort) ...[
                  _Label(text: l.monitorPort),
                  TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '443'),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_draft.kind == MonitorKind.keyword) ...[
                  _Label(text: l.monitorKeyword),
                  TextField(
                    controller: _keyword,
                    decoration: const InputDecoration(hintText: 'OK'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _draft.invertKeyword,
                    onChanged: (v) => setState(() => _draft.invertKeyword = v),
                    title: Text(l.monitorInvert, style: context.txt.bodySmall),
                  ),
                  const SizedBox(height: 6),
                ],
                if (_draft.kind == MonitorKind.http || _draft.kind == MonitorKind.keyword) ...[
                  _Label(text: l.monitorCodes),
                  TextField(
                    controller: _codes,
                    decoration: const InputDecoration(hintText: '200-299'),
                  ),
                  const SizedBox(height: 14),
                ],
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
                    Expanded(child: _NumberField(controller: _interval, label: l.monitorInterval)),
                    const SizedBox(width: 10),
                    Expanded(child: _NumberField(controller: _retries, label: l.monitorMaxRetries)),
                    const SizedBox(width: 10),
                    Expanded(child: _NumberField(controller: _timeout, label: l.monitorTimeout)),
                  ],
                ),
                const SizedBox(height: 12),
                _Label(text: l.monitorParent),
                DropdownButtonFormField<int?>(
                  initialValue: _draft.parent,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(l.noGroup)),
                    for (final group in groups)
                      DropdownMenuItem<int?>(
                        value: group.id,
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _draft.parent = v),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.active,
                  onChanged: (v) => setState(() => _draft.active = v),
                  title: Text(l.monitorActive, style: context.txt.bodySmall),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.upsideDown,
                  onChanged: (v) => setState(() => _draft.upsideDown = v),
                  title: Text(l.monitorUpsideDown, style: context.txt.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(text: l.monitorNotifications),
                if (admin.notifications.isEmpty)
                  Text(
                    l.noNotificationsYet,
                    style: context.txt.labelSmall?.copyWith(color: tk.muted),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in admin.notifications)
                        FilterChip(
                          label: Text((item['name'] as String?) ?? '—'),
                          selected:
                              _draft.notificationIds.contains((item['id'] as num?)?.toInt()),
                          onSelected: (on) {
                            final id = (item['id'] as num?)?.toInt();
                            if (id == null) return;
                            setState(() {
                              if (on) {
                                _draft.notificationIds = [..._draft.notificationIds, id];
                              } else {
                                _draft.notificationIds =
                                    _draft.notificationIds.where((e) => e != id).toList();
                              }
                            });
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: context.txt.labelSmall?.copyWith(color: tk.statusDown),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

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
