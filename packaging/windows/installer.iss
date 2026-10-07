; Build from the same verified payload as the portable ZIP.
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
[Setup]
AppId={{A82FAE51-8DBC-4A5E-A951-0FEC42482B18}
AppName=BitChat Desktop
AppVersion={#ReleaseVersion}
AppVerName=BitChat Desktop {#ReleaseVersion}
AppPublisher=Youhana Sheriff
AppPublisherURL=https://github.com/youhanasheriff/bitchat-desktop
AppSupportURL=https://github.com/youhanasheriff/bitchat-desktop/issues
DefaultDirName={localappdata}\Programs\BitChat Desktop
DefaultGroupName=BitChat Desktop
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.19045
OutputDir={#OutputDir}
OutputBaseFilename=BitChat-Desktop-{#ReleaseVersion}-windows-x86_64-setup
VersionInfoVersion=0.1.0.2
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\bitchat-desktop-windows.exe
CloseApplications=yes
RestartApplications=no
LicenseFile={#SourceDir}\LICENSE.txt
SetupLogging=yes

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\BitChat Desktop"; Filename: "{app}\bitchat-desktop-windows.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\bitchat-desktop-windows.exe"; Description: "Open BitChat Desktop"; Flags: nowait postinstall skipifsilent
