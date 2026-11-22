; The players' installer (server/client split plan step C2), built by tools/make_release.ps1 with Inno Setup in a container:
;   iscc dynasty.iss    next to build.iss (one line: #define Build "<N>") and a client\ folder holding the export
; Installs for the current user only, so no administrator prompt, and can run silently (/VERYSILENT) for a later updater.
#include "build.iss"
#ifndef Build
  #error build.iss must define Build
#endif

[Setup]
AppId={{6B0E5C1E-7D4A-4F55-9C1B-2D7A3E9F4C21}
AppName=Dynasty: A Life Well Lived
AppVersion=build {#Build}
AppPublisher=Dynasty
DefaultDirName={localappdata}\Programs\Dynasty
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=.
OutputBaseFilename=DynastySetup-{#Build}
Compression=lzma2
SolidCompression=yes
UninstallDisplayIcon={app}\Dynasty.exe
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: desktopicon; Description: "Make a desktop shortcut"

[Files]
Source: "client\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Dynasty"; Filename: "{app}\Dynasty.exe"
Name: "{autodesktop}\Dynasty"; Filename: "{app}\Dynasty.exe"; Tasks: desktopicon

[UninstallDelete]
; The game writes its crash reports and telemetry beside itself while it runs (src/shared/event_log.gd, src/client/crash_report.gd:
; res://crash_reports). The installer did not put them there, so Inno would leave the folder behind without this.
Type: filesandordirs; Name: "{app}\crash_reports"

[Run]
Filename: "{app}\Dynasty.exe"; Description: "Play Dynasty now"; Flags: nowait postinstall skipifsilent
