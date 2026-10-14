# QlikView 12 COM cheat sheet (PowerShell)

Verified against QlikView Desktop 12.10 x64 from PowerShell 5.1. The toolkit (`toolkit/lib-qv.ps1`) wraps most of this.
Read this file before you write raw COM code.

## Connect
```powershell
. "$PSScriptRoot\..\tools\qvcom.ps1"        # Get-QvApp, Get-QvDoc, Start-QvDoc, locks, retry, checkpoint, screenshot
Start-QvDoc                                  # launches Qv.exe with the configured doc if QlikView is not running
$app = Get-QvApp                             # [Marshal]::GetActiveObject('QlikTech.QlikView')
$doc = Get-QvDoc                             # active document (checked against _build\qv.config if set)
$app.WaitForIdle()                           # call after reloads, selections, sheet activation
```
In PowerShell, members that take parameters are called like methods: `$doc.GetSheet(0).GetProperties().Name`.
Plain properties work as properties: `$p.Script = $text`.

## Script, reload, variables, evaluate
| Task | Code |
|---|---|
| Read the script | `$doc.GetProperties().Script` |
| Set the script | `$p = $doc.GetProperties(); $p.Script = $text; $p.GenerateLogfile = $true; $doc.SetProperties($p)` |
| Reload | `$doc.DoReload(2, $false, $false)`, then `WaitForIdle()`. The log is `<doc>.qvw.log` |
| Evaluate | `$doc.Evaluate('Sum(Sales)')` returns a string; `$(vX)` expands |
| Variable get | `$doc.Variables('vX').GetContent().String` |
| Variable set/create | `$v = $doc.Variables('vX'); if (-not $v) { [void]$doc.CreateVariable('vX'); $v = $doc.Variables('vX') }; [void]$v.SetContent('Sum(Sales)', $true)` |
| List variables | `$vd = $doc.GetVariableDescriptions(); $vd.Item($i).Name` (skip `IsReserved`/`IsConfig`) |
| Tables and rows | `$doc.GetTableCount()`, `$doc.GetTableName($i)`, `Evaluate("Only({1<`$Table={'T'}>} `$Rows)")` |
| Save | `$doc.Save()`. Checkpoint copy: `Save-QvCheckpoint -Doc $doc -Label x` |

Variables defined by `SET`/`LET` in the script are re-created on every reload. Prefer the script for anything permanent.
`SetContent` changes survive only until the next reload unless you also patch the script.

## Selections
```powershell
$doc.ClearAll($true)                          # ALWAYS before releasing the lock if you selected anything
$f = $doc.Fields('Region'); [void]$f.Select('DACH'); [void]$f.ToggleSelect('CEE')
$doc.Evaluate("GetFieldSelections(Region, ', ', 10)")
```

## Sheets
| Task | Code |
|---|---|
| Count / get | `$doc.NoOfSheets()`, `$doc.GetSheet($i)` |
| Create | `$sh = $doc.CreateSheet(); $p = $sh.GetProperties(); $p.Name = 'Sales'; $p.SheetId = 'Document\SH_SALES'; $sh.SetProperties($p)` |
| Activate | `$doc.ActivateSheetById('Document\SH_SALES')` or `$sh.Activate()` |
| Remove | `$sh.Remove()` |
| Order | `$sh.Promote()` / `$sh.Demote()` (see `Set-QvSheetOrder`) |
| Objects | `$sh.GetSheetObjects()`, `$sh.NoOfSheetObjects()`, `$doc.GetSheetObject('Document\ID')` |
| Background | `$p.UseApplicationBkg=$false; $p.UseColorBkg=$true; $p.BkgColor...` (see `Reset-QvSheet`) |

