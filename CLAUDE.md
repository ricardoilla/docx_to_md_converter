# CLAUDE.md: DocFlip project instructions

## Goal
Build **DocFlip**, a cross-platform desktop app (Windows + macOS) that converts:
- `.docx` → Markdown
- Markdown → `.docx`

Public open-source repo, MIT license. Keep it simple, small and dependable.

## Stack (do not change without asking)
- **Flutter (stable channel), desktop only:** `windows` and `macos` targets. Do not create mobile or web targets.
- **Dart**, with null safety. State management uses plain `ChangeNotifier` + `ListenableBuilder` (no Riverpod/Bloc).
- **Conversion engine:** Pandoc, bundled with the app as a separate executable and called with `dart:io` `Process.run`.
- Packages (ask before adding others):
  - `file_selector` for open/save dialogs
  - `desktop_drop` for drag & drop
  - `shared_preferences` to remember the last mode
  - `path` and `path_provider` for temp dirs
  - `flutter_markdown` (optional) for the md→docx preview
  - Clipboard: use the built-in `Clipboard.setData` from `flutter/services.dart`

## UI spec
Single window, about 1100×700, min 800×500 (set this in the native runners). Material 3, with light and dark themes that follow the system.

```
┌──────────────────────────────────────────────────────────────┐
│  [ DOCX ]            [ ⇄ ]            [ Markdown ]           │  ← header: from-label, swap, to-label
├─────────────────────────┬───┬────────────────────────────────┤
│                         │   │                                │
│   INPUT PANEL (left)    │ → │   OUTPUT PANEL (right)         │
│                         │   │                                │
├─────────────────────────┴───┴────────────────────────────────┤
│ [Open file] [Clear]     [ Convert ]      [Copy] [Download]   │
└──────────────────────────────────────────────────────────────┘
```

- **Swap button (⇄)** in the center toggles the mode between `docx2md` and `md2docx`. It swaps the header labels (use `AnimatedSwitcher`) and resets both panels. Animate the arrow with a 180° rotation (`AnimatedRotation`).
- **Mode `docx2md`:**
  - Left panel: a drop zone ("Drop a .docx here or click to open"). Once a file is loaded, show its name, size and an ✕ to remove it.
  - Right panel: read-only monospace `SelectableText`/`TextField` with the Markdown result.
  - Buttons: **Copy** (with a SnackBar "Copied ✓") and **Download .md** (save dialog, default name = input name + `.md`).
- **Mode `md2docx`:**
  - Left panel: an editable monospace `TextField` (multiline, expands). It also accepts a dropped or opened `.md`/`.markdown`/`.txt` file.
  - Right panel: a rendered preview of the Markdown (`flutter_markdown`), or a simple result card after conversion.
  - Buttons: **Download .docx** only (hide Copy). This runs pandoc and writes directly to the chosen path.
- **Convert** is disabled until there is input. Show a progress indicator while it runs. Auto-convert when a file is dropped.
- Errors appear as a SnackBar or inline red message with pandoc's stderr summarized. The app must never crash on a bad file.
- Keyboard shortcuts (use `Shortcuts`/`Actions`; Ctrl on Windows, Cmd on macOS): O = open, Enter = convert, S = download, Shift+C = copy.
- Remember the last mode with `shared_preferences`.

## Code structure
```
lib/
  main.dart
  app.dart                  # MaterialApp, themes
  models/convert_mode.dart
  state/converter_state.dart  # ChangeNotifier: mode, input, output, busy, error
  services/pandoc_service.dart # locate binary + run conversions
  ui/home_page.dart
  ui/widgets/ (header_bar.dart, input_panel.dart, output_panel.dart, action_bar.dart, drop_zone.dart)
```

## PandocService
- **Locate the binary**, never assuming it is on PATH:
  - Windows: `<dir of Platform.resolvedExecutable>/pandoc/pandoc.exe`
  - macOS: `<App>.app/Contents/Resources/pandoc` (resolve from `Platform.resolvedExecutable`, which lives in `Contents/MacOS/`)
  - In debug mode, fall back to `PANDOC_PATH` env var, then to `pandoc` on PATH, so `flutter run` works for development
- `Future<String> docxToMd(String docxPath)`
  - `pandoc <path> -f docx -t gfm --wrap=none --extract-media=<tmpdir>`
  - Images: v1 keeps the references and shows "N images extracted to <folder>". Leave a TODO for an option to save them next to the .md.
- `Future<void> mdToDocx(String markdown, String outPath)`
  - Write the Markdown to a temp file (UTF-8), then `pandoc tmp.md -f gfm -t docx -o <outPath>`
  - Leave a TODO for an optional `--reference-doc` with custom styles.
