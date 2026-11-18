import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/convert_mode.dart';
import '../services/pandoc_service.dart';

/// Holds everything the UI shows: mode, input, output, busy flag and errors.
class ConverterState extends ChangeNotifier {
  ConverterState({
    PandocService? pandoc,
    ConvertMode initialMode = ConvertMode.docx2md,
    this.onModeChanged,
  }) : _pandoc = pandoc ?? PandocService(),
       _mode = initialMode;

  final PandocService _pandoc;

  /// Called whenever the mode changes (used to persist the last mode).
  final void Function(ConvertMode mode)? onModeChanged;

  ConvertMode _mode;
  String? _inputPath; // docx2md: the loaded .docx
  int _inputSize = 0;
  String _markdownInput = ''; // md2docx: editor contents
  String? _markdownSourceDir; // folder of an opened .md (for relative images)
  String _output = ''; // docx2md: Markdown result
  String? _imageInfo; // docx2md: "N images extracted to ..."
  bool _converted = false; // a conversion finished successfully
  int _docxSize = 0; // md2docx: size of the validated result
  bool _busy = false;
  String? _error;
  int _swapCount = 0;

  ConvertMode get mode => _mode;
  String? get inputPath => _inputPath;
  String? get inputName => _inputPath == null ? null : p.basename(_inputPath!);
  int get inputSize => _inputSize;
  String get markdownInput => _markdownInput;
  String get output => _output;
  String? get imageInfo => _imageInfo;
  bool get converted => _converted;
  int get docxSize => _docxSize;
  bool get busy => _busy;
  String? get error => _error;

  /// Number of swaps so far; the arrow turns 180° per swap.
  int get swapCount => _swapCount;

  bool get hasInput => _mode == ConvertMode.docx2md
      ? _inputPath != null
      : _markdownInput.trim().isNotEmpty;

  bool get canConvert => hasInput && !_busy;
  bool get canCopy =>
      _mode == ConvertMode.docx2md && _output.isNotEmpty && !_busy;
  bool get canDownload => _mode == ConvertMode.docx2md
      ? _output.isNotEmpty && !_busy
      : hasInput && !_busy;

  /// Suggested file name for the save dialog.
  String get suggestedOutputName {
    if (_mode == ConvertMode.docx2md) {
      return '${p.basenameWithoutExtension(_inputPath ?? 'document')}.md';
    }
    return 'document.docx';
  }

  /// Toggles direction and resets both panels.
  void swap() {
    _mode = _mode.other;
    _swapCount++;
    _resetPanels();
    onModeChanged?.call(_mode);
    notifyListeners();
  }

  void _resetPanels() {
    _inputPath = null;
    _inputSize = 0;
    _markdownInput = '';
    _markdownSourceDir = null;
    _clearOutput();
    _error = null;
    _pandoc.cleanup();
  }

  void _clearOutput() {
    _output = '';
    _imageInfo = null;
    _converted = false;
    _docxSize = 0;
  }

  /// Removes the input and any result.
  void clear() {
    _resetPanels();
    notifyListeners();
  }

  /// Editor text changed (md2docx).
  void setMarkdown(String text) {
    if (text == _markdownInput) return;
    _markdownInput = text;
    _converted = false;
    _error = null;
    notifyListeners();
  }

  /// Loads a dropped/opened file for the current mode. docx2md converts
  /// automatically once the file is loaded.
  Future<void> loadFile(String path) async {
    final ext = p.extension(path).toLowerCase();
    if (_mode == ConvertMode.docx2md) {
      if (ext != '.docx') {
        _fail('Please choose a .docx file.');
        return;
      }
      try {
        _inputSize = await File(path).length();
      } catch (e) {
        _fail('Could not read the file: $e');
        return;
      }
      _inputPath = path;
      _clearOutput();
      _error = null;
      notifyListeners();
      await convert();
    } else {
      if (!const ['.md', '.markdown', '.txt'].contains(ext)) {
        _fail('Please choose a .md, .markdown or .txt file.');
        return;
      }
      try {
        _markdownInput = await File(path).readAsString();
      } catch (e) {
        _fail('Could not read the file as UTF-8 text.');
        return;
      }
      _markdownSourceDir = p.dirname(path);
      _clearOutput();
      _error = null;
      notifyListeners();
    }
  }

  /// Runs the conversion. For md2docx this validates the Markdown by building
  /// a temporary .docx and shows a result card.
  Future<void> convert() async {
    if (!canConvert) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (_mode == ConvertMode.docx2md) {
        await _pandoc.cleanup(); // drop images of the previous conversion
        final r = await _pandoc.docxToMdDetailed(_inputPath!);
        _output = r.markdown;
        _imageInfo = r.imageCount > 0
            ? '${r.imageCount} image${r.imageCount == 1 ? '' : 's'} '
                  'extracted to ${r.mediaDir}'
            : null;
        _converted = true;
      } else {
        final tmp = p.join(
          Directory.systemTemp.path,
          'docflip_check_${DateTime.now().microsecondsSinceEpoch}.docx',
        );
        try {
          await _pandoc.mdToDocx(
            _markdownInput,
            tmp,
            resourceDir: _markdownSourceDir,
          );
          _docxSize = await File(tmp).length();
          _converted = true;
        } finally {
          try {
            await File(tmp).delete();
          } catch (_) {}
        }
      }
    } on PandocException catch (e) {
      _fail(e.summary);
      return;
    } catch (e) {
      _fail('Unexpected error: $e');
      return;
    }
    _busy = false;
    notifyListeners();
  }

  /// Writes the .docx for the current Markdown directly to [outPath].
  Future<bool> saveDocx(String outPath) async {
    if (_mode != ConvertMode.md2docx || !hasInput) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _pandoc.mdToDocx(
        _markdownInput,
        outPath,
        resourceDir: _markdownSourceDir,
      );
      _docxSize = await File(outPath).length();
      _converted = true;
      _busy = false;
      notifyListeners();
      return true;
    } on PandocException catch (e) {
      _fail(e.summary);
    } catch (e) {
      _fail('Could not save the file: $e');
    }
    return false;
  }

  /// Writes the Markdown result to [outPath] (docx2md).
  Future<bool> saveMarkdown(String outPath) async {
    try {
      await File(outPath).writeAsString(_output);
      return true;
    } catch (e) {
      _fail('Could not save the file: $e');
      return false;
    }
  }

  /// Surfaces an error to the UI.
  void reportError(String message) => _fail(message);

  void _fail(String message) {
    _busy = false;
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _pandoc.cleanup();
    super.dispose();
  }
}
