import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown when pandoc cannot be found, fails, or times out.
class PandocException implements Exception {
  PandocException(this.message, {this.stderr = '', this.exitCode});

  /// Human readable description.
  final String message;

  /// Raw stderr produced by pandoc (may be empty).
  final String stderr;

  /// Exit code, if pandoc ran.
  final int? exitCode;

  /// Short text suitable for a SnackBar: message + first lines of stderr.
  String get summary {
    final lines = stderr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .join(' ');
    final text = lines.isEmpty ? message : '$message: $lines';
    return text.length > 300 ? '${text.substring(0, 300)}…' : text;
  }

  @override
  String toString() => 'PandocException($summary)';
}

/// Result of a DOCX → Markdown conversion.
class DocxToMdResult {
  const DocxToMdResult(this.markdown, {this.imageCount = 0, this.mediaDir});

  final String markdown;

  /// Number of images pandoc extracted.
  final int imageCount;

  /// Folder holding the extracted images (null when there are none).
  final String? mediaDir;
}

/// Locates the bundled pandoc binary and runs conversions with it.
///
/// Arguments are always passed as a list (never through a shell).
class PandocService {
  PandocService({
    this.timeout = const Duration(seconds: 60),
    Future<Directory> Function()? tempRoot,
  }) : _tempRoot = tempRoot ?? getTemporaryDirectory;

  final Duration timeout;

  /// Where temp folders are created (injectable for tests).
  final Future<Directory> Function() _tempRoot;

  /// Temp folders created by this service, removed by [cleanup].
  final List<Directory> _tempDirs = [];

  /// Markdown flavor used when writing. Pandoc's own Markdown is used because
  /// it can express what real Word files contain: pipe tables when simple and
  /// grid tables otherwise (multi-paragraph cells, lists in cells, merged
  /// cells), image sizes (`{width=.. height=..}`), underline and footnotes.
  /// GFM would fall back to raw HTML tables that cannot be turned back into
  /// Word tables, which lost whole tables in a DOCX -> MD -> DOCX round trip.
  static const _mdWriteFormat = 'markdown-implicit_figures';

  /// Reading also accepts common GitHub-style Markdown typed by the user.
  static const _mdReadFormat =
      'markdown-implicit_figures+autolink_bare_uris+task_lists';

  /// Lua filter applied when converting DOCX -> Markdown to fix things that
  /// do not survive the trip otherwise.
  static const _docxFilter = '''
-- 1) Word stores table alignment per cell; copy the first row alignment to
--    the columns (pandoc reads them as "default").
function Table(tbl)
  local row = tbl.head.rows[1]
  if not row and tbl.bodies[1] then row = tbl.bodies[1].body[1] end
  if not row then return nil end
  for i, cell in ipairs(row.cells) do
    local spec = tbl.colspecs[i]
    if spec and spec[1] == 'AlignDefault' then
      tbl.colspecs[i] = { cell.alignment, spec[2] }
    end
  end
  return tbl
end

-- 2) Nested links (table-of-contents page numbers) cannot be written in
--    Markdown: keep only the outer link.
function Link(link)
  link.content = link.content:walk({
    Link = function(inner) return inner.content end
  })
  return link
end

-- 3) Emphasis wrapping only line breaks/spaces would become "****": unwrap it.
local function blank(inlines)
  for _, el in ipairs(inlines) do
    if el.t ~= 'LineBreak' and el.t ~= 'Space' and el.t ~= 'SoftBreak' then
      return false
    end
  end
  return true
end
function Strong(el) if blank(el.content) then return el.content end end
function Emph(el) if blank(el.content) then return el.content end end
''';

  /// Finds the pandoc executable, never assuming it is on PATH in release.
  String locateBinary() {
    final exe = Platform.resolvedExecutable;
    String? bundled;
    if (Platform.isWindows) {
      bundled = p.join(p.dirname(exe), 'pandoc', 'pandoc.exe');
    } else if (Platform.isMacOS) {
      // exe lives in <App>.app/Contents/MacOS/
      bundled = p.join(p.dirname(p.dirname(exe)), 'Resources', 'pandoc');
    }
    if (bundled != null && File(bundled).existsSync()) return bundled;

    if (kDebugMode) {
      final env = Platform.environment['PANDOC_PATH'];
      if (env != null && env.isNotEmpty && File(env).existsSync()) return env;
      return 'pandoc'; // development fallback: PATH
    }
    throw PandocException('Bundled pandoc was not found at ${bundled ?? exe}');
  }

