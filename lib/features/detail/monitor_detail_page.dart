import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/fmt.dart';
import '../../core/utils/status_ui.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/heartbeat_bar.dart';
import '../../core/widgets/ping_chart.dart';
import '../../data/models/status_page.dart';
import '../../state/app_state.dart';
import '../../state/status_controller.dart';

class MonitorDetailPage extends StatelessWidget {
  const MonitorDetailPage({
    super.key,
    required this.monitor,
    this.groupName = '',
  });

  final Monitor monitor;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final ctl = context.watch<StatusController>();
    final app = context.watch<AppState>();
    final snap = ctl.snapshot;

    if (snap == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(context.read<AppState>().clampName(monitor.name)),
        ),
        body: Center(child: Text(l.noData)),
      );
    }

    final status = snap.statusOf(monitor.id);
    final heartbeats = snap.heartbeatsOf(monitor.id);
    final color = status.color(tk);

    final pings = heartbeats
        .where((h) => h.ping != null && h.ping! > 0)
        .map((h) => h.ping!)
        .toList(growable: false);

    final avg = pings.isEmpty ? null : pings.reduce((a, b) => a + b) / pings.length;
    final minP = pings.isEmpty ? null : pings.reduce((a, b) => a < b ? a : b);
    final maxP = pings.isEmpty ? null : pings.reduce((a, b) => a > b ? a : b);

    final downEvents = heartbeats.where((h) => h.status == MonitorStatus.down).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(monitor.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(tk.pagePadding.left, 0, tk.pagePadding.right, 28),
        children: [
          // Hero status
          AppCard(
            color: status.softColor(tk).withValues(alpha: context.isDark ? 0.18 : 0.09),
            borderColor: color.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 14),
                  ),
                  child: Icon(status.icon, color: color, size: 24),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.label(l),
                        style: context.txt.titleLarge?.copyWith(color: color, fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          Fmt.monitorType(monitor.type),
                          if (groupName.isNotEmpty) groupName,
                        ].join(' · '),
                        style: context.txt.bodySmall?.copyWith(color: tk.muted),
                      ),
                    ],
                  ),
                ),
                if (app.showSla && heartbeats.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.percent(snap.uptimeOf(monitor.id, 24)),
                        style: context.txt.titleMedium?.copyWith(
                          fontFeatures: tk.tabular,
                          color: tk.textStrong,
                        ),
                      ),
                      Text(
                        l.uptime24h,
                        style: context.txt.labelSmall?.copyWith(color: tk.muted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Heartbeat strip
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.last60Checks, style: context.txt.titleSmall),
                    const Spacer(),
                    Text(
                      Fmt.dateTime(snap.fetchedAt),
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                HeartbeatBar(
                  heartbeats: heartbeats,
                  maxBars: 60,
                  height: 70,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendDot(color: tk.statusUp, label: l.statusUp),
                    const SizedBox(width: 12),
                    _LegendDot(color: tk.statusDown, label: l.statusDown),
                    const SizedBox(width: 12),
                    _LegendDot(color: tk.statusPending, label: l.statusPending),
                    const SizedBox(width: 12),
                    _LegendDot(color: tk.statusMaintenance, label: l.statusMaintenance),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Uptime windows
          if (app.showSla)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.uptimeStats, style: context.txt.titleSmall),
                const SizedBox(height: 12),
                for (final window in const [24, 720, 2160]) ...[
                  _UptimeRow(
                    label: window == 24
                        ? l.uptime24h
                        : window == 720
                            ? l.uptime30d
                            : l.uptime90d,
                    ratio: snap.uptimeOf(monitor.id, window),
                  ),
                  if (window != 2160) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Response time
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.responseTimeMs, style: context.txt.titleSmall),
                    const Spacer(),
                    if (pings.isNotEmpty)
                      AppChip(
                        label: '${Fmt.ping(avg)} avg',
                        dense: true,
                        color: tk.accent,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                PingChart(heartbeats: heartbeats),
                if (pings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Metric(label: l.minResponse, value: Fmt.ping(minP)),
                      _Metric(label: l.avgResponse, value: Fmt.ping(avg)),
                      _Metric(label: l.maxResponse, value: Fmt.ping(maxP)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Details
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.details, style: context.txt.titleSmall),
                const SizedBox(height: 10),
                _DetailRow(label: l.type, value: Fmt.monitorType(monitor.type)),
                _DetailRow(label: 'ID', value: '#${monitor.id}'),
                if (monitor.certExpiryDays != null)
                  _DetailRow(
                    label: l.certTls,
                    value: monitor.certValid == false
                        ? l.certExpired
                        : l.certDaysLeft(monitor.certExpiryDays!),
                    valueColor: monitor.hasCertIssue ? tk.statusPending : null,
                  ),
                _DetailRow(
                  label: l.downCount,
                  value: '$downEvents / ${heartbeats.length}',
                  valueColor: downEvents > 0 ? tk.statusDown : null,
                ),
                if (monitor.sendUrl) _DetailRow(label: 'URL', value: l.notPublicUrl),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Recent events
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.recentEvents, style: context.txt.titleSmall),
                const SizedBox(height: 8),
                if (heartbeats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      l.noEvents,
                      style: context.txt.bodySmall?.copyWith(color: tk.muted),
                    ),
                  )
                else
                  for (final hb in _recentNotable(heartbeats))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          StatusDot(status: hb.status, size: 6),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              hb.msg.trim().isEmpty
                                  ? hb.status.label(l)
                                  : hb.msg.trim(),
                              style: context.txt.bodySmall?.copyWith(color: tk.textStrong),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Fmt.shortDateTime(hb.time),
                            style: context.txt.labelSmall?.copyWith(
                              color: tk.muted,
                              fontFeatures: tk.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Picks out state changes plus the newest sample, so the event list reads
  /// like a timeline instead of 60 identical rows.
  static List<Heartbeat> _recentNotable(List<Heartbeat> list) {
    final out = <Heartbeat>[];
    for (var i = list.length - 1; i >= 0; i--) {
      final changed = i == 0 || list[i].status != list[i - 1].status;
      if (changed || list[i].msg.trim().isNotEmpty) out.add(list[i]);
      if (out.length >= 8) break;
    }
    if (out.isEmpty && list.isNotEmpty) out.add(list.last);
    return out;
  }
}

class _UptimeRow extends StatelessWidget {
  const _UptimeRow({required this.label, required this.ratio});

  final String label;
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                label,
                style: context.txt.labelSmall?.copyWith(color: tk.muted),
              ),
            ),
            Expanded(child: UptimeBar(ratio: ratio, height: 6)),
            SizedBox(
              width: 66,
              child: Text(
                Fmt.percent(ratio),
                textAlign: TextAlign.right,
                style: context.txt.labelMedium?.copyWith(
                  fontFeatures: tk.tabular,
                  color: tk.textStrong,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.txt.labelSmall?.copyWith(color: tk.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.txt.titleSmall?.copyWith(
              fontFeatures: tk.tabular,
              color: tk.textStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: context.txt.bodySmall?.copyWith(color: tk.muted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.txt.bodySmall?.copyWith(
                color: valueColor ?? tk.textStrong,
                fontWeight: FontWeight.w600,
                fontFeatures: tk.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.txt.labelSmall?.copyWith(color: tk.muted, fontSize: 10),
        ),
      ],
    );
  }
}
