@echo off
chcp 65001 >nul
rem Lance le compagnon ForeverGazette à chaque ouverture de session Windows (en fond, sans fenêtre).
rem Journal : gazette_discord.log dans ce dossier. Pour annuler : retirer-demarrage.bat
setlocal
set "DIR=%~dp0"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
where pythonw >nul 2>nul || (echo Python introuvable : installe-le depuis python.org en cochant « Add Python to PATH ». & pause & exit /b 1)
if not exist "%DIR%gazette_discord.ini" (echo Copie d'abord gazette_discord.example.ini en gazette_discord.ini et remplis-le. & pause & exit /b 1)
python -c "import PIL" 2>nul || (echo Installation de Pillow pour le PDF et les images... & python -m pip install --user pillow)
echo @echo off> "%STARTUP%\ForeverGazette.bat"
echo cd /d "%DIR%">> "%STARTUP%\ForeverGazette.bat"
echo start "" pythonw "%DIR%gazette_discord.py" --watch --today --weekly --log "%DIR%gazette_discord.log">> "%STARTUP%\ForeverGazette.bat"
start "" pythonw "%DIR%gazette_discord.py" --watch --today --weekly --log "%DIR%gazette_discord.log"
echo Compagnon installé : il tourne maintenant et se relancera à chaque ouverture de session.
echo Journal : %DIR%gazette_discord.log
pause
