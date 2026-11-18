import 'dart:io';

import 'package:docflip/services/pandoc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'test_helpers.dart';

void main() {
  final skip = pandocAvailable ? null : 'pandoc not found on PATH';
  late PandocService svc;
  late Directory tmp;

  setUp(() {
    svc = PandocService(tempRoot: () async => Directory.systemTemp);
    tmp = Directory.systemTemp.createTempSync('docflip_test_');
  });
  tearDown(() async {
    await svc.cleanup();
    tmp.deleteSync(recursive: true);
  });

  test('works when the temp root folder does not exist yet', () async {
    final missing = Directory('${tmp.path}/not/created/yet');
    final fresh = PandocService(tempRoot: () async => missing);
    expect(await fresh.docxToMd(fixture('sample.docx')), contains('Título'));
    await fresh.cleanup();
  }, skip: skip);

  test('docx -> md keeps structure', () async {
    final r = await svc.docxToMdDetailed(fixture('sample.docx'));
    expect(r.markdown, contains('# Título principal'));
    expect(r.markdown, contains('**negrita**'));
    expect(r.markdown, contains('[enlace](https://example.com/ruta)'));
    expect(r.markdown, contains('- Elemento uno'));
    expect(r.markdown, contains('[^1]'));
    expect(r.imageCount, 1);
  }, skip: skip);

  test('paths with spaces and non-ASCII characters work', () async {
    final src = File(fixture('Año_ñandú.docx'));
    final dir = Directory(p.join(tmp.path, 'carpeta con espacios'))
      ..createSync();
    final copy = src.copySync(p.join(dir.path, 'Año ñandú.docx'));
    expect(await svc.docxToMd(copy.path), contains('Título principal'));
    final out = p.join(dir.path, 'salida ñ.docx');
    await svc.mdToDocx('# Hola ñandú', out);
    expect(File(out).existsSync(), isTrue);
  }, skip: skip);

  test('corrupt or renamed file throws PandocException', () async {
    final bad = File(p.join(tmp.path, 'bad.docx'))
      ..writeAsStringSync('this is not a zip');
    expect(() => svc.docxToMd(bad.path), throwsA(isA<PandocException>()));
    expect(
      () => svc.docxToMd(p.join(tmp.path, 'missing.docx')),
      throwsA(isA<PandocException>()),
    );
  }, skip: skip);

  test('md -> docx -> md preserves headings, lists and tables', () async {
    final md = File(fixture('sample.md')).readAsStringSync();
    final out = p.join(tmp.path, 'out.docx');
    await svc.mdToDocx(md, out, resourceDir: p.dirname(fixture('sample.md')));
    final back = await svc.docxToMd(out);
    expect(back, contains('# Título principal'));
    expect(back, contains('## Listas'));
    expect(back, contains('- Elemento uno'));
    expect(back, contains('1.  Primero'));
    expect(back, contains('Producto'));
  }, skip: skip);

  // Key requirement: original .docx -> .md -> .docx must stay as close to the
  // original as possible. Compared through pandoc's native AST.
  Future<String> roundTrip(String path) async {
    final md = await svc.docxToMdDetailed(path);
    final out = p.join(tmp.path, 'roundtrip.docx');
    await svc.mdToDocx(md.markdown, out);
    return out;
  }

  test('round trip: sample.docx stays identical', () async {
    final out = await roundTrip(fixture('sample.docx'));
    final before = await canonicalAst(svc, fixture('sample.docx'));
    final after = await canonicalAst(svc, out);
    if (before != after) {
      File(p.join(tmp.path, 'before.native')).writeAsStringSync(before);
      File(p.join(tmp.path, 'after.native')).writeAsStringSync(after);
      final diff = await Process.run('diff', [
        '-u',
        p.join(tmp.path, 'before.native'),
        p.join(tmp.path, 'after.native'),
      ]);
      fail('Round trip changed the document:\n${diff.stdout}');
    }
  }, skip: skip);

  // Real-world Word file (put yours at test/fixtures/ejemplo.docx). Exact AST
  // equality is not expected: table-of-contents page-number links, relative
  // column widths and fully empty tables cannot be written in Markdown. The
  // content must be intact: same text, headings, lists and (almost) tables.
  test(
    'round trip: ejemplo.docx keeps text, headings, lists, tables',
    () async {
      final path = fixture('ejemplo.docx');
      final out = await roundTrip(path);
      final before = await canonicalAst(svc, path);
      final after = await canonicalAst(svc, out);

      String text(String f) =>
          Process.runSync(svc.locateBinary(), [
                f,
                '-t',
                'plain',
                '--wrap=none',
                '--columns=100000',
              ]).stdout
              .toString()
              .split('\n')
              .where((l) => !RegExp(r'^[\s+|=:-]*$').hasMatch(l))
              .join(' ')
              .replaceAll(RegExp(r'[|+=-]'), '')
              .replaceAll(RegExp(r'\s+'), ' ');
      expect(text(out), text(path), reason: 'text content changed');

      for (final node in [
        'Header ',
        'BulletList',
        'OrderedList',
        'CodeBlock',
      ]) {
        expect(countNodes(after, node), countNodes(before, node), reason: node);
      }
      final tablesBefore = countNodes(
        before,
        RegExp(r'^, Table', multiLine: true),
      );
      final tablesAfter = countNodes(
        after,
        RegExp(r'^, Table', multiLine: true),
      );
      expect(
        tablesAfter,
        greaterThanOrEqualTo(tablesBefore - 1),
        reason: 'tables were lost',
      );
    },
    skip:
        skip ??
        (File(fixture('ejemplo.docx')).existsSync()
            ? null
            : 'fixture ejemplo.docx not present'),
  );
}
