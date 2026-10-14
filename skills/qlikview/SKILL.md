---
name: qlikview
description: Build, fix and automate QlikView Desktop (.qvw) apps. Use for any QlikView task, such as a load script, generating test or demo data, a data model with multiple fact tables or a link table, set analysis, measures or variables, KPIs, dashboards and sheets (D-A-R), charts, cyclic or drill groups, bookmarks, fixing wrong measures or "Error in expression", or reviewing a QlikView app. Drives QlikView 12 through COM from PowerShell (WSL or Windows) with a tested toolkit.
license: MIT
compatibility: Full use needs Windows with QlikView Desktop 12.x and an agent that can run Windows PowerShell 5.1 (natively or from WSL). Without that, the reference docs still help with load scripts, set analysis and data models.
metadata:
  version: "1.0"
---

# QlikView skill

You build and fix QlikView Desktop apps by driving the running QlikView through COM from PowerShell. Everything here was
learned while building a 1M-row, 7-sheet D-A-R sales app (`examples/sales-demo/`). Reuse it; do not rediscover it.

`<skill>` below means the folder that contains this file (e.g. `~/.claude/skills/qlikview` or `~/.agents/skills/qlikview`).

If you cannot run PowerShell on the Windows machine where QlikView runs (e.g. a web chat), still use this skill: write the
load script, expressions and build scripts from `reference/` and `examples/`, and tell the user which `toolkit/` commands to run.

## 1. Respond first, then plan, then build
1. **Answer immediately** from this skill: what you will build, the sheets and objects, the data model and the risks. Don't start with broad research.
2. **Write a short plan** (phases, files, sheets, checks, rough time) and **wait for approval** when the user asks for a plan or the task is big.
3. Only read `reference/*.md` and `examples/` for the specific detail you need.

## 2. Environment check (30 seconds)
* QlikView Desktop 12.x is at `C:\Program Files\QlikView\Qv.exe`. COM ProgID: `QlikTech.QlikView`.
* From WSL, run scripts with `_build/tools/qvrun.sh <script.ps1> [args]` (powershell.exe + wslpath + timeout).
* Is QlikView running with the doc? `Get-Process qv`. If not: `Start-QvDoc` (in `qvcom.ps1`) opens the configured doc.
  **Never close the user's QlikView or documents, and never open other documents in their instance.**
* Window size: design for a **1690 × 755** canvas, and do not resize the user's window. Screenshots need the window **not minimized**.

## 3. Bootstrap a project (once per app)
```bash
<skill>/qv-init.sh "<project-dir>" "<App>.qvw"        # Windows-native: qv-init.ps1 -Project <dir> -Document <App>.qvw
```
This creates `<project>/_build/` with `tools/` (toolkit), `script/`, `spec/` (metrics.tsv, groups.json), `build/`
(app-settings.ps1, build-SH_TEMPLATE.ps1), `backup/`, `logs/`, `shots/`, `status/`, `qa/` and `qv.config` (the doc path).

## 4. Workflow (the order that works)
| Step | Do | Tool |
|---|---|---|
| 1. Contract | Write `spec/data-contract.md`: tables, fields, measures/variables, groups, sheet IDs. Every later step binds to these names | `examples/sales-demo/spec/data-contract.md` |
| 2. Script | `script/<app>.qvs` with tabs Main/Config/Dimensions/Calendar/facts/LinkTable/Variables/Cleanup | `reference/script-patterns.md`, `examples/sales-demo/script/` |
| 3. Reload | Test reload with a small volume first, then the full one | `tools/reload.ps1 -Set @{vCfgRows='50000'}` |
| 4. Verify data | Row counts, totals, identities, no `$Syn` tables, the demo stories show, deterministic | `tools/verify.ps1 -Tsv spec/metrics.tsv` |
| 5. Groups and bookmarks | Cyclic/drill groups from JSON; story bookmarks | `tools/create-groups.ps1`, `examples/.../create-bookmarks.ps1` |
| 6. Sheets | One idempotent `build/build-SH_<TAG>.ps1` per sheet, Dashboard first | `templates/build-SH_TEMPLATE.ps1`, `toolkit/lib-*.ps1` |
| 7. Look | Screenshot every sheet and **look at it** (open the PNG as an image). Fix, rebuild, look again | `tools/shot.ps1 -Sheet SH_X` |
| 8. Gate | Error scan + screenshots + save. Then a human-eye pass with the checklist in `reference/layout-standard.md` | `tools/final-check.ps1` |

Checkpoint after each milestone: `Save-QvCheckpoint -Doc $doc -Label <name>` (copies the .qvw to `_build/backup/`).

## 5. Toolkit quick reference (`_build/tools/`)
* **qvcom.ps1**: `Get-QvApp`, `Get-QvDoc`, `Start-QvDoc`, `Enter-QvLock -Owner x` / `Exit-QvLock` / `Update-QvLock`,
  `Invoke-QvLocked`, `Invoke-QvRetry { }`, `Save-QvCheckpoint`, `Save-QvScreenshot -Path`.
