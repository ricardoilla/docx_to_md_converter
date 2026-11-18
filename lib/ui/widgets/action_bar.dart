import 'package:flutter/material.dart';

import '../../models/convert_mode.dart';
import '../../state/converter_state.dart';

/// Bottom bar: [Open file] [Clear]   [Convert]   [Copy] [Download].
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onConvert,
    required this.onCopy,
    required this.onDownload,
  });

  final ConverterState state;
  final VoidCallback onOpen;
  final VoidCallback onConvert;
  final VoidCallback onCopy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final isDocx2md = s.mode == ConvertMode.docx2md;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 4,
          child: s.busy ? const LinearProgressIndicator() : null,
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              OutlinedButton.icon(
                key: const Key('open-button'),
                onPressed: s.busy ? null : onOpen,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open file'),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('clear-button'),
                onPressed: s.busy ? null : s.clear,
                child: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('convert-button'),
                onPressed: s.canConvert ? onConvert : null,
                icon: const Icon(Icons.autorenew),
                label: const Text('Convert'),
              ),
              const Spacer(),
              if (isDocx2md) ...[
                OutlinedButton.icon(
                  key: const Key('copy-button'),
                  onPressed: s.canCopy ? onCopy : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton.tonalIcon(
                key: const Key('download-button'),
                onPressed: s.canDownload ? onDownload : null,
                icon: const Icon(Icons.download),
                label: Text(isDocx2md ? 'Download .md' : 'Download .docx'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
