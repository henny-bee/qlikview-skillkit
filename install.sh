#!/usr/bin/env bash
# Installs the QlikView skill for Claude Code (user level): ~/.claude/skills/qlikview
#   ./install.sh            symlink (updates when you git pull)
#   ./install.sh --copy     copy instead of symlink
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills/qlikview"
DST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/qlikview"
mkdir -p "$(dirname "$DST")"
if [ -e "$DST" ] || [ -L "$DST" ]; then
  echo "Replacing existing $DST"; rm -rf "$DST"
fi
if [ "${1:-}" = "--copy" ]; then cp -r "$SRC" "$DST"; else ln -s "$SRC" "$DST"; fi
chmod +x "$SRC/qv-init.sh" "$SRC/toolkit/qvrun.sh" 2>/dev/null || true
echo "Installed: $DST -> $SRC"
echo "Restart Claude Code (or start a new session), then ask for any QlikView task."
