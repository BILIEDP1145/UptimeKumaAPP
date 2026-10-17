import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/status_ui.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/admin_models.dart';
import '../../data/models/status_page.dart';
import '../../state/admin_controller.dart';
import '../servers/server_edit_page.dart';
import 'incident_page.dart';
import 'monitor_edit_page.dart';
import 'notification_edit_page.dart';

/// Third tab: everything that requires an authenticated session.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final tk = context.tk;
    final l = L10n.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    if (admin.server == null) {
      return _EmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: l.guideHeadline,
        body: l.guideLead,
        action: l.guideAddNow,
        onAction: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ServerEditPage()),
        ),
      );
    }

    if (!admin.server!.isManage) {
      return _EmptyState(
        icon: Icons.visibility_outlined,
        title: l.needManageMode,
        body: l.modeManageBody,
        action: l.edit,
        onAction: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => ServerEditPage(server: admin.server)),
        ),
      );
    }

    if (!admin.signedIn) {
      return _SignInPanel(admin: admin);
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tk.pagePadding.left + 2,
            topPad + 18,
            tk.pagePadding.right,
            10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.navManage, style: context.txt.headlineSmall),
                    const SizedBox(height: 3),
                    Text(
                      '${admin.server!.displayHost} · ${admin.server!.username}',
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: admin.connecting ? null : () => admin.refresh(),
                icon: admin.connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tk.pagePadding.left),
          child: _TabBar(
            index: _tab,
            labels: [l.manageMonitors, l.notificationsTab, l.eventsTab],
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: switch (_tab) {
            0 => _MonitorsTab(admin: admin),
            1 => _NotificationsTab(admin: admin),
            _ => _EventsTab(admin: admin),
          },
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.labels, required this.onChanged});

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final sharp = tk.style.isSharp;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tk.surfaceSunken,
        borderRadius: BorderRadius.circular(sharp ? 2 : 10),
        border: Border.all(color: tk.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? tk.surfaceCard : Colors.transparent,
                    borderRadius: BorderRadius.circular(sharp ? 1 : 8),
                    boxShadow: i == index ? tk.cardShadow : null,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.txt.labelMedium?.copyWith(
                      color: i == index ? tk.accentInk : tk.muted,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign in
// ---------------------------------------------------------------------------

class _SignInPanel extends StatefulWidget {
  const _SignInPanel({required this.admin});

  final AdminController admin;

  @override
  State<_SignInPanel> createState() => _SignInPanelState();
}

class _SignInPanelState extends State<_SignInPanel> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _otpRequired = false;

  @override
  void initState() {
    super.initState();
    _user.text = widget.admin.server?.username ?? '';
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = L10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.admin.signIn(
      username: _user.text.trim(),
      password: _pass.text,
      otp: _otp.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _otpRequired = result.requires2fa;
      _error = result.ok ? null : (result.message ?? l.connectionFailed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        tk.pagePadding.left,
        topPad + 26,
        tk.pagePadding.right,
        28,
      ),
      children: [
        Text(l.navManage, style: context.txt.headlineSmall),
        const SizedBox(height: 5),
        Text(
          l.manageSignInLead,
          style: context.txt.bodySmall?.copyWith(color: tk.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _user,
                autocorrect: false,
                decoration: InputDecoration(labelText: l.fieldUsername),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                autocorrect: false,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l.fieldPassword),
              ),
              if (_otpRequired) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.fieldOtp),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: context.txt.labelSmall?.copyWith(color: tk.statusDown),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? l.signingIn : l.signInBtn),
                ),
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => ServerEditPage(server: widget.admin.server)),
          ),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(l.edit),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Monitors
// ---------------------------------------------------------------------------

