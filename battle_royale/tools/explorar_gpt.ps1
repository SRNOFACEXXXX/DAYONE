$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\game'))
$godotPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotPath)) { throw 'Godot 4.7.1 não foi encontrado.' }
# The quoted absolute project path keeps the space in "teste GPT" intact.
Start-Process -FilePath $godotPath -ArgumentList @('--path', ('"'+$projectPath+'"'), 'res://maps/ilha/ilha.tscn', '--', '--start=-233,-353', '--yaw=-8')
