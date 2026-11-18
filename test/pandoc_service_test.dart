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

  test('docx -> md keeps structure', () async {
    final r = await svc.docxToMdDetailed(fixture('sample.docx'));
    expect(r.markdown, contains('# Título principal'));
    expect(r.markdown, contains('**negrita**'));
    expect(r.markdown, contains('[enlace](https://example.com/ruta)'));
    expect(r.markdown, contains('- Elemento uno'));
    expect(r.markdown, contains('|:---------|---------:|:------:|'));
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
    expect(back, contains('| Producto | Cantidad | Precio |'));
    expect(back, contains('|:---------|---------:|:------:|'));
  }, skip: skip);

  // The key requirement: original .docx -> .md -> .docx must stay as close to
  // the original as possible. Compared through pandoc's native AST.
  group('docx -> md -> docx round trip', () {
    final candidates = {
      'sample.docx': fixture('sample.docx'),
      // Put your own Word file at test/fixtures/ejemplo.docx to test it too.
      'ejemplo.docx': fixture('ejemplo.docx'),
    };
    candidates.forEach((name, path) {
      test(
        name,
        () async {
          final md = await svc.docxToMdDetailed(path);
          final out = p.join(tmp.path, 'roundtrip.docx');
          await svc.mdToDocx(md.markdown, out);
          final before = await canonicalAst(svc, path);
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
        },
        skip:
            skip ??
            (File(path).existsSync() ? null : 'fixture $name not present'),
      );
    });
  });
}
