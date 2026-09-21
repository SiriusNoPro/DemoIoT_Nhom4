@echo off
setlocal
set "IDF_TOOLS_PATH=C:\Espressif\tools"
call "C:\esp\v5.5.5\esp-idf\export.bat"
if errorlevel 1 exit /b %errorlevel%
cd /d "%~dp0"
python "%IDF_PATH%\tools\idf.py" -p COM3 build flash monitor