## Create objects (sheet methods)
`CreateBarChart CreateLineChart CreateComboChart CreatePieChart CreateScatterChart CreateGridChart CreateGaugeChart
CreateRadarChart CreatePivotTable CreateStraightTable CreateTableBox CreateListBox CreateMultiBox CreateTextObject
CreateButton CreateLineArrowObject CreateCurrentSelectionsBox CreateSearchObject CreateBookmarkObject CreateSlider
CreateInputBox CreateStatisticsBox CreateContainer CreateObjectFromXmlPropertiesFile`

Mekko, funnel and block charts are bar charts with `GraphLayout.GraphMode` = **12 / 11 / 10**.
Object type codes from `GetObjectType()`: 6 text, 5 button, 11 straight table (10+ = charts and tables), 13 pie, 16 combo, 22 gauge.

Chart workflow: `$o = $sh.CreateBarChart(); [void]$o.AddDimension('Region'); [void]$o.AddGroupDimension('cyc_Time'); [void]$o.AddExpression('Sum(Sales)')`,
then `$p = $o.GetProperties()`, edit, `$o.SetProperties($p)`. Set the rect with `$r = $o.GetRect(); $r.Left=...; $o.SetRect($r)`.

## Property paths you will need (charts: under `$p`)
| What | Path |
|---|---|
| Object ID | `(Get-QvFrame $p).ObjectId = 'Document\DASH_KPI1'` (Frame lives at `GraphLayout.Frame`, `Layout.Frame` or `Frame`) |
| **Chart caption** | **`$p.GraphLayout.WindowTitle.v = 'Title'`** (+ `Frame.Name.v`). Without it QV shows the 1st expression label |
| Show caption / help | `Frame.ShowCaption`, `Frame.HelpText.v`, `Frame.AllowInfo` |
| Show condition | `Frame.Show.Always = $false; Frame.Show.Expression.v = 'vShowHelp=1'` |
| Calc condition | `$p.EvaluationCondition.v = 'Count(InvoiceLineID) <= 50000'` |
| Custom calc-condition message | `$em = $p.GraphLayout.ErrorMessageOverrides; while ($em.Count -lt 6) {[void]$em.Add()}; $em.Item(5).v = 'Select a month first'` (table box: `$p.ErrorMessageOverrides`) |
| Expression definition | `$p.Expressions.Item(i).Item(0).Data.ExpressionData.Definition.v` |
| Expression label | `...Data.ExpressionVisual.Label.v` |
| **Values on data points** | `...ExpressionVisual.ShowAsTextInChart = $false` (QV 12 sets it to ON for every new expression) |
| Number format | `...ExpressionVisual.NumberPresentation` with Type 0 raw, 10 int, 11 fixed, 12 money, 2 custom; plus `Fmt`, `nDec`, `Dec`, `Thou` |
| Bar/line/symbol | `...ExpressionVisual.ShowAsBar / ShowAsLine / ShowAsSymbol`; secondary axis `PrimaryAxis = $false` |
| Colour per bar/slice | `...Data.AttributeExpressions.BkgColorExp.Definition.v = 'RGB(47,109,181)'` |
| Text colour (tables) | `...AttributeExpressions.TextColorExp.Definition.v` |
| Relative (% of total) | `...ExpressionData.Relative = $true` |
| Table cell repr. | `...ExpressionVisual.ImageRepresentation.Presentation`: 3 circ. gauge, 4 linear gauge, 5 traffic light, 6 LED digits, 7 mini chart |
| Gauge range/segments | `...ExpressionVisual.GaugeSettings`: `GaugeMin.v`, `GaugeMax.v`, `GaugeSegments.Item(i).LowerBound.v`, `.Color` |
| Y-axis | `...Data.AxisData`: `Show`, `Grid`, `Force0`, `Min.v`, `Max.v`, `Font`, `NumberPresentation` |
| Dimension label / null suppression | `$p.Dimensions.Item(i).Title.v = 'Region'`, `.NullSuppression = $true` |
| Calculated dimension | `[void]$p.Dimensions.Add(); $d = $p.Dimensions.Item($p.Dimensions.Count-1); $d.PseudoDef.Name = '=If(...)'` (appended AFTER the field dims) |
| Cyclic expression group | `$g = $p.Expressions.Item(i); [void]$g.Add(); $m = $g.Item($g.Count-1)` then set `$m.Data...` like any expression |
| Dimension limit (Top N) | `$p.Dimensions.Item(i).MaxNumShown.v = 'vTopN'` (shows the largest N) |
| Dimension sort by expr. | `...SortCriteria.SortByExpression = -1; .Expression.v = '...'; SortByNumeric=0; SortByAscii=0; SortByLoadOrder=0` |
| Column width | `ColWidth` in **1/300 inch**: `px * 300 / 96` (the chart-text unit is ~0.1 mm: `px / 0.378`) |
| Table totals on top | `$p.TableProperties.TableTotalPosition = 0` |
| No total for a column | wrap the definition: `If(Dimensionality()=0, Null(), <expr>)` |
| Pivot layout | `ExpressionPosition`, `NumberOfLeftDimensions`: set them via an XML round-trip (`Set-EngPivotLayout`) |
| XL / maximize icons | `Frame.XLIcon`, `Frame.AllowMaximize` |
| Colours | COLORREF int = `R + G*256 + B*65536`; `Set-QvColorArea $area '#RRGGBB'` (Mode 0, PrimaryCol.Col, Alpha) |
| Fonts | `Font.FontName`, `Font.PointSize1000 = 9000` |

