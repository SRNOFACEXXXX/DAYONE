@echo off
rem // [LOCOMOTION-FIX v12]
cd /d "%~dp0dust_fps"
echo Kasbah: http://127.0.0.1:5180/
echo No navegador: Preparar jogo, aguardar e depois Jogar.
call npm run dev -- --configLoader native
pause
