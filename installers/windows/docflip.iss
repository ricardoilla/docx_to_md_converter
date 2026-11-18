; Inno Setup script for DocFlip.
; Build: iscc /DAppVersion=0.1.0 installers\windows\docflip.iss
; Run from the repo root after `flutter build windows --release`.
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

[Setup]
AppId={{6B0F3E0A-4C2D-4D8E-9B67-D0CF11A0F11A}
AppName=DocFlip
AppVersion={#AppVersion}
AppPublisher=DocFlip
DefaultDirName={autopf}\DocFlip
DefaultGroupName=DocFlip
UninstallDisplayIcon={app}\docflip.exe
OutputDir=..\..\dist
OutputBaseFilename=DocFlip-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; TODO (optional): code signing, e.g. SignTool=signtool

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; Flags: unchecked

[Files]
; Whole Release folder, including pandoc\pandoc.exe
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DocFlip"; Filename: "{app}\docflip.exe"
Name: "{group}\Uninstall DocFlip"; Filename: "{uninstallexe}"
Name: "{autodesktop}\DocFlip"; Filename: "{app}\docflip.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\docflip.exe"; Description: "Launch DocFlip"; Flags: nowait postinstall skipifsilent
