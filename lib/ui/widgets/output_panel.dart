import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/convert_mode.dart';
import '../../state/converter_state.dart';

/// Right panel: Markdown text (docx2md) or preview / result card (md2docx).
class OutputPanel extends StatelessWidget {
  const OutputPanel({super.key, required this.state});

  final ConverterState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = state;

    Widget content;
    if (s.busy) {
      content = const Center(child: CircularProgressIndicator());
    } else if (s.error != null) {
      content = SingleChildScrollView(
        child: SelectableText(
          s.error!,
          key: const Key('error-text'),
          style: TextStyle(color: cs.error),
        ),
      );
    } else if (s.mode == ConvertMode.docx2md) {
      content = s.output.isEmpty
          ? const _Placeholder('The Markdown result appears here')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.imageInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      s.imageInfo!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      s.output,
                      key: const Key('output-text'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            );
    } else if (s.converted && s.docxSize > 0) {
      content = Center(
        child: Card(
          key: const Key('result-card'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 48, color: cs.primary),
                const SizedBox(height: 8),
                const Text('Ready to download as .docx'),
                Text(
                  '${(s.docxSize / 1024).toStringAsFixed(1)} KB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    } else if (s.markdownInput.trim().isEmpty) {
      content = const _Placeholder('A preview of your Markdown appears here');
    } else {
      content = Markdown(
        data: s.markdownInput,
        selectable: true,
        // Images are not previewed (they may be local paths).
        sizedImageBuilder: (_) => const SizedBox.shrink(),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: content,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.outline),
    ),
  );
}
