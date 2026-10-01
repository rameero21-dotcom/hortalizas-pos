; Instalador de Hortalizas POS para Windows (Inno Setup).
;
; Se compila en CI justo despues de "flutter build windows --release",
; empaquetando los binarios que quedan en build\windows\x64\runner\Release\.
; No depende de nada versionado en windows\ (esa carpeta no esta en el
; repo: se regenera en cada build con "flutter create").
;
; AppId fijo: instalar una version nueva sobre una vieja actualiza en
; el mismo lugar en vez de dejar dos instalaciones separadas - por eso
; "descargar el instalador de nuevo y darle doble clic" alcanza para
; actualizar.
#define MyAppName "Hortalizas POS"
#define MyAppExeName "hortalizas_pos.exe"
#define MyAppPublisher "C&S Hortalizas"

[Setup]
AppId={{8F2A1C4E-9B3D-4F6A-8C2E-1A5B7D9E3F01}
AppName={#MyAppName}
AppVersion=1.0.0
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=installer_output
OutputBaseFilename=hortalizas-pos-setup
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el Escritorio"; GroupDescription: "Accesos directos:"; Flags: checkedonce

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir Hortalizas POS"; Flags: nowait postinstall skipifsilent
