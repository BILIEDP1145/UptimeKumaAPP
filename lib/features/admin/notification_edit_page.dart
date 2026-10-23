import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/admin_models.dart';
import '../../state/admin_controller.dart';

/// Creates or edits one Uptime Kuma notification channel. The form is driven
/// by [NotificationProviderSpec], so new providers only need a spec entry.
class NotificationEditPage extends StatefulWidget {
  const NotificationEditPage({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<NotificationEditPage> createState() => _NotificationEditPageState();
}

class _NotificationEditPageState extends State<NotificationEditPage> {
  late NotificationProviderSpec _spec;
  late final TextEditingController _name;
  final Map<String, TextEditingController> _fields = {};
  bool _active = true;
  bool _isDefault = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _spec = NotificationProviderSpec.byType(existing?['type'] as String?) ??
        NotificationProviderSpec.all.first;
    _name = TextEditingController(text: (existing?['name'] as String?) ?? '');
    _active = existing?['active'] != false;
    _isDefault = (existing?['isDefault'] as bool?) ?? false;
    _rebuildFieldControllers();
  }

  void _rebuildFieldControllers() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _fields.clear();
    final existing = widget.existing;
    for (final field in _spec.fields) {
      final value = existing != null && existing['type'] == _spec.type
          ? existing[field.key]
          : null;
      _fields[field.key] =
          TextEditingController(text: value == null ? '' : value.toString());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    for (final field in _spec.fields) {
      if (field.required && (_fields[field.key]?.text.trim().isEmpty ?? true)) {
        setState(() => _error = '${field.label(l.zh)} · ${l.requiredField}');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'name': _name.text.trim().isEmpty ? _spec.label(l.zh) : _name.text.trim(),
      'type': _spec.type,
      'active': _active,
      'isDefault': _isDefault,
      'applyExisting': false,
      ..._spec.defaults,
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
    };

    try {
      await context.read<AdminController>().saveNotification(
            payload,
            id: (widget.existing?['id'] as num?)?.toInt(),
          );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.notificationSaved)));
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEdit ? l.edit : l.addNotification),
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
                _Label(text: l.notificationType),
                DropdownButtonFormField<String>(
                  initialValue: _spec.type,
                  decoration: const InputDecoration(),
                  items: [
                    for (final spec in NotificationProviderSpec.all)
                      DropdownMenuItem(value: spec.type, child: Text(spec.label(l.zh))),
                  ],
                  onChanged: _isEdit
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _spec = NotificationProviderSpec.byType(value)!;
                            _rebuildFieldControllers();
                          });
                        },
                ),
                const SizedBox(height: 14),
                _Label(text: l.notificationName),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(hintText: _spec.label(l.zh)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in _spec.fields) ...[
                  _Label(text: field.label(l.zh)),
                  TextField(
                    controller: _fields[field.key],
                    obscureText: field.secret,
                    autocorrect: false,
                    keyboardType: field.secret ? TextInputType.text : null,
                    decoration: InputDecoration(hintText: field.hint),
                  ),
                  const SizedBox(height: 14),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text(l.notificationEnabled, style: context.txt.bodySmall),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: Text(l.notificationDefault, style: context.txt.bodySmall),
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
