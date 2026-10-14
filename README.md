# QlikView skill for Claude Code

A [Claude Code](https://docs.claude.com/en/docs/claude-code) skill and a PowerShell toolkit for **building, fixing and reviewing
QlikView Desktop apps**: load scripts, data models, measures, dashboards and sheets. Claude drives the running QlikView through COM.

Ask *"make a sales dashboard in QlikView"*, *"write a load script with invoices and credit notes"* or *"the margin measure looks wrong"*.
Claude answers with a plan right away and builds with tested code, instead of probing the QlikView API from scratch.

<img width="1695" height="770" alt="image" src="https://github.com/user-attachments/assets/fd6a90ae-cc6d-401a-aaee-6e921adc4b63" />


## What's inside
```
skills/qlikview/
├── SKILL.md                 # what Claude reads: workflow, rules, toolkit reference (loads automatically for QlikView tasks)
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

## Requirements
* Windows with **QlikView Desktop 12.x** (tested with 12.10 x64, Personal Edition works), installed at `C:\Program Files\QlikView\Qv.exe`
* **Claude Code**, running in **WSL** (recommended) or natively on Windows
* Windows PowerShell 5.1 (built into Windows)

## Install
WSL / Linux shell:
```bash
git clone <this-repo-url> qlikview-skill && cd qlikview-skill
./install.sh            # symlinks skills/qlikview -> ~/.claude/skills/qlikview  (use --copy to copy instead)
```
Windows (PowerShell):
```powershell
git clone <this-repo-url> qlikview-skill; cd qlikview-skill
powershell -ExecutionPolicy Bypass -File install.ps1     # copies to %USERPROFILE%\.claude\skills\qlikview
```
Start a new Claude Code session. The skill loads automatically when a task mentions QlikView, and you can check it with `/skills`.

## Quick start
1. Open (or create) your `.qvw` in QlikView Desktop and keep the window **not minimized**.
2. In Claude Code: *"Use the qlikview skill. Project folder C:\Projects\SalesApp, document SalesApp.qvw. Build a D-A-R sales dashboard from my data."*
3. Claude bootstraps the project, proposes a plan, and after your OK builds, screenshots and checks every sheet.

Manual use without Claude:
```bash
~/.claude/skills/qlikview/qv-init.sh /mnt/c/Projects/SalesApp SalesApp.qvw
cd /mnt/c/Projects/SalesApp
_build/tools/qvrun.sh _build/tools/eval.ps1 'Sum(Sales)' 'Count(DISTINCT CustomerID)'
_build/tools/qvrun.sh _build/tools/reload.ps1 -Script '_build\script\app.qvs'
_build/tools/qvrun.sh _build/build/build-SH_TEMPLATE.ps1        # after renaming the placeholder fields
_build/tools/qvrun.sh _build/tools/final-check.ps1             # error scan + screenshot of every sheet + save
```

## How it works
* PowerShell attaches to the running QlikView (`GetActiveObject('QlikTech.QlikView')`) and edits the document through the QlikView COM API.
* Scripts are **idempotent**: each sheet builder clears its sheet and recreates every object with fixed IDs, so you can re-run them freely.
* A file-based **COM lock** lets several Claude agents work on one document safely, one writer at a time.
* Every change is checked visually: screenshots via `PrintWindow`, which Claude reads as images.

## Safety notes
* The toolkit never closes QlikView or your documents and never opens other documents. If QlikView is not running, `Start-QvDoc` opens the configured one.
* Builders save checkpoints to `_build/backup/` (ignored by git). Keep your own backup of important `.qvw` files anyway.
* Avoid charts without a real data field: on large models they can freeze QlikView (see `reference/gotchas.md`).

## Contributing
Found a new QlikView quirk? Add it to `reference/gotchas.md` (symptom, cause, fix). Add reusable helpers to the toolkit, and keep
`toolkit/*.ps1` ASCII-only (or UTF-8 with BOM) for Windows PowerShell 5.1.

## License
[MIT](LICENSE). QlikView is a trademark of QlikTech International AB. This project is not affiliated with or endorsed by Qlik.
