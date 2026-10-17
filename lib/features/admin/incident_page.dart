import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../state/admin_controller.dart';

/// Posts a status-page incident ("事件") from the phone.
class IncidentPage extends StatefulWidget {
  const IncidentPage({super.key, required this.admin});

  final AdminController admin;

  @override
  State<IncidentPage> createState() => _IncidentPageState();
}

class _IncidentPageState extends State<IncidentPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _pageTitle = TextEditingController();
  final _pageSlug = TextEditingController();
  String _style = 'info';
  bool _posting = false;
  bool _creatingPage = false;
  String? _error;
  String? _slug;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _pageTitle.dispose();
    _pageSlug.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Kuma addresses incidents by status-page slug, not by numeric id.
    final pages = widget.admin.statusPages;
    _slug = pages.isEmpty ? null : (pages.first['slug'] as String?);
  }

  Future<void> _createPage() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = _pageTitle.text.trim();
    final slug = _pageSlug.text.trim().toLowerCase();
    if (title.isEmpty || slug.isEmpty) {
      setState(() => _error = l.requiredField);
      return;
    }
    setState(() {
      _creatingPage = true;
      _error = null;
    });
    try {
      await widget.admin.addStatusPage(title: title, slug: slug);
      if (!mounted) return;
      setState(() {
        _creatingPage = false;
        _pageTitle.clear();
        _pageSlug.clear();
        _slug = slug;
      });
      messenger.showSnackBar(SnackBar(content: Text(l.statusPageCreated)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingPage = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _post() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final slug = _slug;
    if (slug == null || slug.isEmpty) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = l.requiredField);
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await widget.admin.postIncident(
        slug: slug,
        title: _title.text.trim(),
        content: _content.text.trim(),
        style: _style,
      );
      if (!mounted) return;
      setState(() {
        _posting = false;
        _title.clear();
        _content.clear();
      });
      messenger.showSnackBar(SnackBar(content: Text(l.eventPosted)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final pages = widget.admin.statusPages;

    if (pages.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          tk.pagePadding.left,
          24,
          tk.pagePadding.right,
          MediaQuery.of(context).padding.bottom + 28,
        ),
        children: [
          AppCard(
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 17, color: tk.muted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    l.noStatusPageHint,
                    style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.createStatusPage, style: context.txt.titleSmall),
                const SizedBox(height: 12),
                _Label(text: l.statusPageTitleField),
                TextField(
                  controller: _pageTitle,
                  decoration: InputDecoration(hintText: l.statusPageTitleField),
                ),
                const SizedBox(height: 14),
                _Label(text: l.statusPageSlugField),
                TextField(
                  controller: _pageSlug,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: l.statusPageSlugHint,
                    helperText: l.statusPageSlugHint,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _creatingPage ? null : _createPage,
                    icon: _creatingPage
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded, size: 17),
                    label: Text(l.create),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: context.txt.labelSmall?.copyWith(color: tk.statusDown),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        tk.pagePadding.left,
        2,
        tk.pagePadding.right,
        MediaQuery.of(context).padding.bottom + 28,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(text: l.statusPageLabel),
              DropdownButtonFormField<String>(
                initialValue: _slug ?? pages.first['slug'] as String?,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: [
                  for (final page in pages)
                    DropdownMenuItem<String>(
                      value: page['slug'] as String?,
                      child: Text(
                        (page['title'] as String?) ?? (page['slug'] as String? ?? '—'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _slug = v),
              ),
              const SizedBox(height: 14),
              _Label(text: l.eventTitle),
              TextField(
                controller: _title,
                decoration: InputDecoration(hintText: l.eventTitle),
              ),
              const SizedBox(height: 14),
              _Label(text: l.eventContent),
              TextField(
                controller: _content,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(hintText: l.eventContent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(text: l.eventStyle),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _styleChip('info', l.styleInfo, tk.statusMaintenance),
                  _styleChip('warning', l.styleWarning, tk.statusPending),
                  _styleChip('danger', l.styleDanger, tk.statusDown),
                  _styleChip('primary', l.stylePrimary, tk.accent),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: true,
                onChanged: null,
                title: Text(l.eventPinned, style: context.txt.bodySmall),
                subtitle: Text(
                  l.eventAutoPinned,
                  style: context.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.4,
                  ),
                ),
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
          child: FilledButton.icon(
            onPressed: _posting ? null : _post,
            icon: _posting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.campaign_outlined, size: 17),
            label: Text(l.postEvent),
          ),
        ),
      ],
    );
  }

  Widget _styleChip(String value, String label, Color color) {
    final selected = _style == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? color : null,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _style = value),
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
