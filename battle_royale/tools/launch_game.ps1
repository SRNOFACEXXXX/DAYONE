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

Start-Process -FilePath $godotPath -ArgumentList @('--path', ('"' + $projectPath + '"'))
