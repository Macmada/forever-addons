@echo off
chcp 65001 >nul
rem Retire le lancement automatique du compagnon ForeverGazette et l'arrête.
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ForeverGazette.bat" 2>nul
wmic process where "name='pythonw.exe' and commandline like '%%gazette_discord.py%%'" call terminate >nul 2>nul
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(pythonw?|pyw?)\.exe$' } | Where-Object { $_.CommandLine -like '*gazette_discord.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" 2>nul
echo Lancement automatique retiré, compagnon arrêté.
pause
