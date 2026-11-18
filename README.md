# DocFlip

**Convert Word (.docx) to Markdown and Markdown to Word. One window, two panels, one swap button.**

DocFlip is a small, free, open-source desktop app for Windows and macOS. Drop a `.docx` on the left and get clean Markdown on the right, or click the arrow to swap directions and turn Markdown into a Word document.

![screenshot](docs/screenshot.png)

## Features

- **DOCX → Markdown**: headings, bold/italic, lists, tables, links, code blocks and footnotes are kept
- **Faithful round trip**: DOCX → MD → DOCX keeps headings, lists, tables (with alignment), links, footnotes and images
- **Markdown → DOCX**: paste or open a `.md` file and download a ready-to-use Word document
- **Swap button (⇄)**: flip the direction with a single click
- **Copy to clipboard** for Markdown output
- **Download** the result as `.md` or `.docx`
- **Drag & drop** files onto the input panel
- **Works offline.** Your files never leave your computer
- Native installers for **Windows** (.exe) and **macOS** (.dmg, universal: Apple Silicon and Intel)

## Download

Get the latest installer from the [Releases](https://github.com/ricardoilla/docx_to_md_converter/releases/latest) page.

| Platform | File |
|---|---|
| Windows 10/11 (64-bit) | `DocFlip-x.y.z-windows-x64-setup.exe` |
| macOS 11+ (Apple Silicon & Intel) | `DocFlip-x.y.z-macos-universal.dmg` |

> **macOS note:** the app is not notarized yet. On first launch, right-click the app → **Open**, or run:
> `xattr -dr com.apple.quarantine /Applications/DocFlip.app`
>
> **Windows note:** SmartScreen may show a warning for unsigned apps. Click **More info → Run anyway**.

## How to use

1. Choose a direction. The default is **DOCX → MD**. Click **⇄** to switch to **MD → DOCX**.
2. Add your input:
   - DOCX → MD: drag a `.docx` onto the left panel or click **Open file**
   - MD → DOCX: paste Markdown into the left panel, or open a `.md` file
3. Click **Convert**.
4. Use **Copy** (Markdown only) or **Download**.

## Built with

- [Flutter](https://flutter.dev/) (Dart) for a native desktop app on Windows and macOS
- [Pandoc](https://pandoc.org/), bundled, as the conversion engine

## Development

Requirements: the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable) with desktop support enabled. On macOS you also need Xcode. On Windows you need Visual Studio 2022 with the "Desktop development with C++" workload.

```bash
git clone https://github.com/ricardoilla/docx_to_md_converter.git
cd docx_to_md_converter
flutter pub get
dart run tool/fetch_pandoc.dart   # downloads pandoc into third_party/pandoc/
flutter run -d macos              # or: flutter run -d windows
flutter build macos --release     # or: flutter build windows --release
```

Run the tests with `flutter test`. The round-trip test compares a `.docx` with the `.docx` obtained after DOCX → MD → DOCX; to try your own Word file, save it as `test/fixtures/ejemplo.docx` (git-ignored, so private documents are never committed).

During development you can also use a pandoc installed on your system (`brew install pandoc` / `winget install pandoc`).

Releases are built automatically by GitHub Actions when a `v*` tag is pushed:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Contributing

Issues and pull requests are welcome. For larger changes, please open an issue first so we can discuss the approach.

## License

DocFlip is released under the [MIT License](LICENSE).

The installers include an unmodified copy of [Pandoc](https://github.com/jgm/pandoc), which is licensed under the **GPL-2.0-or-later**. Pandoc runs as a separate program. Its license text is included in the app bundle (`COPYING.txt` next to the pandoc binary), and its source code is available at https://github.com/jgm/pandoc.