- Run with `Process.run`, passing arguments as a list (no shell). Set a timeout of about 60 s. Throw a typed `PandocException` with stderr.
- Clean up temp files. Handle paths with spaces and non-ASCII characters (test with `Año_ñandú.docx`).

## Pandoc bundling
- `tool/fetch_pandoc.dart` (run with `dart run tool/fetch_pandoc.dart [--platform windows|macos]`): download the official pandoc release from GitHub releases. Pin a version constant in the script.
  - Windows: extract `pandoc.exe` to `third_party/pandoc/windows/pandoc.exe`
  - macOS: download both the arm64 and x86_64 zips and combine them into one universal binary with `lipo -create` → `third_party/pandoc/macos/pandoc`
  - Also copy pandoc's `COPYING` file to `third_party/pandoc/COPYING.txt`
- Add `third_party/pandoc/` to `.gitignore`. Never commit binaries.
- **Windows:** in `windows/CMakeLists.txt`, add an `install(...)` rule that copies `third_party/pandoc/windows/pandoc.exe` and `COPYING.txt` into `${INSTALL_BUNDLE_DATA_DIR}/../pandoc/`, so it ends up next to the exe in `build/windows/x64/runner/Release/pandoc/`.
- **macOS:** in the Xcode project (Runner target), add a "Run Script" build phase that copies `third_party/pandoc/macos/pandoc` and `COPYING.txt` into `Contents/Resources/` and makes the binary executable. If `CODE_SIGN_IDENTITY` is set, sign it with the same identity.
- **macOS sandbox:** disable the App Sandbox (`com.apple.security.app-sandbox = false`) in both `DebugProfile.entitlements` and `Release.entitlements`. The app is not distributed via the App Store, and the sandbox would block running pandoc and free file access. Keep the hardened runtime for future notarization.

## Installers
- **Windows:** Inno Setup script at `installers/windows/docflip.iss` that packages the whole `Release/` folder (including `pandoc/`) into `DocFlip-<version>-windows-x64-setup.exe`, with Start Menu and optional desktop shortcuts and an uninstaller.
- **macOS:** create a `.dmg` with `create-dmg` (npm) or `hdiutil`. The output is `DocFlip-<version>-macos-universal.dmg`.

## CI / Releases
- `.github/workflows/release.yml`, triggered on tags `v*`:
  - `windows-latest` job: set up Flutter, fetch pandoc, `flutter build windows --release`, install Inno Setup (choco), build the installer, and upload it.
  - `macos-latest` job: set up Flutter, fetch pandoc (universal), `flutter build macos --release`, build the dmg, and upload it.
  - Create a **draft** GitHub Release with both installers attached (`softprops/action-gh-release`).
  - Leave clearly marked, optional placeholders for macOS signing/notarization (`APPLE_CERTIFICATE`, `APPLE_ID`, `APPLE_TEAM_ID`, …) and Windows signing. Do not require them.
- `.github/workflows/ci.yml` runs on push/PR: `dart format --set-exit-if-changed .`, `flutter analyze`, and `flutter test`.

## Tests
- Unit tests for `ConverterState`: swap resets the state, buttons are enabled or disabled correctly, and errors are surfaced.
- Integration tests for `PandocService` with fixtures in `test/fixtures/`. They use a PATH pandoc and are skipped if none is found. The fixtures are a sample `.docx` with headings, a table, a list, a link, bold/italic and an image, plus a sample `.md`.
- Round-trip test: md → docx → md should preserve headings, lists and tables.
- Error test: a corrupt or renamed file throws `PandocException` instead of crashing.
- A widget test for the main layout and the swap animation state.

## Repo files to create
`README.md` (already provided, keep it updated), `LICENSE` (MIT), `CLAUDE.md`, `.gitignore`, `docs/screenshot.png` (placeholder), `CHANGELOG.md`, `.github/ISSUE_TEMPLATE/bug_report.md`.

## Working rules
- Work in small steps and commit after each milestone with clear messages.
- Milestones:
  1. `flutter create --platforms=windows,macos`, then the window size and the static UI layout
  2. State, swap logic and panel states
  3. Pandoc fetch script and PandocService, then docx→md working in `flutter run` with a PATH pandoc
  4. md→docx, save dialog and Markdown preview
  5. Copy, SnackBars, drag & drop, shortcuts and theming
  6. Bundling pandoc inside the Windows and macOS builds, and verifying a release build runs without pandoc on PATH
  7. Tests
  8. Installers and the CI/release workflows
- After each milestone, run `flutter analyze` and `flutter test` and fix all warnings. When possible, also run `flutter build macos` or `flutter build windows`.
- UI text is in English. Keep the code commented and readable.
- Do not implement auto-update, accounts, telemetry or network calls at runtime. The app must be 100% offline.
