; QuietTrack Inno Setup installer script
; Compile with Inno Setup 6+ (https://jrsoftware.org/isinfo.php)
;
; Before compiling:
;   1. Run: flutter build windows
;   2. Open this .iss file in Inno Setup Compiler
;   3. Click Build > Compile
;   4. Output: installer/Output/QuietTrack_Setup.exe

#define MyAppName "QuietTrack"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Anwo91"
#define MyAppURL "https://github.com/Anwo91/QuietTrack"
#define MyAppExeName "quiettrack.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B7E4F9A2-3C1D-4A8E-9F5B-6D2E1C0A7B3F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=QuietTrack_Setup_{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest
SetupIconFile=..\assets\icons\quiettrack.ico
LicenseFile=..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "Start QuietTrack with Windows"; GroupDescription: "Other:"; Flags: unchecked

[Files]
; Main executable + all DLLs and data from the Release folder
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Optional: start with Windows (only if user checked the box)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch QuietTrack"; Flags: nowait postinstall skipifsilent
