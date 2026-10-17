import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/fmt.dart';
import '../../core/utils/status_ui.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/remote_icon.dart';
import '../../core/widgets/heartbeat_bar.dart';
import '../../data/models/status_page.dart';
import '../../state/app_state.dart';
import '../../state/status_controller.dart';
import '../detail/monitor_detail_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ctl = context.watch<StatusController>();
    final tk = context.tk;
    final l = L10n.of(context);

    if (app.activeServer == null) {
      return _NoInstance(l: l);
    }

    final snap = ctl.snapshot;

    return RefreshIndicator(
      color: tk.accent,
      backgroundColor: tk.surfaceCard,
      onRefresh: () => ctl.load(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              app: app,
              ctl: ctl,
            ),
          ),
          if (ctl.error != null && snap != null)
            SliverToBoxAdapter(child: _OfflineBanner(message: ctl.error!)),
          if (snap?.incident != null)
            SliverToBoxAdapter(child: _IncidentBanner(incident: snap!.incident!)),
          if (ctl.loading && snap == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (snap != null) ...[
            if (snap.maintenances.where((m) => m.isActive).isNotEmpty)
              SliverToBoxAdapter(
                child: _MaintenanceBanner(
                  windows: snap.maintenances.where((m) => m.isActive).toList(),
                ),
              ),
            ..._buildGroups(context, snap, l),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(tk.pagePadding.left, 4, tk.pagePadding.right, 24),
                child: Text(
                  snap.config.footerText?.trim().isNotEmpty == true
                      ? snap.config.footerText!
                      : (snap.config.description.isNotEmpty ? snap.config.description : ''),
                  textAlign: TextAlign.center,
                  style: context.txt.bodySmall?.copyWith(color: tk.muted),
                ),
              ),
            ),
          ] else
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                message: ctl.error ?? l.statusUnknown,
                onRetry: () => ctl.load(showSpinner: true),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGroups(BuildContext context, StatusSnapshot snap, L10n l) {
    final tk = context.tk;
    final slivers = <Widget>[];
    slivers.add(
      SliverPadding(
        padding: EdgeInsets.fromLTRB(tk.pagePadding.left, tk.cardGap, tk.pagePadding.right, 0),
        sliver: SliverList.separated(
          itemCount: snap.groups.length,
          separatorBuilder: (_, _) => SizedBox(height: tk.cardGap),
          itemBuilder: (context, i) {
            final group = snap.groups[i];
            return _GroupBlock(group: group, snapshot: snap);
          },
        ),
      ),
    );
    return slivers;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.app, required this.ctl});

  final AppState app;
  final StatusController ctl;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final snap = ctl.snapshot;
    final topPad = MediaQuery.of(context).padding.top;
    final server = app.activeServer;
    final overall = snap?.overallStatus ?? MonitorStatus.unknown;

    final String headline;
    if (ctl.error != null && snap == null) {
      headline = l.overallUnknown;
    } else if (snap == null) {
      headline = l.loading;
    } else {
      final down = snap.downCount;
      if (down == 0) {
        headline = l.overallOperational;
      } else if (down * 2 >= snap.allMonitors.length) {
        headline = l.overallMajor;
      } else {
        headline = l.overallPartial;
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        tk.pagePadding.left + 2,
        topPad + (tk.style.isSharp ? 8 : 12),
        tk.pagePadding.right + 2,
        tk.style.isSharp ? 14 : 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tk.headerFrom, tk.headerTo],
        ),
        borderRadius: tk.style.isSharp
            ? BorderRadius.zero
            : const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: tk.style.isSharp
            ? null
            : [
                BoxShadow(
                  color: tk.headerFrom.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 9),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                // The status page publishes its own icon; show it instead of a
                // generic mark so the instance is recognisable at a glance.
                child: RemoteIcon(
                  path: server?.resolveAsset(ctl.snapshot?.config.iconPath),
                  size: 24,
                  fallback: const Icon(
                    Icons.monitor_heart_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server?.name ?? '',
                      style: context.txt.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      server?.displayHost ?? '',
                      style: context.txt.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (ctl.refreshing)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                )
              else
                _HeaderButton(
                  icon: Icons.refresh_rounded,
                  onTap: () => ctl.load(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StatusDot(status: overall, size: 9, pulse: overall == MonitorStatus.down),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: context.txt.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (snap != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l.monitorsCount(snap.allMonitors.length)} · ${l.updated} ${Fmt.relative(snap.fetchedAt, l)}',
              style: context.txt.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatPill(
                  label: l.upCount,
                  value: '${snap.upCount}',
                  color: tk.statusUp,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: l.downCount,
                  value: '${snap.downCount}',
                  color: tk.statusDown,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: l.pendingCount,
                  value: '${snap.pendingCount}',
                  color: tk.statusPending,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: l.maintenanceCount,
                  value: '${snap.maintenanceCount}',
                  color: tk.statusMaintenance,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 9),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: context.txt.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: context.txt.titleMedium?.copyWith(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFeatures: tk.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.group, required this.snapshot});

  final MonitorGroup group;
  final StatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final monitors = group.realMonitors;
    final headerOnly = group.monitors.isNotEmpty && monitors.isEmpty;

    if (monitors.isEmpty && !headerOnly) return const SizedBox.shrink();

    final downCount = monitors.where((m) => snapshot.statusOf(m.id) == MonitorStatus.down).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: group.name,
          trailing: downCount > 0
              ? AppChip(
                  label: '$downCount',
                  color: tk.statusDown,
                  dense: true,
                  icon: Icons.error_rounded,
                )
              : AppChip(
                  label: '${monitors.length}',
                  color: tk.muted,
                  dense: true,
                ),
        ),
        if (monitors.isNotEmpty)
          AppCard(
            padding: EdgeInsets.zero,
            accentStripe: downCount > 0,
            borderColor: downCount > 0 ? tk.statusDown.withValues(alpha: 0.4) : null,
            child: Column(
              children: [
                for (var i = 0; i < monitors.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: tk.hairline, indent: 14, endIndent: 14),
                  _MonitorRow(
                    key: ValueKey('${group.id}_${monitors[i].id}'),
                    monitor: monitors[i],
                    snapshot: snapshot,
                    l: l,
                    groupName: group.name,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    super.key,
    required this.monitor,
    required this.snapshot,
    required this.l,
    required this.groupName,
  });

  final Monitor monitor;
  final StatusSnapshot snapshot;
  final L10n l;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final app = context.watch<AppState>();
    final status = snapshot.statusOf(monitor.id);
    final heartbeats = snapshot.heartbeatsOf(monitor.id);
    final u24 = snapshot.uptimeOf(monitor.id, 24);
    final ping = snapshot.responseTimeOf(monitor.id);
    final isDown = status == MonitorStatus.down;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MonitorDetailPage(monitor: monitor, groupName: groupName),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tk.style.isSharp ? 12 : 14,
          tk.style.isSharp ? 9 : 11,
          tk.style.isSharp ? 12 : 14,
          tk.style.isSharp ? 9 : 11,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusDot(status: status, size: 7, pulse: isDown),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.clampName(monitor.name),
                    style: context.txt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tk.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (app.showSla && u24 != null)
                  Text(
                    Fmt.percent(u24),
                    style: context.txt.labelSmall?.copyWith(
                      color: u24 >= 0.995
                          ? tk.statusUp
                          : u24 >= 0.97
                              ? tk.statusPending
                              : tk.statusDown,
                      fontFeatures: tk.tabular,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            HeartbeatBar(heartbeats: heartbeats, height: 22, maxBars: 50),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: _MetaText(
                          text: Fmt.monitorType(monitor.type),
                          ellipsis: true,
                        ),
                      ),
                      if (ping != null) ...[
                        const _Dot(),
                        _MetaText(text: Fmt.ping(ping)),
                      ],
                      if (monitor.certExpiryDays != null) ...[
                        const _Dot(),
                        Icon(
                          monitor.hasCertIssue ? Icons.lock_clock : Icons.verified_user_outlined,
                          size: 11,
                          color: monitor.hasCertIssue ? tk.statusPending : tk.muted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: _MetaText(
                            text: l.certDaysLeft(monitor.certExpiryDays!),
                            color: monitor.hasCertIssue ? tk.statusPending : null,
                            ellipsis: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isDown) ...[
                  const SizedBox(width: 8),
                  Text(
                    l.statusDown,
                    style: context.txt.labelSmall?.copyWith(
                      color: tk.statusDown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text, this.color, this.ellipsis = false});

  final String text;
  final Color? color;
  final bool ellipsis;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Text(
      text,
      maxLines: 1,
      overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.clip,
      softWrap: false,
      style: context.txt.labelSmall?.copyWith(
        color: color ?? tk.muted,
        fontWeight: FontWeight.w500,
        fontSize: 10.5,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(color: context.tk.muted, fontSize: 10),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(tk.pagePadding.left, tk.cardGap, tk.pagePadding.right, 0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: tk.statusPending.withValues(alpha: 0.10),
        borderColor: tk.statusPending.withValues(alpha: 0.35),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: tk.statusPending),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.offlineBanner,
                style: context.txt.bodySmall?.copyWith(color: tk.statusPending),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentBanner extends StatelessWidget {
  const _IncidentBanner({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final color = incident.isDanger ? tk.statusDown : tk.accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(tk.pagePadding.left, tk.cardGap, tk.pagePadding.right, 0),
      child: AppCard(
        color: color.withValues(alpha: 0.08),
        borderColor: color.withValues(alpha: 0.32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded, size: 16, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    incident.title,
                    style: context.txt.titleSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (incident.content.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                incident.content,
                style: context.txt.bodySmall?.copyWith(color: tk.textStrong),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              Fmt.dateTime(incident.createdDate),
              style: context.txt.labelSmall?.copyWith(color: tk.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner({required this.windows});

  final List<MaintenanceWindow> windows;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(tk.pagePadding.left, tk.cardGap, tk.pagePadding.right, 0),
      child: AppCard(
        color: tk.statusMaintenance.withValues(alpha: 0.08),
        borderColor: tk.statusMaintenance.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle_outlined, size: 16, color: tk.statusMaintenance),
                const SizedBox(width: 7),
                Text(l.scheduledMaintenance, style: context.txt.titleSmall?.copyWith(
                  color: tk.statusMaintenance,
                )),
              ],
            ),
            const SizedBox(height: 6),
            for (final w in windows)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${w.title} · ${Fmt.shortDateTime(w.startDate)} → ${Fmt.shortDateTime(w.endDate)}',
                  style: context.txt.bodySmall?.copyWith(color: tk.textStrong),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: tk.muted),
            const SizedBox(height: 12),
            Text(
              l.overallUnknown,
              style: context.txt.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.txt.bodySmall?.copyWith(color: tk.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(l.retry)),
          ],
        ),
      ),
    );
  }
}

class _NoInstance extends StatelessWidget {
  const _NoInstance({required this.l});

  final L10n l;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tk.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.dns_outlined, size: 34, color: tk.accentInk),
            ),
            const SizedBox(height: 18),
            Text(l.noInstances, style: context.txt.titleMedium),
            const SizedBox(height: 6),
            Text(
              l.noInstancesHint,
              textAlign: TextAlign.center,
              style: context.txt.bodySmall?.copyWith(color: tk.muted),
            ),
          ],
        ),
      ),
    );
  }
}
