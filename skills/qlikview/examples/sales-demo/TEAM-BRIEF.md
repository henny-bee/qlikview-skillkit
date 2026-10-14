# QLIK-CL Build Team — Brief (owned by Lead / Orchestrator `team-lead`)

## Goal
Turn the empty `<project>\QLIK-CL.qvw` into a polished **QlikView sales demo app**:
* A load script that generates sales data with **multiple fact tables** (invoices, credit notes, budget) and **1,000,000 transactional records**, modelled with a link table.
* An attractive layout that follows **D-A-R** (Dashboard → Analysis → Reporting) and uses a **wide range of QlikView objects**.
  Use **labels**, **small explanation boxes** and **cyclic/drill groups** wherever they help.
* QA has validated it for function, data accuracy, performance and UI consistency.

Binding interface: **spec/data-contract.md** (tables, fields, variables, groups, sheet IDs). Read it first.

## Environment (important)
* We run in WSL. QlikView Desktop **12.10 (x64 Personal Edition)** runs on Windows, and the user has the doc **open in the GUI**.
  We control it via **COM** from PowerShell: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\...\script.ps1'`
  (convert paths with `wslpath -w`). Put your work in `.ps1` files under your own folder rather than one-liners, so the work is repeatable.
* Dot-source the shared helper: `. "$PSScriptRoot\..\tools\qvcom.ps1"`
  It provides `Get-QvApp`, `Get-QvDoc`, `Enter-QvLock`/`Exit-QvLock`/`Update-QvLock`, `Invoke-QvLocked`, `Invoke-QvRetry`,
  `Save-QvCheckpoint -Doc $doc -Label x` and `Save-QvScreenshot -Path x.png`. Look at a screenshot with the Read tool: it shows images.
* PowerShell + QlikView COM quirk: properties are called as methods (`$qv.ActiveDocument()`, `$doc.GetSheet(0).GetProperties().Name`).
  Load script: `$p=$doc.GetProperties(); $p.Script = $text; $doc.SetProperties($p)`. Reload: `$doc.DoReload(2,$false,$false)` or `$doc.Reload()`.
  Evaluate: `$doc.Evaluate("Sum(NetSales)")`. Sheet create: `$doc.CreateSheet()`, plus all the `Sheet.Create*` methods
  (`CreateBarChart`, `CreateGaugeChart`, `CreatePivotTable`, `CreateTextObject`, `CreateContainer`, `CreateSlider`, `CreateInputBox`, `CreateMultiBox`,
  `CreateStatisticsBox`, `CreateSearchObject`, `CreateBookmarkObject`, `CreateObjectFromXmlPropertiesFile`, …). Discover members with `| Get-Member`.
* **Do not open other documents** in the user's QlikView instance and **do not close the doc or QlikView**.
  If you need a scratch area, create a sheet named `ZZ_<you>_Sandbox` and delete it when you are done.
* `.ps1` files containing non-ASCII text (€, –, ·) must be **UTF-8 with BOM**. Text files you load (the .qvs script) should be read with `-Encoding UTF8`.
* The user's QlikView window is 1723×928 px, which leaves a visible sheet canvas of about **1700 × 760 px** at 100% zoom.
  Design for **1690 × 755** so every sheet fits **without scrolling** in the user's window and in `Save-QvScreenshot` captures.
  Do not resize or maximize the user's window.

