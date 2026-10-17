import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/server_config.dart';
import '../../state/app_state.dart';
import 'server_edit_page.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tk = context.tk;
    final l = L10n.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: tk.accent,
        foregroundColor: Colors.white,
        elevation: tk.style.isSharp ? 0 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 14),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(l.addInstance, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          if (app.servers.isEmpty)
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
                itemCount: app.servers.length,
                separatorBuilder: (_, _) => SizedBox(height: tk.cardGap),
                itemBuilder: (context, i) {
                  final server = app.servers[i];
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

  static Future<void> _openEditor(BuildContext context, {ServerConfig? server}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ServerEditPage(server: server)),
    );
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

    return AppCard(
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
                  borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 10),
                ),
                child: Icon(Icons.dns_rounded, size: 18, color: palette.color),
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
                          AppChip(label: l.active, color: tk.accent, dense: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${server.displayHost}  ·  /status/${server.slug}',
                      style: context.txt.labelSmall?.copyWith(color: tk.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: tk.muted, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tk.style.isSharp ? 2 : 12),
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await ServersPage._openEditor(context, server: server);
                  } else if (value == 'delete') {
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
                },
                itemBuilder: (context) => [
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
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 17, color: tk.statusDown),
                        const SizedBox(width: 10),
                        Text(l.delete, style: TextStyle(color: tk.statusDown)),
                      ],
                    ),
                  ),
                ],
              ),
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
                  child: Text(l.setActive, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
