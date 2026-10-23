import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';

/// Full text of the GNU GPL v3.0, bundled as an asset so it reads offline.
class GplLicensePage extends StatefulWidget {
  const GplLicensePage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const GplLicensePage(),
      );

  @override
  State<GplLicensePage> createState() => _GplLicensePageState();
}

class _GplLicensePageState extends State<GplLicensePage> {
  late final Future<List<String>> _blocks = _load();

  /// Splits the text into scrollable chunks: one giant `SelectableText` of 674
  /// lines makes selection jumpy and the layout slow.
  Future<List<String>> _load() async {
    final raw = await rootBundle.loadString('assets/licenses/GPL-3.0.txt');
    final lines = raw.split('\n');
    const chunk = 60;
    return [
      for (var i = 0; i < lines.length; i += chunk)
        lines.sublist(i, i + chunk > lines.length ? lines.length : i + chunk).join('\n'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final l = L10n.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l.gplTitle)),
      body: FutureBuilder<List<String>>(
        future: _blocks,
        builder: (context, snapshot) {
          final blocks = snapshot.data;
          if (blocks == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              tk.pagePadding.left,
              8,
              tk.pagePadding.right,
              MediaQuery.viewPaddingOf(context).bottom + 24,
            ),
            itemCount: blocks.length,
            itemBuilder: (context, i) => SelectableText(
              blocks[i],
              style: context.txt.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.55,
                color: tk.textStrong,
              ),
            ),
          );
        },
      ),
    );
  }
}
