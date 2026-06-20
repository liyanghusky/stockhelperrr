@echo off
set "HERE=%~dp0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%HERE%start-stock-widget.ps1"
