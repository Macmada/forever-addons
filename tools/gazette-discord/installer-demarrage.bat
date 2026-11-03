@echo off
chcp 65001 >nul
rem Lance le compagnon ForeverGazette à chaque ouverture de session Windows (en fond, sans fenêtre).
rem Journal : gazette_discord.log dans ce dossier. Pour annuler : retirer-demarrage.bat
setlocal
set "DIR=%~dp0"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
rem Python : le lanceur « py » / « pyw » d'abord (fonctionne avec le gestionnaire d'installation de Python et l'installateur
rem classique) ; « python » peut n'être qu'un raccourci vers le Microsoft Store.
set "PY=" & set "PYW="
py -c "import sys" >nul 2>nul && set "PY=py"
if defined PY (where pyw >nul 2>nul && set "PYW=pyw")
if not defined PY (python -c "import sys" >nul 2>nul && set "PY=python")
if not defined PYW (where pythonw >nul 2>nul && set "PYW=pythonw")
if not defined PY (echo Python introuvable : installe-le depuis python.org, puis relance ce fichier. & pause & exit /b 1)
if not defined PYW set "PYW=%PY%"
if not exist "%DIR%gazette_discord.ini" (echo Copie d'abord gazette_discord.example.ini en gazette_discord.ini et remplis-le. & pause & exit /b 1)
%PY% -c "import PIL" 2>nul || (echo Installation de Pillow pour le PDF et les images... & %PY% -m pip install --user pillow)
%PY% -c "import PIL" 2>nul || (echo Pillow ne s'est pas installé : lance « %PY% -m pip install pillow » dans un terminal, puis relance ce fichier. & pause & exit /b 1)
echo Python : %PY% / %PYW%, Pillow : ok
echo @echo off> "%STARTUP%\ForeverGazette.bat"
echo cd /d "%DIR%">> "%STARTUP%\ForeverGazette.bat"
echo start "" %PYW% "%DIR%gazette_discord.py" --watch --today --weekly --log "%DIR%gazette_discord.log">> "%STARTUP%\ForeverGazette.bat"
start "" %PYW% "%DIR%gazette_discord.py" --watch --today --weekly --log "%DIR%gazette_discord.log"
echo Compagnon installé : il tourne maintenant et se relancera à chaque ouverture de session.
echo Journal : %DIR%gazette_discord.log
pause
