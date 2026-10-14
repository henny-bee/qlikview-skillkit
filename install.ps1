# Installs the QlikView skill for Claude Code on Windows (user level): %USERPROFILE%\.claude\skills\qlikview
#   powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'skills\qlikview'
$dst = Join-Path $env:USERPROFILE '.claude\skills\qlikview'
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
Copy-Item -Recurse $src $dst
"Installed: $dst"
"Restart Claude Code, then ask for any QlikView task."