class _MonitorsTab extends StatelessWidget {
  const _MonitorsTab({required this.admin});

  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);

    if (admin.data == null && admin.connecting) {
      return const Center(child: CircularProgressIndicator());
    }

    final roots = admin.rootMonitors;
    if (roots.isEmpty) {
      return _EmptyState(
        icon: Icons.monitor_heart_outlined,
        title: l.noMonitorsYet,
        body: l.monitorDescription,
        action: l.addFirstMonitor,
        onAction: () => _openEditor(context, null),
      );
    }

    final rows = <Widget>[];
    for (final monitor in roots) {
      rows.add(_MonitorRow(admin: admin, monitor: monitor, indented: false));
      if (monitor.kind.isGroup) {
        for (final child in admin.childrenOf(monitor.id)) {
          rows.add(_MonitorRow(admin: admin, monitor: child, indented: true));
        }
      }
    }

    return Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.fromLTRB(
            tk.pagePadding.left,
            2,
            tk.pagePadding.right,
            96,
          ),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => rows[i],
        ),
        Positioned(
          right: tk.pagePadding.right,
          bottom: 18,
          child: FloatingActionButton.extended(
            heroTag: 'add_monitor',
            onPressed: () => _openEditor(context, null),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.manageAddMonitor),
          ),
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, MonitorDraft? draft) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MonitorEditPage(draft: draft)),
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.admin,
    required this.monitor,
    required this.indented,
  });

  final AdminController admin;
  final AdminMonitor monitor;
  final bool indented;

  MonitorStatus get _status {
    final rows = admin.data?.heartbeats[monitor.id];
    if (rows == null || rows.isEmpty) return MonitorStatus.unknown;
    return MonitorStatus.fromCode((rows.last['status'] as num?)?.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final status = _status;
    final color = status.color(tk);

    return Padding(
      padding: EdgeInsets.only(left: indented ? 18 : 0),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) {
              final raw = monitor.raw;
              final draft = MonitorDraft.fromRow(raw);
              return MonitorEditPage(draft: draft);
            },
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: monitor.active ? color : tk.muted.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          monitor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.txt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tk.textStrong,
                          ),
                        ),
                      ),
                      if (!monitor.active) ...[
                        const SizedBox(width: 6),
                        AppChip(label: l.pausedLabel, color: tk.muted, dense: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${monitor.kind.label(l.zh)} · ${monitor.target}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.txt.labelSmall?.copyWith(color: tk.muted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 18, color: tk.muted),
              onSelected: (value) => _action(context, value),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: monitor.active ? 'pause' : 'resume',
                  child: Text(monitor.active ? l.pause : l.resumeBtn),
                ),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, String value) async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (value) {
        case 'pause':
        case 'resume':
          await admin.setMonitorActive(monitor.id, value == 'resume');
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.delete),
              content: Text(l.confirmDeleteMonitor),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l.delete),
                ),
              ],
            ),
          );
          if (ok != true) return;
          await admin.deleteMonitor(monitor.id);
          messenger.showSnackBar(SnackBar(content: Text(l.monitorDeleted)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({required this.admin});

  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final list = admin.notifications;

    if (list.isEmpty && admin.connecting) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        if (list.isEmpty)
          _EmptyState(
            icon: Icons.notifications_none_rounded,
            title: l.noNotificationsYet,
            body: l.notificationType,
            action: l.addNotification,
            onAction: () => _open(context),
          )
        else
          ListView.separated(
            padding: EdgeInsets.fromLTRB(
              tk.pagePadding.left,
              2,
              tk.pagePadding.right,
              96,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = list[i];
              final id = (item['id'] as num?)?.toInt() ?? 0;
              final spec = NotificationProviderSpec.byType(item['type'] as String?);
              final active = item['active'] != false;
              return AppCard(
                padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
                onTap: () => _open(context, row: item),
                child: Row(
                  children: [
                    Icon(
                      active ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      size: 18,
                      color: active ? tk.accentInk : tk.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['name'] as String?) ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.txt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tk.textStrong,
                            ),
                          ),
                          Text(
                            spec?.label(l.zh) ?? (item['type'] as String? ?? '—'),
                            style: context.txt.labelSmall?.copyWith(color: tk.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await admin.testNotification(item);
                          messenger.showSnackBar(SnackBar(content: Text(l.testSent)));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      icon: Icon(Icons.send_outlined, size: 17, color: tk.muted),
                    ),
                    IconButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await admin.deleteNotification(id);
                          messenger.showSnackBar(SnackBar(content: Text(l.notificationDeleted)));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      icon: Icon(Icons.delete_outline, size: 17, color: tk.muted),
                    ),
                  ],
                ),
              );
            },
          ),
        Positioned(
          right: tk.pagePadding.right,
          bottom: 18,
          child: FloatingActionButton.extended(
            heroTag: 'add_notification',
            onPressed: () => _open(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.addNotification),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, {Map<String, dynamic>? row}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => NotificationEditPage(existing: row)),
    );
  }
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.admin});

  final AdminController admin;

  @override
  Widget build(BuildContext context) {
    return IncidentPage(admin: admin);
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final topPad = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        tk.pagePadding.left,
        topPad + 40,
        tk.pagePadding.right,
        28,
      ),
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tk.accentSoft,
              borderRadius: BorderRadius.circular(tk.style.isSharp ? 3 : 16),
            ),
            child: Icon(icon, size: 26, color: tk.accentInk),
          ),
        ),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: context.txt.titleMedium),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: context.txt.labelSmall?.copyWith(color: tk.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton(onPressed: onAction, child: Text(action)),
        ),
      ],
    );
  }
}
