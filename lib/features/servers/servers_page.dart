import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/server_config.dart';
import '../../data/models/share_code.dart';
import '../../state/app_state.dart';
import 'import_dialog.dart';
import 'server_edit_page.dart';

/// Instance list. Instances that share a collection are rendered as one card:
/// the phone merges their status boards, the servers know nothing about it.
class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    // One entry per row: either a lone instance or a whole collection.
    final entries = <Object>[];
    final seen = <String>{};
    for (final server in app.servers) {
      if (server.inCollection) {
        if (seen.add(server.collectionId!)) {
          entries.add(app.serversInCollection(server.collectionId));
        }
      } else {
        entries.add(server);
      }
    }

    return Scaffold(
      // Tab page: the photo is painted by HomeShell, so this must stay clear.
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        backgroundColor: tk.accent,
        foregroundColor: Colors.white,
        elevation: tk.style.isSharp ? 0 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 14),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(l.add, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tk.pagePadding.left + 2,
                topPad + 18,
                tk.pagePadding.right,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.myInstances, style: context.txt.headlineSmall),
                  const SizedBox(height: 3),
                  Text(
                    l.instanceList,
                    style: context.txt.bodySmall?.copyWith(color: tk.muted),
                  ),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_outlined, size: 38, color: tk.muted),
                      const SizedBox(height: 12),
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
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                tk.pagePadding.left,
                0,
                tk.pagePadding.right,
                96,
              ),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => SizedBox(height: tk.cardGap),
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  if (entry is List<ServerConfig>) {
                    return _CollectionCard(
                      name: entry.first.collectionName ?? l.collection,
                      servers: entry,
                    );
                  }
                  final server = entry as ServerConfig;
                  return _ServerTile(
                    server: server,
                    isActive: server.id == app.activeServerId,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Add menu ---------------------------------------------------------------

  static Future<void> _showAddMenu(BuildContext context) async {
    final l = L10n.of(context);
    final tk = context.tk;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewPaddingOf(ctx).bottom + 12,
        ),
        decoration: BoxDecoration(
          color: tk.surfaceCard,
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 4 : 20),
          boxShadow: tk.cardShadow,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.add_link_rounded, color: tk.accentInk),
                title: Text(l.addInstance),
                onTap: () {
                  Navigator.pop(ctx);
                  _openEditor(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.download_rounded, color: tk.accentInk),
                title: Text(l.importInstance),
                subtitle: Text(
                  l.importInstanceHint,
                  style: ctx.txt.labelSmall?.copyWith(color: tk.muted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showImportDialog(context, title: l.importInstance);
                },
              ),
              ListTile(
                leading: Icon(Icons.tune_rounded, color: tk.accentInk),
                title: Text(l.manage),
                subtitle: Text(
                  l.manageHint,
                  style: ctx.txt.labelSmall?.copyWith(color: tk.muted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showManageSheet(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.layers_rounded, color: tk.accentInk),
                title: Text(l.importCollection),
                subtitle: Text(
                  l.importCollectionHint,
                  style: ctx.txt.labelSmall?.copyWith(color: tk.muted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showImportDialog(context, title: l.importCollection);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Housekeeping lives behind its own entry: burying "remove duplicates"
  /// directly under the ➕ button made the add menu look like a junk drawer.
  static Future<void> _showManageSheet(BuildContext context) async {
    final app = context.read<AppState>();
    final l = L10n.of(context);
    final tk = context.tk;
    final duplicates = app.duplicateCount;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewPaddingOf(ctx).bottom + 12,
        ),
        decoration: BoxDecoration(
          color: tk.surfaceCard,
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 4 : 20),
          boxShadow: tk.cardShadow,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(l.manage, style: ctx.txt.titleSmall),
              ),
              ListTile(
                leading: Icon(
                  Icons.cleaning_services_outlined,
                  color: duplicates > 0 ? tk.statusDown : tk.muted,
                ),
                title: Text(l.removeDuplicates),
                subtitle: Text(
                  duplicates > 0 ? l.duplicatesFound(duplicates) : l.noDuplicates,
                  style: ctx.txt.labelSmall?.copyWith(color: tk.muted),
                ),
                enabled: duplicates > 0,
                onTap: duplicates > 0
                    ? () {
                        Navigator.pop(ctx);
                        _removeDuplicates(context);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _removeDuplicates(BuildContext context) async {
    final app = context.read<AppState>();
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final removed = await app.removeDuplicateServers();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed == 0 ? l.noDuplicates : l.removedDuplicates(removed),
        ),
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    ServerConfig? server,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ServerEditPage(server: server)),
    );
  }

  static Future<void> _copy(BuildContext context, String code) async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(SnackBar(content: Text(l.exportedToClipboard)));
  }

  // Collection prompt ------------------------------------------------------

  /// One collection picker used by both the single and the batch dialog.
  ///
  /// Chips in a Wrap were a dead end: a dozen collections turned the dialog into
  /// a wall of tags. A dropdown keeps the list scrollable and the layout fixed.
  static Widget _collectionPicker({
    required List<({String id, String name, List<ServerConfig> servers})>
    existing,
    required String? value,
    required ValueChanged<String?> onChanged,
    required TextEditingController custom,
    required String newLabel,
    required String nameHint,
  }) {
    final isNew = value == _newCollectionKey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(),
          hint: Text(newLabel),
          items: [
            for (final c in existing)
              DropdownMenuItem<String>(
                value: c.name,
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            DropdownMenuItem<String>(
              value: _newCollectionKey,
              child: Text(newLabel),
            ),
          ],
          onChanged: onChanged,
        ),
        if (isNew) ...[
          const SizedBox(height: 10),
          TextField(
            controller: custom,
            autofocus: true,
            decoration: InputDecoration(hintText: nameHint),
          ),
        ],
      ],
    );
  }

  static const String _newCollectionKey = '__new__';

  /// Batch join: tick the instances, pick a collection, done in one request per
  /// instance instead of repeating the dialog for every card.
  static Future<void> _promptBulkCollection(BuildContext context) async {
    final app = context.read<AppState>();
    final l = L10n.of(context);
    final tk = context.tk;
    final existing = app.collections;
    final servers = app.servers;
    final custom = TextEditingController();
    final selected = <String>{};
    String? chosen = existing.isEmpty ? _newCollectionKey : existing.first.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l.bulkJoin),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.bulkJoinHint,
                  style: ctx.txt.labelSmall?.copyWith(
                    color: tk.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _collectionPicker(
                  existing: existing,
                  value: chosen,
                  onChanged: (v) => setLocal(() => chosen = v),
                  custom: custom,
                  newLabel: l.newCollection,
                  nameHint: l.collectionName,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${selected.length} / ${servers.length}',
                      style: ctx.txt.labelSmall?.copyWith(color: tk.muted),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setLocal(() {
                        if (selected.length == servers.length) {
                          selected.clear();
                        } else {
                          selected
                            ..clear()
                            ..addAll(servers.map((s) => s.id));
                        }
                      }),
                      child: Text(l.selectAll),
                    ),
                  ],
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final server in servers)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(server.id),
                          title: Text(
                            server.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              selected.add(server.id);
                            } else {
                              selected.remove(server.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.confirm),
            ),
          ],
        ),
      ),
    );

    final typed = custom.text;
    custom.dispose();
    if (confirmed != true || selected.isEmpty) return;
    final name = (chosen == _newCollectionKey ? typed : chosen)?.trim() ?? '';
    if (name.isEmpty) return;
    for (final id in selected) {
      await app.joinCollection(id, name);
    }
  }

  static Future<void> _promptCollection(
    BuildContext context,
    ServerConfig server,
  ) async {
    final app = context.read<AppState>();
    final l = L10n.of(context);
    final tk = context.tk;
    final existing = app.collections;
    final custom = TextEditingController();
    String? chosen =
        server.collectionName ??
        (existing.isEmpty ? _newCollectionKey : existing.first.name);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l.joinCollection),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.collectionHint,
                style: ctx.txt.labelSmall?.copyWith(
                  color: tk.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _collectionPicker(
                existing: existing,
                value: chosen,
                onChanged: (v) => setLocal(() => chosen = v),
                custom: custom,
                newLabel: l.newCollection,
                nameHint: l.collectionName,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final typed = custom.text;
                final name =
                    (chosen == _newCollectionKey ? typed : chosen)?.trim() ??
                    '';
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await app.joinCollection(server.id, name);
              },
              child: Text(l.confirm),
            ),
          ],
        ),
      ),
    );
    custom.dispose();
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.server, required this.isActive});

  final ServerConfig server;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final app = context.read<AppState>();
    final palette = AccentPalette.byId(server.colorTag);

    return GestureDetector(
      onLongPress: app.menuTrigger == 'longPress'
          ? () => _showServerMenuAt(context, server)
          : null,
      child: AppCard(
        accentStripe: isActive,
        borderColor: isActive ? tk.accent.withValues(alpha: 0.45) : null,
        onTap: () => app.setActiveServer(server.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(
                      tk.style.isSharp ? 2 : 10,
                    ),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    size: 18,
                    color: palette.color,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              server.name,
                              style: context.txt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: tk.textStrong,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            AppChip(
                              label: l.active,
                              color: tk.accent,
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${server.displayHost}  ·  /status/${server.slug}',
                        style: context.txt.labelSmall?.copyWith(
                          color: tk.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (app.menuTrigger == 'button') _ServerMenu(server: server),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 12, color: tk.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    server.statusPageUrl,
                    style: context.txt.labelSmall?.copyWith(color: tk.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isActive)
                  TextButton(
                    onPressed: () => app.setActiveServer(server.id),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      l.setActive,
                      style: const TextStyle(fontSize: 12),
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

/// Collection container: a header with the name and an export action, then one
/// compact row per member in list order.
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.name, required this.servers});

  final String name;
  final List<ServerConfig> servers;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final app = context.read<AppState>();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_rounded, size: 17, color: tk.accentInk),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: context.txt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tk.textStrong,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l.collectionMembers(servers.length),
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.exportCollection,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.ios_share_rounded, size: 18, color: tk.muted),
                onPressed: () => ServersPage._copy(
                  context,
                  ShareCode.forCollection(name, servers),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          for (var i = 0; i < servers.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _CollectionMember(
              server: servers[i],
              isActive: servers[i].id == app.activeServerId,
              index: i + 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionMember extends StatelessWidget {
  const _CollectionMember({
    required this.server,
    required this.isActive,
    required this.index,
  });

  final ServerConfig server;
  final bool isActive;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);
    final app = context.read<AppState>();
    final palette = AccentPalette.byId(server.colorTag);

    return GestureDetector(
      onLongPress: app.menuTrigger == 'longPress'
          ? () => _showServerMenuAt(context, server)
          : null,
      child: InkWell(
        onTap: () => app.setActiveServer(server.id),
        borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              Text(
                '$index',
                style: context.txt.labelSmall?.copyWith(
                  color: tk.muted,
                  fontFeatures: tk.tabular,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: context.txt.bodySmall?.copyWith(
                        color: tk.textStrong,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      server.displayHost,
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isActive)
                AppChip(label: l.active, color: tk.accent, dense: true),
              _ServerMenu(server: server, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

List<PopupMenuEntry<String>> _serverMenuItems(
  BuildContext context,
  ServerConfig server,
) {
  final tk = context.tk;
  final l = L10n.of(context);
  return [
    PopupMenuItem(
      value: 'edit',
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 17),
          const SizedBox(width: 10),
          Text(l.edit),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'export',
      child: Row(
        children: [
          const Icon(Icons.ios_share_rounded, size: 17),
          const SizedBox(width: 10),
          Text(l.exportConfig),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'join',
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, size: 17),
          const SizedBox(width: 10),
          Text(l.joinCollection),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'bulk',
      child: Row(
        children: [
          const Icon(Icons.checklist_rounded, size: 17),
          const SizedBox(width: 10),
          Text(l.bulkJoin),
        ],
      ),
    ),
    if (server.inCollection)
      PopupMenuItem(
        value: 'leave',
        child: Row(
          children: [
            const Icon(Icons.layers_clear_rounded, size: 17),
            const SizedBox(width: 10),
            Text(l.leaveCollection),
          ],
        ),
      ),
    PopupMenuItem(
      value: 'delete',
      child: Row(
        children: [
          Icon(Icons.delete_outline, size: 17, color: tk.statusDown),
          const SizedBox(width: 10),
          Text(l.delete, style: TextStyle(color: tk.statusDown)),
        ],
      ),
    ),
  ];
}

Future<void> _handleServerMenu(
  BuildContext context,
  ServerConfig server,
  String value,
) async {
  final tk = context.tk;
  final l = L10n.of(context);
  final app = context.read<AppState>();
  switch (value) {
    case 'edit':
      await ServersPage._openEditor(context, server: server);
    case 'export':
      await ServersPage._copy(
        context,
        ShareCode.forInstance(
          server,
          collectionName: server.inCollection ? server.collectionName : null,
        ),
      );
    case 'join':
      await ServersPage._promptCollection(context, server);
    case 'bulk':
      await ServersPage._promptBulkCollection(context);
    case 'leave':
      await app.leaveCollection(server.id);
    case 'delete':
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.deleteInstance),
          content: Text(l.deleteInstanceBody(server.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tk.statusDown,
                minimumSize: const Size(0, 40),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.delete),
            ),
          ],
        ),
      );
      if (ok == true) await app.removeServer(server.id);
  }
}

/// Opens the same menu the ⋯ button shows, anchored to the card the user
/// long-pressed. One menu, two ways in.
Future<void> _showServerMenuAt(
  BuildContext context,
  ServerConfig server,
) async {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final value = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    ),
    items: _serverMenuItems(context, server),
  );
  if (value == null || !context.mounted) return;
  await _handleServerMenu(context, server, value);
}

class _ServerMenu extends StatelessWidget {
  const _ServerMenu({required this.server, this.dense = false});

  final ServerConfig server;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        color: tk.muted,
        size: dense ? 18 : 20,
      ),
      padding: dense ? EdgeInsets.zero : const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
      ),
      itemBuilder: (context) => _serverMenuItems(context, server),
      onSelected: (value) => _handleServerMenu(context, server, value),
    );
  }
}
