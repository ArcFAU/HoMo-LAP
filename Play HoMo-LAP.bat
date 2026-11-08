@echo off
rem HoMo-LAP - plays the simulator from this folder.
rem Needs Python (any 3.x) and an internet connection (the 3D library loads from a CDN).
rem source\serve.py is a plain local web server that makes the browser load the newest files every time.
cd /d "%~dp0game"
echo HoMo-LAP running at http://localhost:8765  -  close this window to stop.
start "" cmd /c "timeout /t 2 /nobreak >/dev/null & start http://localhost:8765/index.html"
python "%~dp0source\serve.py" 8765 2>/dev/null && goto :eof
py "%~dp0source\serve.py" 8765 2>/dev/null && goto :eof
"%USERPROFILE%\anaconda3\python.exe" "%~dp0source\serve.py" 8765 && goto :eof
echo.
echo Could not start Python. Install Python, or play online (link in README.md).
pause
