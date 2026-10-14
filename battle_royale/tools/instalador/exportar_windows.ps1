# Gera build\DAYONE\ (export do Godot), build\DAYONE_Setup.exe (Inno Setup) e build\DAYONE_portatil.zip.
# Veja docs\INSTALADOR.md. Rodar a partir de battle_royale\tools\instalador.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$raiz = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\..'))   # repositório
$projeto = Join-Path $raiz 'battle_royale\game'
$build = Join-Path $raiz 'build'
$saida = Join-Path $build 'DAYONE'

$godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter 'Godot_v4.7.1-stable_win64_console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $godot) { throw 'Godot 4.7.1 não encontrado. Instale: winget install GodotEngine.GodotEngine' }

# export templates: sem eles o export falha com mensagem confusa
$tpl = Join-Path $env:APPDATA 'Godot\export_templates\4.7.1.stable'
if (-not (Test-Path (Join-Path $tpl 'windows_release_x86_64.exe'))) {
    throw "Export templates 4.7.1 ausentes em $tpl. No editor: Editor > Manage Export Templates > Download and Install."
}

New-Item -ItemType Directory -Force -Path $saida | Out-Null
Write-Host '== Exportando o jogo (Windows Desktop, release)'
& $godot.FullName --headless --path $projeto --export-release 'Windows Desktop' (Join-Path $saida 'DAYONE.exe')
if ($LASTEXITCODE -ne 0) { throw "Export falhou (código $LASTEXITCODE)" }
Copy-Item (Join-Path $here 'LEIA-ME.txt') $saida -Force

Write-Host '== Gerando o instalador (Inno Setup)'
$iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($iscc) {
    & $iscc (Join-Path $here 'dayone.iss')
    if ($LASTEXITCODE -ne 0) { throw "ISCC falhou (código $LASTEXITCODE)" }
    Write-Host "Instalador: $(Join-Path $build 'DAYONE_Setup.exe')"
} else {
    Write-Warning 'Inno Setup 6 não encontrado: instalador não gerado (o zip portátil sai mesmo assim).'
}

Write-Host '== Zip portátil'
$zip = Join-Path $build 'DAYONE_portatil.zip'
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$saida\*" -DestinationPath $zip
Write-Host "Pronto: $zip"
