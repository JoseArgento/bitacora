@echo off
rem Bitacora - copia tus ultimas capturas del juego (Screenshots) adonde Bitacora puede mostrarlas.
rem Para traer mas de 10:  "Traer capturas del juego.bat" -Cuantas 30
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Capturas.ps1" -Accion Traer %*
echo.
pause
