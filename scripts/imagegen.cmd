@echo off
REM Windows wrapper for codex-imagegen — forwards all args to the bash script.
REM Requires Git Bash (C:\Program Files\Git\bin\bash.exe) or `bash` on PATH.

setlocal
set "SCRIPT_DIR=%~dp0"
set "BASH_EXE=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH_EXE%" set "BASH_EXE=bash"

"%BASH_EXE%" "%SCRIPT_DIR%imagegen.sh" %*
exit /b %ERRORLEVEL%
