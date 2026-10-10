@echo off
setlocal
rem Igual ao JOGAR.cmd, mas mostra as formas de colisao (--debug-collisions): tire capturas de onde o jogador atravessa algo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_game.ps1" -ExtraArgs "--debug-collisions"
endlocal
