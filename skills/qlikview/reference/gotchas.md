# Gotchas: things that cost hours the first time

Each entry gives the symptom, the cause and the fix. All are verified on QlikView 12.10 x64 with 1M rows.

## Stability and performance
| Symptom | Cause | Fix |
|---|---|---|
| QlikView freezes for minutes, needs a force restart | A chart whose dimension or expression references **no data field** (e.g. `ValueLoop`/`ValueList` only) on a large model | Never create field-less charts. Relabel a real field (e.g. `Quarter` renamed as stages) or use text objects |
| Each COM call takes 1-7 s during a build | QlikView recalculates the **visible** sheet after every change | Build while a blank "parking" sheet is active (`Enter-QvParking` / `Exit-QvParking`) |
| Agents block each other | QlikView COM is single-threaded | One writer at a time: `Enter-QvLock`/`Exit-QvLock`. Hold it per sheet (≤ 6 min). More than ~3 parallel builders gains nothing |
| Waiting script crashes "Cannot find path owner.txt" | Lock released between Test-Path and Get-Item | Fixed in `qvcom.ps1` (`-ErrorAction SilentlyContinue` + retry) |
| A killed script leaves the lock held | Timeout killed PowerShell | The lock records `pid=`; `Enter-QvLock` breaks locks of dead processes automatically |
| Detail tables (1M rows) are slow or unusable | No calculation condition | `EvaluationCondition` = `Count(LineID) <= 50000`, plus a friendly message in `ErrorMessageOverrides.Item(5)` |
| Screenshot is black or empty | QlikView window minimized | Keep the window restored. `PrintWindow` works when it is covered, not minimized |

## Wrong-looking measures (the classic "measure issue")
| Symptom | Cause | Fix |
|---|---|---|
| Chart title shows "2026 actual" or "CYTD" (the first expression label) | Caption is read from `GraphLayout.WindowTitle`, not `Frame.Name` | Set `GraphLayout.WindowTitle.v` (the toolkit does it) |
| Pie or relative chart labels show **"€ 0"** | Share values (0..1) formatted as money | `Fmt='pct'` on relative expressions |
| Value labels pile up on every point | QV 12 turns `ShowAsTextInChart` ON for every new expression | Set it OFF by default; turn it on only where needed |
| Every chart got labels even with `Values=$false` | PowerShell: `$hashtable.Values` is the hashtable's value **collection**, so it is always truthy | Use `$x['Values']` |
| Table total row shows a raw `1234070383.61` under a sparkline or rate column | Totals computed for every column | Wrap the definition in `If(Dimensionality()=0, Null(), …)` (`NoTotal=$true`) or set a proper rate total |
| Totals row shows `-` | Null symbol in total cells | Blank the null/missing symbols (`Set-QvbBlankNull`) or give real totals |
| Budget achievement 72% for the current year, 0% for future quarters | Actuals stop at the data end date, the budget covers the whole year | Separate measures: `vBudget` (full year) and `vBudgetToDate` (capped at the data end); achievement = actual / budget to date. **Label both on screen** |
| Lower last-year bar looks like a drop | Current year is partial (YTD) | Say "2026 = Jan–Sep (YTD)" in the title |
| Axis shows `100,000,000` | Large raw numbers | Divide by 1e6 in the expression, `Fmt='moneyM'`, and an axis unit text "€ M" (QV ignores text like " M" inside axis number formats) |
| Mekko y-axis shows 0.0–1.0 | Relative Mekko axis ignores % formats | Hide that axis; the title says "share" |
| Status lights identical on every row | Thresholds wider than the real spread (e.g. all regions 5.2–5.8% credit rate) | Base the light on something that varies (YoY growth) or tighten the thresholds; check the screenshot |
| Same category gets different colours in different charts | Default palette colours by load order | One fixed colour expression per categorical dimension (`$QS.ChannelColorExpr` pattern) on every chart |
| Variable "exists" checks report 0 found | Error swallowed in a helper | `$doc.Variables(name)` returns `$null` when missing; test each name and don't wrap it in a silent try |
| Cyclic expression: title can't name the active measure | No COM or expression access to the active member label | Buttons + UI variable (`vUI_TrendMeasure`) and `Pick()` in the expression and title |

## Layout
| Symptom | Cause | Fix |
|---|---|---|
| Truncated headers ("Net Revenue C…", "United King…") | Default column widths | Set `ColWidth` (px × 300 / 96) or shorter headers ("NM %") |
| Horizontal scrollbar in Current Selections | `ColWidths` cannot be set via COM | XML round-trip: `Repair-QvCurSelWidths` |
| Block chart leaf captions grey or truncated | Labels only show for field dims; small leaves cut off | Prefer a 100% stacked bar or a pivot heat-map |
| Pivot heat-map without values | Grid chart shows values only on hover | Pivot table with a background colour expression and visible values |
| Drill group in a pivot leaves the dims empty | `AddGroupDimension` on a pivot fails silently | Plain dimensions in pivots; drill groups in charts |
| Empty half of a container tab | Pivot columns too narrow | Set column widths to fill the container (sum of widths ≤ inner width, or a scrollbar appears) |
| A helper silently does nothing on a just-built object | `$doc.GetSheetObject('Document\ID')` returns null for an object created on an **inactive** sheet (parking active) | Look objects up on their sheet: `$sheet.GetSheetObjects()` + `GetObjectId()` |
| Two tabs with the same name, or a leftover "park" sheet | Sandbox or parking sheets not removed | Delete them; `final-check.ps1` lists every sheet |
| Lead reviewed an outdated screenshot and sent fixes that were already done | Screenshots are overwritten while builders work | Always check the screenshot **timestamp** before sending fix notes |

## PowerShell and COM
* `.ps1` files with non-ASCII characters (€ · ▲) must be **UTF-8 with BOM** for Windows PowerShell 5.1. Keep libraries ASCII and build glyphs with `[char]0x20AC`.
* `$(vX)` inside a **double-quoted** PowerShell string is expanded by PowerShell. Use single quotes for QlikView dollar expansions.
* Inside a scriptblock passed to another function, a variable named like that function's parameter (e.g. `$Configure`) resolves to the inner one. Copy it to a different name first.
* PowerShell variables are case-insensitive: `$c` and `$C` are the same variable, so a `foreach ($c in …)` loop overwrites a colour table `$C`.
* A gauge segment list with ONE segment needs the unary comma: `Seg=@(,@('0','#hex'))`.
* `CreateDocBookmark`: the 3rd argument is the ID, the 9th is the info text.
* Run every COM script with a timeout (`qvrun.sh` uses `timeout 300`). If QlikView hangs, **do not kill it from a script**: tell the user.
* Never close the user's document or QlikView, and never open other documents in their instance.
