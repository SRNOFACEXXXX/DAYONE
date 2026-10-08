$ErrorActionPreference = 'Stop'
$projectPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\game')).TrimEnd('\')
$godotPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe'

if (-not (Test-Path -LiteralPath $godotPath)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Godot 4.7.1 não foi encontrado.`n$godotPath", 'Ilha Brava') | Out-Null
    exit 1
}

$escapedProject = [Regex]::Escape($projectPath)
$running = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -like 'Godot*.exe' -and
    $_.CommandLine -match $escapedProject -and
    $_.CommandLine -notmatch 'res://' -and
    $_.CommandLine -notmatch '--headless|--quit-after|--script|--editor' -and
    (Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue).MainWindowHandle -ne 0 -and
    (Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue).Responding
} | Select-Object -First 1

if ($running) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class IlhaBravaWindow {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
'@
    $process = Get-Process -Id $running.ProcessId -ErrorAction SilentlyContinue
    if ($process -and $process.MainWindowHandle -ne 0) {
        [IlhaBravaWindow]::ShowWindowAsync($process.MainWindowHandle, 9) | Out-Null
        [IlhaBravaWindow]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
    }
    exit 0
}

# Clone novo: o cache de classes (class_name) e a importacao ficam em .godot/ (fora do Git). Sem isso o jogo abre em tela cinza
# com "Could not find type WeaponDef/UIStyle...". Importa uma vez, com janela de progresso, antes de abrir.
$cacheClasses = Join-Path $projectPath '.godot\global_script_class_cache.cfg'
if (-not (Test-Path -LiteralPath $cacheClasses)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Primeira execucao: o Godot vai importar o projeto (pode levar varios minutos). Uma janela vai abrir e fechar sozinha. Clique OK e aguarde.", 'DAYONE') | Out-Null
    Start-Process -FilePath $godotPath -ArgumentList @('--headless', '--editor', '--quit', '--path', ('"' + $projectPath + '"')) -Wait
}

Start-Process -FilePath $godotPath -ArgumentList @('--path', ('"' + $projectPath + '"'))
