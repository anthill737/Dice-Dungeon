
[Setup]
AppName=Dice Dungeon
AppVersion=1.0
DefaultDirName={autopf}\Dice Dungeon
DefaultGroupName=Dice Dungeon
OutputDir=installer_output
OutputBaseFilename=DiceDungeon_Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "DiceDungeon_Portable\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\Dice Dungeon"; Filename: "{app}\DiceDungeon.exe"
Name: "{commondesktop}\Dice Dungeon"; Filename: "{app}\DiceDungeon.exe"

[Run]
Filename: "{app}\DiceDungeon.exe"; Description: "Launch Dice Dungeon"; Flags: nowait postinstall skipifsilent
