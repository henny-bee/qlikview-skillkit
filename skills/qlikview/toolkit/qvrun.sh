#!/usr/bin/env bash
# Runs a QlikView COM PowerShell script from WSL (or Git Bash) with a timeout.
#   _build/tools/qvrun.sh <script.ps1> [ps-args...]        e.g.  qvrun.sh _build/tools/eval.ps1 -Expr 'Sum(Sales)'
# Env: QV_TIMEOUT (seconds, default 300). Paths are converted to Windows paths automatically.
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <script.ps1> [args...]" >&2; exit 2; }
script="$1"; shift
winpath() { if command -v wslpath >/dev/null 2>&1; then wslpath -w "$1"; elif command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }
exec timeout "${QV_TIMEOUT:-300}" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(winpath "$script")" "$@"
