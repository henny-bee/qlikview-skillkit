#!/usr/bin/env bash
# Bootstraps a QlikView project workspace: <project>/_build/{tools,script,spec,build,backup,logs,shots,status,qa}
# and copies the skill toolkit into _build/tools. Safe to re-run: it refreshes tools/, never touches your other files.
#   qv-init.sh <project-dir> [document.qvw]
#   e.g.  ~/.claude/skills/qlikview/qv-init.sh "/mnt/c/Users/me/projects/SalesApp" SalesApp.qvw
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <project-dir> [document.qvw]" >&2; exit 2; }
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$1" && pwd)"; DOC="${2:-}"
B="$PROJ/_build"
mkdir -p "$B"/{tools,script,spec,build,backup,logs,shots,status,qa}
cp -f "$SKILL_DIR"/toolkit/* "$B/tools/"
chmod +x "$B/tools/qvrun.sh"
# starter templates (never overwrite your own files)
for f in app-settings.ps1 build-SH_TEMPLATE.ps1 build-SH_INSIGHTS.ps1; do [ -f "$B/build/$f" ] || cp "$SKILL_DIR/templates/$f" "$B/build/$f"; done
for f in metrics.tsv groups.json; do [ -f "$B/spec/$f" ] || cp "$SKILL_DIR/templates/$f" "$B/spec/$f"; done
if [ -n "$DOC" ]; then
  if command -v wslpath >/dev/null 2>&1; then WIN="$(wslpath -w "$PROJ/$DOC")"; elif command -v cygpath >/dev/null 2>&1; then WIN="$(cygpath -w "$PROJ/$DOC")"; else WIN="$PROJ/$DOC"; fi
  printf '%s\n' "$WIN" > "$B/qv.config"
fi
[ -f "$B/.gitignore" ] || printf '.locks/\nbackup/\nlogs/\nshots/\nfinal-shots/\n*.qvw\n*.qvw.log\n' > "$B/.gitignore"
echo "QlikView workspace ready: $B"
[ -f "$B/qv.config" ] && echo "Target document: $(cat "$B/qv.config")" || echo "No document configured: the toolkit uses the active QlikView document (or set _build/qv.config)."
echo "Next: _build/tools/qvrun.sh _build/tools/eval.ps1 'Count(DISTINCT \$Field)'   (QlikView must be open with the doc)"
