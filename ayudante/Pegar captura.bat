@echo off
rem Bitacora - guarda la imagen del portapapeles en la carpeta de imagenes (lo mismo que Ctrl+Alt+V).
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Capturas.ps1" -Accion Pegar %*
