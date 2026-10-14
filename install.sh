#!/usr/bin/env bash
# Installs the qlikview Agent Skill (user level) by symlinking (default) or copying skills/qlikview.
#   ./install.sh                      both: ~/.claude/skills (Claude Code) and ~/.agents/skills (Codex, Gemini CLI, Copilot, Cursor, ...)
#   ./install.sh --agent claude       only ~/.claude/skills
#   ./install.sh --agent agents       only ~/.agents/skills
#   ./install.sh --target DIR         any other tool's skills folder (the skill is installed as DIR/qlikview)
#   ./install.sh --copy               copy instead of symlink (combine with the options above)
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills/qlikview"
AGENT=all; COPY=0; TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --agent)  AGENT="$2"; shift 2 ;;
    --target) TARGETS+=("$2"); shift 2 ;;
    --copy)   COPY=1; shift ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
if [ ${#TARGETS[@]} -eq 0 ]; then
  case "$AGENT" in
    claude) TARGETS=("$HOME/.claude/skills") ;;
    agents) TARGETS=("$HOME/.agents/skills") ;;
    all)    TARGETS=("$HOME/.claude/skills" "$HOME/.agents/skills") ;;
    *) echo "--agent must be claude, agents or all" >&2; exit 2 ;;
  esac
fi
chmod +x "$SRC/qv-init.sh" "$SRC/toolkit/qvrun.sh" 2>/dev/null || true
for dir in "${TARGETS[@]}"; do
  DST="$dir/qlikview"; mkdir -p "$dir"
  if [ -L "$DST" ]; then rm "$DST"; elif [ -e "$DST" ]; then rm -rf "$DST"; fi
  if [ $COPY -eq 1 ]; then cp -r "$SRC" "$DST"; else ln -s "$SRC" "$DST"; fi
  echo "Installed: $DST"
done
echo "Start a new session in your agent, then ask for any QlikView task."
