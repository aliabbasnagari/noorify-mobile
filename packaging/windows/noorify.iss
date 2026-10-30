; Inno Setup script for the Noorify Windows installer.
; Built by .github/workflows/pipeline.yml:
;   ISCC /DAppVersion=1.2.3 /DOutputName=noorify-v1.2.3-windows-setup noorify.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef OutputName
  #define OutputName "noorify-windows-setup"
#endif

[Setup]
AppId={{B7C1E5A2-3D44-4F0B-9A5E-6F2C8D1E4A90}
AppName=Noorify
AppVersion={#AppVersion}
DefaultDirName={autopf}\Noorify
DefaultGroupName=Noorify
UninstallDisplayIcon={app}\noorify.exe
OutputDir=..\..
OutputBaseFilename={#OutputName}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Noorify"; Filename: "{app}\noorify.exe"
Name: "{autodesktop}\Noorify"; Filename: "{app}\noorify.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\noorify.exe"; Description: "Launch Noorify"; Flags: nowait postinstall skipifsilent
