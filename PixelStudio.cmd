@echo off
setlocal
set "PIXEL_STUDIO_EDITOR=%~dp0bin\godot.windows.editor.x86_64.exe"
if not exist "%PIXEL_STUDIO_EDITOR%" (
    echo Pixel Studio editor has not been built yet.
    echo See modules\pixel_studio\README.md for build instructions.
    pause
    exit /b 1
)
"%PIXEL_STUDIO_EDITOR%" --editor --path "%~dp0demo\pixel_studio"