## COM write lock (mandatory)
QlikView is single-threaded. Hold the lock (`Enter-QvLock -Owner <you>` … `Exit-QvLock -Owner <you>`, or `Invoke-QvLocked`) for
**every** script change, reload, object/sheet/group/variable create or modify, selection change, or save. Hold it per step,
for minutes and never hours, and call `Update-QvLock` during long batches. Short read-only calls (Evaluate, GetProperties) don't need the lock,
but wrap them in `Invoke-QvRetry`, because QlikView may be busy reloading. **Always clear selections (`$doc.ClearAll($true)`) before you release the lock**
if you made any selections. Save with `Save-QvCheckpoint` at each milestone. Checkpoints go to `_build\backup\`.

### Lessons learned (incident 15:38: QlikView hung for 10 minutes and had to be force-restarted)
* Never create charts whose dimensions or expressions reference **no data field** (e.g. field-less `ValueLoop`/`ValueList` test charts). On 1M rows they freeze QlikView.
* Run every COM script from bash with `timeout 180 powershell.exe ...`. If QlikView stops responding, **message team-lead right away**.
  Never kill or restart QlikView yourself. The lock records `pid=` and automatically breaks if the holder process is dead.
* Checkpoint (`Save-QvCheckpoint`) after every successful milestone, so a restart never loses work.

## Folders and ownership. Edit only your own folders; message the owner for anything else.
| Path | Owner |
|---|---|
| `TEAM-BRIEF.md`, `spec/data-contract.md`, `tools/` | Lead |
| `script/QLIK-CL.qvs` (load script, source of truth), `engineer/`, `spec/variables.md`, `spec/data-stories.md`, `spec/data-model.md` | Engineer |
| `designer/`, `spec/layout-spec.md`, `spec/style-guide.md` | Designer |
| `qa/` (test plan, check scripts, `qa/issues.md`, screenshots) | QA |
| `status/<you>.md` | each agent keeps its own status file current (phase, done, next, blockers) |

Inside the .qvw: the Engineer owns the script, variables, groups and bookmarks. The Designer owns sheets, sheet objects, layout and UI variables (`vUI_*`).
**QA never changes the app.** QA reports problems, and the owner fixes them.

## Workflow (phases and dependencies)
```
P0 Lead      : contract + brief + helper                               [done]
P1 parallel  : Engineer  E1 script → reload → verify → groups → variables.md → message "DATA READY"
               Designer  D1 layout-spec + style-guide + reusable builder lib (no app writes needed, sandbox sheet OK)
               QA        Q1 test plan + automated check scripts (data, expressions, UI, performance)
P2 pipeline  : on DATA READY → QA runs the data checks while the Designer builds sheet by sheet (SH_DASH first).
               After each sheet the Designer messages QA ("SHEET READY SH_x") and QA reviews it while the Designer builds the next one.
               Engineer: fixes data issues from QA, then builds bookmarks for the demo stories, then supports the Designer
               (the Designer may hand a whole sheet to the Engineer, e.g. SH_REPORT, using the Designer's style lib).
P3 QA loop   : QA logs issues in qa/issues.md (ID, severity Blocker/Major/Minor/Cosmetic, owner, status) and messages the owner.
               The owner fixes and replies "FIXED <id>", and QA re-verifies and closes the issue.
P4 acceptance: QA sends the final report to the Lead. The Lead does the acceptance review and the final save.
```
Report to `team-lead` at each milestone. Messages: **≤ 8 lines**. Put long content in files and send the path.
If you are blocked for more than 5 minutes, message the Lead. Do not wait silently.

## Quality bar
* Reload is error-free and has **no synthetic keys or circular references**. Reload time is reasonable (aim for < 90 s), and data is deterministic.
* Every visible number reconciles with the facts (QA checks independently).
* Layout: consistent header band and navigation on every sheet, a consistent palette and fonts, aligned grid, no overlapping objects
  (except deliberate background panels), titles on every object, units and number formats on every KPI, and no "Error in expression" or empty charts.
* Every sheet has small explanation boxes ("What am I looking at?") and labels. Cyclic and drill groups are used on the Analysis sheets.

## Round 2 (2026-10-14) — finish the app. Lead = `team-lead` (orchestrator)
State at start: data DONE (1M rows, 167 vars, 8 groups verified live). Only the sandbox sheet `ZZ_designer_Sandbox` (Dashboard prototype) exists.
QlikView was restarted by the lead at round start; the user window is now maximized (~1900 px wide), but **keep designing for 1690 × 755**.
Team and ownership this round:
| Agent | Scope |
|---|---|
| `designer-a` | owns `designer/lib-qv.ps1` + style. Fixes the Dashboard defects, builds the final **SH_DASH** (reuse/rename SH01 "Main", delete the sandbox), then **SH_SALES** and **SH_CUST**. |
| `designer-b` | builds **SH_CN** and **SH_TEAM** in `designer/b/` (build-SH_CN.ps1, build-SH_TEAM.ps1). Dot-sources lib-qv.ps1 read-only; put extra helpers in `designer/b/lib-ext.ps1`. |
| `engineer` | builds **SH_REPORT** and **SH_HELP** (engineer/build-SH_REPORT.ps1, build-SH_HELP.ps1) with the designer lib, plus the story bookmarks. Fixes measure/variable bugs that QA reports. |
| `qa` | fixes false positives in its checkers (E-01 "0 vars found", E-09 empty groups, YoYpp is ×100 by spec), then reviews each sheet and logs issues in qa/issues.md. |
Sheet build order and the COM lock: hold the lock **per sheet build (≤ 6 min)**, then release it so the others can build. Each builder must check that its sheet renders with **no "€ 0", raw unformatted numbers, truncated text, overlapping labels or wrong titles**.
When a sheet is done, append `SHEET READY SH_x` to your status file `status/<you>.md`.