  /// Whether a usable pandoc can be found (used to skip integration tests).
  Future<bool> isAvailable() async {
    try {
      final r = await Process.run(locateBinary(), ['--version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Converts a .docx file to Markdown.
  Future<String> docxToMd(String docxPath) async =>
      (await docxToMdDetailed(docxPath)).markdown;

  /// Like [docxToMd] but also reports extracted images.
  Future<DocxToMdResult> docxToMdDetailed(String docxPath) async {
    final media = await _makeTempDir('docflip_media_');
    final filter = File(p.join(media.path, 'docx_to_md.lua'));
    await filter.writeAsString(_docxFilter);
    final out = await _run([
      docxPath,
      '-f',
      'docx',
      '-t',
      _mdWriteFormat,
      '--wrap=none',
      '--lua-filter=${filter.path}',
      '--extract-media=${media.path}',
    ]);
    // TODO: option to save extracted images next to the .md file.
    var count = 0;
    final mediaSub = Directory(p.join(media.path, 'media'));
    if (mediaSub.existsSync()) {
      count = mediaSub.listSync(recursive: true).whereType<File>().length;
    }
    return DocxToMdResult(
      out,
      imageCount: count,
      mediaDir: count > 0 ? mediaSub.path : null,
    );
  }

  /// Converts Markdown text to a .docx written directly to [outPath].
  ///
  /// [resourceDir] lets relative image paths in the Markdown resolve.
  Future<void> mdToDocx(
    String markdown,
    String outPath, {
    String? resourceDir,
  }) async {
    final tmp = await _makeTempDir('docflip_md_');
    try {
      final mdFile = File(p.join(tmp.path, 'input.md'));
      await mdFile.writeAsString(markdown, encoding: utf8);
      // TODO: optional --reference-doc=<file> to apply custom Word styles.
      await _run([
        mdFile.path,
        '-f',
        _mdReadFormat,
        '-t',
        'docx',
        if (resourceDir != null) '--resource-path=$resourceDir',
        '-o',
        outPath,
      ]);
    } finally {
      await _delete(tmp);
    }
  }

  /// Deletes every temp folder created so far (extracted images included).
  Future<void> cleanup() async {
    for (final d in List.of(_tempDirs)) {
      await _delete(d);
    }
  }

  Future<Directory> _makeTempDir(String prefix) async {
    final base = await _tempRoot();
    // The platform cache folder may not exist yet on a fresh install.
    await base.create(recursive: true);
    final dir = await base.createTemp(prefix);
    _tempDirs.add(dir);
    return dir;
  }

  Future<void> _delete(Directory d) async {
    _tempDirs.remove(d);
    try {
      if (d.existsSync()) await d.delete(recursive: true);
    } catch (_) {}
  }

  /// Runs pandoc, returning stdout. Kills the process on timeout.
  Future<String> _run(List<String> args) async {
    final binary = locateBinary();
    final Process proc;
    try {
      proc = await Process.start(binary, args);
    } on ProcessException catch (e) {
      throw PandocException('Could not start pandoc', stderr: e.message);
    }
    final stdoutF = proc.stdout.fold<List<int>>([], (a, b) => a..addAll(b));
    final stderrF = proc.stderr.fold<List<int>>([], (a, b) => a..addAll(b));
    final int code;
    try {
      code = await proc.exitCode.timeout(timeout);
    } on TimeoutException {
      proc.kill();
      throw PandocException('Conversion timed out after ${timeout.inSeconds}s');
    }
    final err = utf8.decode(await stderrF, allowMalformed: true);
    if (code != 0) {
      throw PandocException(
        'Pandoc failed (exit $code)',
        stderr: err,
        exitCode: code,
      );
    }
    return utf8.decode(await stdoutF, allowMalformed: true);
  }
}