## Buttons and actions
`$p.ActionItems.Add(); $ai.Type = <code>; $ai.Parameters.Add(); $ai.Parameters.Item(0).v = 'SH_SALES'`.
Action type codes: clear 4, back 6, forward 7, bookmark 14, **sheet 18**, **set variable 31**, select 32, clear field 36,
clear other 26, lock all 2, unlock all 3. Text alignment: HAlign 0/1/2 (left/centre/right), VAlign 0/4/8 (top/centre/bottom).

## Groups
```powershell
$grp = $doc.CreateGroup('cyc_Time'); $grp.AddField('Year'); $grp.AddField('YearMonth')
$p = $grp.GetProperties(); $p.IsCyclic = $true; $p.Labels = [object[]]@('Year','Month'); $grp.SetProperties($p)
# read: $p.FieldDefs.Count / $p.FieldDefs.Item(i).Name ; remove: $doc.RemoveGroup('cyc_Time')
```
Cyclic expression groups have no reliable COM getter for the *active* member's label, so use buttons + a UI variable when the title must name the measure.
`AddGroupDimension` on a **pivot table** leaves the dimensions empty, so use plain dimensions there.

## Bookmarks
```powershell
# (ShowPopupInfo, Name, Id, PopupTime, ExcludeSelections, IncludeLayoutState, IncludeScrollPos, IncludeInputFieldValues, InfoText, HideFromMenu)
$doc.CreateDocBookmark($false, 'Story 1 - Networking', 'BM_STORY1', 0, $false, $true, $false, $false, 'info text', $false)
$doc.RecallDocBookmarkById('Document\BM_STORY1'); $doc.GetDocBookmarkNames(); $doc.RemoveDocBookmark('Story 1 - Networking')
```
The **3rd argument is the ID**. Create the bookmark while its target sheet is active, with IncludeLayoutState = `$true`, so recalling it opens that sheet.

## XML round-trip (for properties COM cannot set)
`$o.WriteXmlPropertiesFile($tmp)` → edit the XML → `$o.Close()` → `$sh.CreateObjectFromXmlPropertiesFile($tmp)`, then restore the ObjectId and rect.
Used for Current Selections `ColWidths` (`Repair-QvCurSelWidths`) and pivot layout (`Set-EngPivotLayout`).

## Screenshots
`Save-QvScreenshot -Path x.png` captures the whole QlikView window with PrintWindow. It works when the window is covered, but **not when it is minimized**.
Activate the sheet and `WaitForIdle()` first, then wait a few seconds on big data.
