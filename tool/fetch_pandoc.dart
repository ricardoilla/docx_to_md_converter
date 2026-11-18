// Downloads the official pandoc release and lays it out for bundling.
//
//   dart run tool/fetch_pandoc.dart [--platform windows|macos]
//
// Output (all git-ignored):
//   third_party/pandoc/windows/pandoc.exe
//   third_party/pandoc/macos/pandoc        (universal arm64 + x86_64)
//   third_party/pandoc/COPYING.txt
import 'dart:io';

/// Pinned pandoc version.
const pandocVersion = '3.14';

const _base = 'https://github.com/jgm/pandoc/releases/download/$pandocVersion';

Future<void> main(List<String> args) async {
  var platform = Platform.isWindows ? 'windows' : 'macos';
  final i = args.indexOf('--platform');
  if (i >= 0 && i + 1 < args.length) platform = args[i + 1];
  if (platform != 'windows' && platform != 'macos') {
    stderr.writeln('--platform must be windows or macos');
    exit(64);
  }

  final root = Directory('third_party/pandoc')..createSync(recursive: true);
  final work = Directory.systemTemp.createTempSync('docflip_pandoc_');
  try {
    if (platform == 'windows') {
      await _windows(root, work);
    } else {
      await _macos(root, work);
    }
    await _download(
      'https://raw.githubusercontent.com/jgm/pandoc/$pandocVersion/COPYING.md',
      File('${root.path}/COPYING.txt'),
    );
    stdout.writeln('pandoc $pandocVersion ready in ${root.path}');
  } finally {
    work.deleteSync(recursive: true);
  }
}

Future<void> _windows(Directory root, Directory work) async {
  final zip = File('${work.path}/win.zip');
  await _download('$_base/pandoc-$pandocVersion-windows-x86_64.zip', zip);
  final out = Directory('${work.path}/win')..createSync();
  await _unzip(zip, out);
  final exe = out
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere((f) => f.path.endsWith('pandoc.exe'));
  final dest = File('${root.path}/windows/pandoc.exe')
    ..createSync(recursive: true);
  exe.copySync(dest.path);
}

Future<void> _macos(Directory root, Directory work) async {
  final bins = <String>[];
  for (final arch in ['arm64', 'x86_64']) {
    final zip = File('${work.path}/$arch.zip');
    await _download('$_base/pandoc-$pandocVersion-$arch-macOS.zip', zip);
    final out = Directory('${work.path}/$arch')..createSync();
    await _unzip(zip, out);
    bins.add(
      out
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('/bin/pandoc'))
          .path,
    );
  }
  final dest = File('${root.path}/macos/pandoc')..createSync(recursive: true);
  await _run('lipo', ['-create', ...bins, '-output', dest.path]);
  await _run('chmod', ['+x', dest.path]);
  // lipo invalidates signatures and arm64 binaries must be signed: ad-hoc.
  await _run('codesign', ['--force', '--sign', '-', dest.path]);
}

Future<void> _download(String url, File to) async {
  stdout.writeln('Downloading $url');
  final client = HttpClient();
  try {
    var req = await client.getUrl(Uri.parse(url));
    var res = await req.close(); // follows redirects by default
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    }
    await res.pipe(to.openWrite());
  } finally {
    client.close();
  }
}

Future<void> _unzip(File zip, Directory out) async {
  if (Platform.isWindows) {
    await _run('powershell', [
      '-NoProfile',
      '-Command',
      "Expand-Archive -Force -LiteralPath '${zip.path}' -DestinationPath '${out.path}'",
    ]);
  } else {
    await _run('unzip', ['-q', '-o', zip.path, '-d', out.path]);
  }
}

Future<void> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) {
    stderr.writeln(r.stderr);
    throw ProcessException(exe, args, '${r.stderr}', r.exitCode);
  }
}
