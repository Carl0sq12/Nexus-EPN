@echo off
REM Uso: connect-phone.bat 192.168.100.11:34023
set ADB=C:\Users\Alisson.Munoz\Android\platform-tools\adb.exe
if "%~1"=="" (
  echo Uso: connect-phone.bat IP:PUERTO
  echo Ejemplo: connect-phone.bat 192.168.100.11:34023
  exit /b 1
)
"%ADB%" connect %~1
"%ADB%" devices -l
