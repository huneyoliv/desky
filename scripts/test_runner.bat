@echo off
title Desky Test Runner
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test_runner.ps1"
pause
