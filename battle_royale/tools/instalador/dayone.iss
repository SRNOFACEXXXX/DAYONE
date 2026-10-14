; Instalador do DAYONE (Inno Setup 6). Compilar:  ISCC.exe dayone.iss   ->  build\DAYONE_Setup.exe
; Pré-requisito: exportar o jogo para build\DAYONE\ (Godot --export-release "Windows Desktop", ver docs/INSTALADOR.md)
#define Nome "DAYONE"
#define Versao "0.1.1"

[Setup]
AppId={{6B1E8F42-DA70-4E01-9C5E-DA7A0E000001}
AppName={#Nome}
AppVersion={#Versao}
AppPublisher=DAYONE
DefaultDirName={autopf}\{#Nome}
DefaultGroupName={#Nome}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\..\build
OutputBaseFilename=DAYONE_Setup
Compression=lzma2/fast
SolidCompression=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayIcon={app}\DAYONE.exe

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"; Flags: checkedonce

[Files]
Source: "..\..\..\build\DAYONE\DAYONE.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\build\DAYONE\DAYONE.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\build\DAYONE\LEIA-ME.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\DAYONE"; Filename: "{app}\DAYONE.exe"; Tasks: desktopicon
Name: "{autoprograms}\DAYONE"; Filename: "{app}\DAYONE.exe"

[Run]
Filename: "{app}\DAYONE.exe"; Description: "Jogar DAYONE agora"; Flags: nowait postinstall skipifsilent
