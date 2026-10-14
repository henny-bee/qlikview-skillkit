# QlikView Agent Skill

An [Agent Skill](https://agentskills.io) plus a PowerShell toolkit for **building, fixing and reviewing QlikView Desktop apps**:
load scripts, data models, measures, dashboards and sheets. The agent drives the running QlikView through COM.

It follows the open **Agent Skills** format (`SKILL.md`), so it works with any compatible AI agent:
Claude Code, OpenAI Codex, Gemini CLI, GitHub Copilot / VS Code, Cursor, OpenCode, Goose and more
(see the [client list](https://agentskills.io/clients)).

Ask *"make a sales dashboard in QlikView"*, *"write a load script with invoices and credit notes"* or *"the margin measure looks wrong"*.
The agent answers with a plan right away and builds with tested code, instead of probing the QlikView API from scratch.

<img width="1695" height="770" alt="image" src="https://github.com/user-attachments/assets/fd6a90ae-cc6d-401a-aaee-6e921adc4b63" />


## What's inside
```
skills/qlikview/
├── SKILL.md                 # what the agent reads: workflow, rules, toolkit reference (loads automatically for QlikView tasks)
├── qv-init.sh / .ps1        # bootstrap a project: <project>/_build/{tools,script,spec,build,backup,logs,shots,...}
├── toolkit/                 # copied into each project's _build/tools
│   ├── qvcom.ps1            #   connect, start doc, COM write lock, retry, checkpoint, screenshot
│   ├── lib-qv.ps1           #   sheet builder: header/nav, KPI tiles, all chart types, gauges, tables, buttons, help boxes
│   ├── lib-ext.ps1          #   filter panel, list/multi box, current selections, search, reference lines
│   ├── lib-eng.ps1          #   calendar, statistics box, table box, container, bookmark object, line/arrow, pivot layout
│   ├── reload.ps1 eval.ps1 verify.ps1 create-groups.ps1 shot.ps1 final-check.ps1
│   └── qvrun.sh             #   run any .ps1 from WSL / Git Bash with a timeout
├── templates/               # starter build script, app settings, metrics.tsv, groups.json
├── reference/
│   ├── com-cheatsheet.md    # COM methods + property paths (captions, formats, totals, widths, colours, groups, bookmarks)
│   ├── gotchas.md           # every bug that cost time, with cause and fix
│   ├── script-patterns.md   # deterministic test data, link table, master calendar, set-analysis variable templates
│   └── layout-standard.md   # D-A-R layout, grid, palette, zero-defect checklist
└── examples/sales-demo/     # complete reference app: 1M-row generated load script, 7 sheet builders, specs, QA checks, screenshots
```

## Which tools can use it
| Mode | Where | What works |
|---|---|---|
| **Full** | An agent that runs **on the Windows machine with QlikView** and can execute shell commands: Claude Code, Codex CLI, Gemini CLI, Copilot agent mode in VS Code, Cursor, OpenCode, … (natively on Windows or in WSL) | Everything: reload scripts, build sheets, check measures, take screenshots, run the final check |
| **Knowledge only** | Chat apps without access to your machine (e.g. Claude.ai or ChatGPT with an uploaded skill) | Load scripts, set analysis, data models, measure fixes and ready-to-run build scripts. You run the `toolkit/` commands yourself |

Screenshot review works best with agents that can view images (most can open a PNG file).

## Requirements (full mode)
* Windows with **QlikView Desktop 12.x** (tested with 12.10 x64, Personal Edition works), installed at `C:\Program Files\QlikView\Qv.exe`
* An Agent Skills compatible agent with shell access, running natively on Windows or in **WSL**
* Windows PowerShell 5.1 (built into Windows)

## Install
Each agent reads skills from its own folder. The shared folder **`~/.agents/skills`** is read by Codex, Gemini CLI, GitHub Copilot
and Cursor; Claude Code reads **`~/.claude/skills`**. By default the installers put the skill in both.

WSL / Linux / macOS shell (symlinks, so `git pull` updates the skill):
```bash
git clone https://github.com/henny-bee/qlikview-skillkit.git && cd qlikview-skillkit
./install.sh                         # ~/.claude/skills/qlikview + ~/.agents/skills/qlikview
./install.sh --agent claude          # only Claude Code       (--agent agents: only the shared folder)
./install.sh --target <skills-dir>   # any other tool's skills folder;  add --copy to copy instead of symlink
```
Windows (PowerShell):
```powershell
git clone https://github.com/henny-bee/qlikview-skillkit.git; cd qlikview-skillkit
powershell -ExecutionPolicy Bypass -File install.ps1 -Link          # both folders under %USERPROFILE%, as junctions
powershell -ExecutionPolicy Bypass -File install.ps1 -Agent claude  # only Claude Code; -Target <dir> for other tools; omit -Link to copy
```

| Agent | User-level skills folder | Docs |
|---|---|---|
| Claude Code | `~/.claude/skills/` | [docs](https://code.claude.com/docs/en/skills) |
| OpenAI Codex | `~/.agents/skills/` | [docs](https://developers.openai.com/codex/skills/) |
| Gemini CLI | `~/.gemini/skills/` or `~/.agents/skills/` | [docs](https://geminicli.com/docs/cli/skills/) |
| GitHub Copilot (VS Code, CLI) | `~/.copilot/skills/` or `~/.agents/skills/` | [docs](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) |
| Cursor | `~/.cursor/skills/` or `~/.agents/skills/` (also reads `~/.claude/skills/`) | [docs](https://cursor.com/docs/context/skills) |
| Other agents | see the [client list](https://agentskills.io/clients) | |
| Claude.ai / chat apps | upload `skills/qlikview` as a ZIP in the app's skills settings (knowledge-only mode) | [docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) |

For a single project, you can instead copy `skills/qlikview` into the repo's `.agents/skills/` (or `.claude/skills/`, `.github/skills/`).
Start a new agent session after installing. The skill loads automatically when a task mentions QlikView.

## Quick start
1. Open (or create) your `.qvw` in QlikView Desktop and keep the window **not minimized**.
2. Ask your agent: *"Use the qlikview skill. Project folder C:\Projects\SalesApp, document SalesApp.qvw. Build a D-A-R sales dashboard from my data."*
3. The agent bootstraps the project, proposes a plan, and after your OK builds, screenshots and checks every sheet.

Manual use (no agent needed):
```bash
~/.agents/skills/qlikview/qv-init.sh /mnt/c/Projects/SalesApp SalesApp.qvw     # or ~/.claude/skills/qlikview/...
cd /mnt/c/Projects/SalesApp
_build/tools/qvrun.sh _build/tools/eval.ps1 'Sum(Sales)' 'Count(DISTINCT CustomerID)'
_build/tools/qvrun.sh _build/tools/reload.ps1 -Script '_build\script\app.qvs'
_build/tools/qvrun.sh _build/build/build-SH_TEMPLATE.ps1        # after renaming the placeholder fields
_build/tools/qvrun.sh _build/tools/final-check.ps1             # error scan + screenshot of every sheet + save
```
On Windows without WSL: `powershell -ExecutionPolicy Bypass -File <skill>\qv-init.ps1 -Project C:\Projects\SalesApp -Document SalesApp.qvw`,
then run the `_build\tools\*.ps1` scripts with `powershell -ExecutionPolicy Bypass -File`.

## How it works
* PowerShell attaches to the running QlikView (`GetActiveObject('QlikTech.QlikView')`) and edits the document through the QlikView COM API.
* Scripts are **idempotent**: each sheet builder clears its sheet and recreates every object with fixed IDs, so you can re-run them freely.
* A file-based **COM lock** lets several agents (or agent + human scripts) work on one document safely, one writer at a time.
* Every change is checked visually: screenshots via `PrintWindow`, which the agent opens as images.

## Safety notes
* The toolkit never closes QlikView or your documents and never opens other documents. If QlikView is not running, `Start-QvDoc` opens the configured one.
* Builders save checkpoints to `_build/backup/` (ignored by git). Keep your own backup of important `.qvw` files anyway.
* Avoid charts without a real data field: on large models they can freeze QlikView (see `reference/gotchas.md`).

## Contributing
Found a new QlikView quirk? Add it to `reference/gotchas.md` (symptom, cause, fix). Add reusable helpers to the toolkit, and keep
`toolkit/*.ps1` ASCII-only (or UTF-8 with BOM) for Windows PowerShell 5.1. Keep `SKILL.md` within the
[Agent Skills specification](https://agentskills.io/specification) (name = folder name, description ≤ 1024 characters, body < 500 lines).

## License
[MIT](LICENSE). QlikView is a trademark of QlikTech International AB. This project is not affiliated with or endorsed by Qlik.
Agent Skills is an open format originally developed by Anthropic.