* **lib-qv.ps1** (style `$QS`, colours `$QS.C`, glyphs `$QS.Glyph`): `Reset-QvSheet $doc 'SH_X' 'Name'`, `Enter-QvParking`/`Exit-QvParking`,
  `New-QvHeader` (band + nav + title + help, configured by `$QvAppInfo`/`$QvNav` in `build/app-settings.ps1`), `New-QvHelp`,
  `New-QvKpiTile`, `New-QvMiniKpi`, `New-QvText`, `New-QvButton -Actions @(@{Type='sheet';P=@('SH_X')})`,
  `New-QvChart $doc $sh Id <bar|line|combo|pie|scatter|grid|gauge|radar|mekko|funnel|block|pivot|straight> @(x,y,w,h) -Caption -Dims -Exprs`,
  `New-QvSlider`, `New-QvInputBox`, `New-QvContainer`, `Set-QvSheetOrder`, `Repair-QvCurSelWidths`,
  `Get-QvMoneyM`, `Get-QvGrowthText`, `Get-QvPpText`, `Set-QvNumFmt` kinds: money, moneyM, pct, pp, growth, int, dec1.
  Expression hashtable keys: `D L Fmt Mode Color ColorExpr TextColorExpr Right Values Relative NoTotal Repr Gauge Mini Cycle ColWidth NoAxis AxisMin AxisMax`.
  Dimension keys: `F` (field, `cyc_`/`drl_` group, or `=calc`), `L`, `Limit` (Top N variable), `SortExpr`, `SortDesc`, `NoNull`, `ColWidth`.
* **lib-ext.ps1**: `New-QvbFilterPanel $doc $sh $Tag` (current selections, period list boxes, multi box, search), `New-QvbListBox`,
  `New-QvbMultiBox`, `New-QvbCurSel`, `New-QvbSearch`, `Add-QvbRefLine`, `Set-QvbBlankNull`. **lib-eng.ps1**: calendar, statistics box,
  table box, container, bookmark object, line/arrow, `Set-EngPivotLayout`.
* **Scripts**: `reload.ps1`, `eval.ps1 '<expr>' ...`, `verify.ps1 -Tsv`, `create-groups.ps1 -Json`, `shot.ps1 -Sheet`, `final-check.ps1`.

## 6. Rules that prevent the known bugs (details: `reference/gotchas.md`)
* **Never** create a chart without a real data field in its dimension or expression: on big data it freezes QlikView.
* Build while the parking sheet is active; hold the COM lock per sheet (≤ 6 min); `ClearAll($true)` before releasing it if you selected anything.
* Chart titles go in `GraphLayout.WindowTitle` (the toolkit does it). Value labels are OFF unless needed. Shares use `Fmt='pct'`.
* Every title names its measure **and unit**; partial periods are labelled (YTD); a budget vs partial actuals uses **budget to date**.
* Tables: totals on top, `NoTotal` for sparkline, rate and light columns, explicit column widths, and no `-` in totals.
* One fixed colour per category value across all charts. Status lights must vary across rows.
* Line-level tables on big data get a calculation condition plus a friendly message.
* `.ps1` with non-ASCII must be UTF-8 **with BOM**. Use single quotes around `$(vX)` so PowerShell does not expand it.
* Before sending fix notes, check that the screenshot you reviewed is the **latest** (timestamp).

## 7. Measure problems: triage order
1. `eval.ps1 '$(vX)'` returns a value? If not, check the variable definition (`$doc.Variables('vX').GetContent().String`).
2. Compare with an independent formula written from the raw fields. Mismatch: fix the variable in the **script** too, or it is lost on the next reload.
3. Correct number but wrong on screen: it's a presentation problem (format, title, labels, totals, relative %), so see the gotchas.
4. Plausibility: period vs budget coverage, YTD vs full year, null keys at a coarser grain (budget), credit notes signed or unsigned.

## 8. Working as a team (optional, for big builds)
QlikView COM is single-threaded, so more than 3 builders mostly wait on the lock. A proven setup: **engineer** (script, data, variables,
groups, bookmarks, Reports/Help sheets), **1–2 designers** (sheets; one owns `lib-qv.ps1`), **QA** (read-only checks, logs issues
with owners, never changes the app), and **you as lead** (contract, decisions, screenshot review, final gate).
Give every agent the brief (`examples/sales-demo/TEAM-BRIEF.md` is a template), have each one write a `status/<name>.md` file,
mark sheets with `SHEET READY SH_x`, and require one build plus one fix pass per sheet. For small tasks, work alone.

## 9. Done means
`final-check.ps1` reports 0 errors on every sheet, you have looked at every screenshot, the checklist in
`reference/layout-standard.md` passes, `verify.ps1` totals reconcile, the document is saved, and a checkpoint exists.
Report what was built, the numbers, any accepted deviations, and the file paths.
