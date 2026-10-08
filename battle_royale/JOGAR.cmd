@echo off
setlocal
rem O PowerShell impede abrir duas instancias e traz a janela existente para frente.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_game.ps1"
endlocal
