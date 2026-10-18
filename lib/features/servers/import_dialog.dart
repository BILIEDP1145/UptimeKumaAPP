import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/share_code.dart';
import '../../state/app_state.dart';

/// Paste-and-import sheet, shared by the instance list and the first-run guide.
///
/// It takes whatever the user has: one `uptimekuma://instance/...` link, a
/// collection link, or several links pasted on separate lines. Anything that
/// does not parse is skipped, and an entirely unparsable paste reports back
/// instead of silently doing nothing.
Future<int> showImportDialog(
  BuildContext context, {
  required String title,
}) async {
  final controller = TextEditingController();
  final app = context.read<AppState>();
  final l = L10n.of(context);
  final tk = context.tk;
  final messenger = ScaffoldMessenger.of(context);
  var imported = 0;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.importHint,
              style: ctx.txt.labelSmall?.copyWith(color: tk.muted, height: 1.4),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              autofocus: true,
              autocorrect: false,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(hintText: 'uptimekuma://…'),
            ),
            const SizedBox(height: 8),
            _PasteButton(controller: controller),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final payloads = <SharePayload>[];
            for (final line in controller.text.split(RegExp(r'[\r\n]+'))) {
              if (line.trim().isEmpty) continue;
              final payload = ShareCode.parse(line);
              if (payload != null) payloads.add(payload);
            }
            if (payloads.isEmpty) {
              messenger.showSnackBar(SnackBar(content: Text(l.importInvalid)));
              return;
            }
            Navigator.pop(ctx);
            imported = await app.importPayloads(payloads);
            messenger.showSnackBar(
              SnackBar(content: Text(l.importedCount(imported))),
            );
          },
          child: Text(l.importAction),
        ),
      ],
    ),
  );
  controller.dispose();
  return imported;
}

/// Reads the clipboard into the field — first-run users usually have the link
/// waiting there and no idea it should be pasted rather than typed.
class _PasteButton extends StatelessWidget {
  const _PasteButton({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final text = data?.text?.trim() ?? '';
          if (text.isEmpty) return;
          controller.text = text;
          controller.selection = TextSelection.collapsed(offset: text.length);
        },
        icon: const Icon(Icons.content_paste_rounded, size: 15),
        label: Text(l.pasteFromClipboard),
      ),
    );
  }
}
