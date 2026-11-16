@echo off
rem Bitacora - ayudante de capturas. Crea la carpeta de imagenes del juego, su lista y el atajo Ctrl+Alt+V.
rem Es texto: abrilo con el Bloc de notas para ver que hace. No usa la red ni pide permisos de administrador.
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Capturas.ps1" -Accion Instalar %*
echo.
pause
