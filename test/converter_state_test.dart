import 'dart:io' as io;
import 'package:docflip/models/convert_mode.dart';
import 'package:docflip/services/pandoc_service.dart';
import 'package:docflip/state/converter_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pandoc stand-in so state tests need no binary.
class FakePandoc extends PandocService {
  bool fail = false;

  @override
  Future<DocxToMdResult> docxToMdDetailed(String docxPath) async {
    if (fail) throw PandocException('boom', stderr: 'bad file');
    return const DocxToMdResult('# Hi');
  }

  @override
  Future<void> cleanup() async {}
}

void main() {
  late FakePandoc fake;
  late ConverterState state;
  setUp(() {
    fake = FakePandoc();
    state = ConverterState(pandoc: fake);
  });

  test('starts in docx2md with everything disabled', () {
    expect(state.mode, ConvertMode.docx2md);
    expect(state.canConvert, isFalse);
    expect(state.canCopy, isFalse);
    expect(state.canDownload, isFalse);
  });

  test('typing Markdown enables convert and download, never copy', () {
    state.swap();
    expect(state.mode, ConvertMode.md2docx);
    state.setMarkdown('# Title');
    expect(state.canConvert, isTrue);
    expect(state.canDownload, isTrue);
    expect(state.canCopy, isFalse);
  });

  test('swap resets the state and counts turns', () {
    state.swap();
    state.setMarkdown('text');
    state.swap();
    expect(state.mode, ConvertMode.docx2md);
    expect(state.markdownInput, isEmpty);
    expect(state.output, isEmpty);
    expect(state.swapCount, 2);
  });

  test('swap notifies the mode change callback', () {
    ConvertMode? seen;
    final s = ConverterState(pandoc: fake, onModeChanged: (m) => seen = m);
    s.swap();
    expect(seen, ConvertMode.md2docx);
  });

  test('rejects files with the wrong extension', () async {
    await state.loadFile('/tmp/notes.pdf');
    expect(state.error, isNotNull);
    expect(state.hasInput, isFalse);
  });

  test('pandoc errors are surfaced, not thrown', () async {
    fake.fail = true;
    await state.loadFile(_existingFile('x.docx'));
    expect(state.error, contains('boom'));
    expect(state.busy, isFalse);
    expect(state.canCopy, isFalse);
  });

  test('successful conversion enables copy and download', () async {
    await state.loadFile(_existingFile('ok.docx'));
    expect(state.output, '# Hi');
    expect(state.canCopy, isTrue);
    expect(state.canDownload, isTrue);
    expect(state.suggestedOutputName, 'docflip_state_ok.md');
    state.clear();
    expect(state.output, isEmpty);
  });
}

String _existingFile(String name) {
  final f = io.File('${io.Directory.systemTemp.path}/docflip_state_$name');
  f.writeAsBytesSync([0]);
  return f.path;
}
