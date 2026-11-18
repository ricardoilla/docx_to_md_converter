import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../models/convert_mode.dart';
import '../../state/converter_state.dart';
import 'drop_zone.dart';

/// Left panel: drop zone / file card (docx2md) or Markdown editor (md2docx).
class InputPanel extends StatefulWidget {
  const InputPanel({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onDrop,
  });

  final ConverterState state;
  final VoidCallback onOpen;
  final void Function(String path) onDrop;

  @override
  State<InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends State<InputPanel> {
  final _controller = TextEditingController();
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.state.markdownInput;
    _controller.addListener(() => widget.state.setMarkdown(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    // Keep the editor in sync when the state changes externally (open/clear).
    if (_controller.text != s.markdownInput) {
      _controller.text = s.markdownInput;
    }
    final cs = Theme.of(context).colorScheme;

    Widget body;
    if (s.mode == ConvertMode.docx2md) {
      body = s.inputPath == null
          ? DropZone(highlighted: _dragging, onTap: widget.onOpen)
          : Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(s.inputName!, overflow: TextOverflow.ellipsis),
                subtitle: Text(_size(s.inputSize)),
                trailing: IconButton(
                  key: const Key('remove-file'),
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: s.clear,
                ),
              ),
            );
      if (s.inputPath != null) {
        body = Align(alignment: Alignment.topCenter, child: body);
      }
    } else {
      body = TextField(
        key: const Key('markdown-editor'),
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Paste Markdown here, or drop / open a .md file',
        ),
      );
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) {
        setState(() => _dragging = false);
        if (d.files.isNotEmpty) widget.onDrop(d.files.first.path);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: _dragging && s.mode == ConvertMode.md2docx
              ? Border.all(color: cs.primary, width: 2)
              : null,
        ),
        child: body,
      ),
    );
  }
}
