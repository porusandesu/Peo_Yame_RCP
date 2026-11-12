#define BuildNumber GetEnv("PEO_YAME_BUILD_NUMBER")

[Setup]
AppId={{B1E4F192-76B2-4B5F-A5B8-CDB0EBC71DA4}
AppName=Peo Yame
AppVersion=1.0.{#BuildNumber}
AppPublisher=Peo Yame
DefaultDirName={localappdata}\Programs\Peo Yame
DefaultGroupName=Peo Yame
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\publish
OutputBaseFilename=Peo Yame v{#BuildNumber} Setup
SetupIconFile=assets\PeoYame.ico
UninstallDisplayIcon={app}\Peo Yame.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "..\publish\Peo Yame.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Peo Yame"; Filename: "{app}\Peo Yame.exe"
Name: "{autodesktop}\Peo Yame"; Filename: "{app}\Peo Yame.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\Peo Yame.exe"; Description: "Launch Peo Yame"; Flags: postinstall nowait skipifsilent
