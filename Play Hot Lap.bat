@echo off
rem Hot Lap - plays the game from this folder.
rem Needs Python (any 3.x) and an internet connection (the 3D library loads from a CDN).
cd /d "%~dp0game"
echo Hot Lap running at http://localhost:8765  -  close this window to stop.
start "" cmd /c "timeout /t 2 /nobreak >nul & start http://localhost:8765/index.html"
python -m http.server 8765 2>nul && goto :eof
py -m http.server 8765 2>nul && goto :eof
"%USERPROFILE%\anaconda3\python.exe" -m http.server 8765 && goto :eof
echo.
echo Could not start Python. Install Python, or play online (link in README.md).
pause
