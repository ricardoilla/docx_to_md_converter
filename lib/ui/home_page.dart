import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/convert_mode.dart';
import '../state/converter_state.dart';
import 'widgets/action_bar.dart';
import 'widgets/header_bar.dart';
import 'widgets/input_panel.dart';
import 'widgets/output_panel.dart';

class _OpenIntent extends Intent {
  const _OpenIntent();
}

class _ConvertIntent extends Intent {
  const _ConvertIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

/// Main (and only) screen.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});

  final ConverterState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ConverterState get s => widget.state;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    s.addListener(_showErrors);
  }

  @override
  void dispose() {
    s.removeListener(_showErrors);
    super.dispose();
  }

  /// Shows each new error once in a SnackBar (also shown inline).
  void _showErrors() {
    final e = s.error;
    if (e != null && e != _lastShownError && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e), backgroundColor: Colors.red));
    }
    _lastShownError = e;
  }

  Future<void> _open() async {
    if (s.busy) return;
    final docx = s.mode == ConvertMode.docx2md;
    final file = await openFile(
      acceptedTypeGroups: [
        docx
            ? const XTypeGroup(label: 'Word', extensions: ['docx'])
            : const XTypeGroup(
                label: 'Markdown',
                extensions: ['md', 'markdown', 'txt'],
              ),
      ],
    );
    if (file != null) await s.loadFile(file.path);
  }

  Future<void> _copy() async {
    if (!s.canCopy) return;
    await Clipboard.setData(ClipboardData(text: s.output));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied ✓')));
    }
  }

  Future<void> _download() async {
    if (!s.canDownload) return;
    final docx = s.mode == ConvertMode.md2docx;
    final loc = await getSaveLocation(
      suggestedName: s.suggestedOutputName,
      acceptedTypeGroups: [
        docx
            ? const XTypeGroup(label: 'Word', extensions: ['docx'])
            : const XTypeGroup(label: 'Markdown', extensions: ['md']),
      ],
    );
    if (loc == null) return;
    final ok = docx
        ? await s.saveDocx(loc.path)
        : await s.saveMarkdown(loc.path);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved ✓')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mac = Platform.isMacOS;
    SingleActivator key(LogicalKeyboardKey k, {bool shift = false}) =>
        SingleActivator(k, control: !mac, meta: mac, shift: shift);

    return Shortcuts(
      shortcuts: {
        key(LogicalKeyboardKey.keyO): const _OpenIntent(),
        key(LogicalKeyboardKey.enter): const _ConvertIntent(),
        key(LogicalKeyboardKey.keyS): const _SaveIntent(),
        key(LogicalKeyboardKey.keyC, shift: true): const _CopyIntent(),
      },
      child: Actions(
        actions: {
          _OpenIntent: CallbackAction<_OpenIntent>(onInvoke: (_) => _open()),
          _ConvertIntent: CallbackAction<_ConvertIntent>(
            onInvoke: (_) => s.convert(),
          ),
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) => _download(),
          ),
          _CopyIntent: CallbackAction<_CopyIntent>(onInvoke: (_) => _copy()),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: ListenableBuilder(
                listenable: s,
                builder: (context, _) => Column(
                  children: [
                    HeaderBar(
                      mode: s.mode,
                      swapCount: s.swapCount,
                      onSwap: s.swap,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: InputPanel(
                              state: s,
                              onOpen: _open,
                              onDrop: s.loadFile,
                            ),
                          ),
                          const Icon(Icons.arrow_forward),
                          Expanded(child: OutputPanel(state: s)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ActionBar(
                      state: s,
                      onOpen: _open,
                      onConvert: s.convert,
                      onCopy: _copy,
                      onDownload: _download,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
