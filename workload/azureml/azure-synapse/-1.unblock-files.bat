@echo off

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -Command "Get-ChildItem \"%~dp0.\" -Filter *.ps1 -Recurse | Unblock-File"

echo All .ps1 files unblocked

