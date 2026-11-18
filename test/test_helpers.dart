import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:docflip/services/pandoc_service.dart';

/// True when a pandoc (PANDOC_PATH or PATH) can be run; integration tests
/// are skipped otherwise.
final bool pandocAvailable = () {
  try {
    final bin = Platform.environment['PANDOC_PATH'] ?? 'pandoc';
    return Process.runSync(bin, ['--version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}();

String fixture(String name) => p.absolute('test', 'fixtures', name);

/// Dumps a document as pandoc's native AST with volatile bits (image paths,
/// extracted media names) normalised, so two docx files can be compared.
Future<String> canonicalAst(PandocService svc, String docxPath) async {
  final r = await Process.run(svc.locateBinary(), [
    docxPath,
    '-t',
    'native',
    '--wrap=none',
  ]);
  if (r.exitCode != 0) throw StateError('pandoc failed: ${r.stderr}');
  return (r.stdout as String).replaceAllMapped(
    RegExp(r'"[^"]*?/?(media/)?[^"/]*\.(png|jpe?g|gif|emf|wmf)"'),
    (m) => '"<image>"',
  );
}
