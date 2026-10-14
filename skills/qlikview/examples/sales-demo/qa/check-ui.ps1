# QA UI checks for QLIK-CL (owner: QA). Holds the COM lock while it activates sheets / takes screenshots, then restores
# the previously active sheet, clears selections and releases the lock. Never modifies objects.
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File <win path>\check-ui.ps1 [-Sheet SH_DASH,SH_SALES] [-NoScreens] [-Force]
# Safety: a sheet with a chart expression that references no data field (hang risk over 1M rows) is NOT activated unless -Force.
# Expectations come from spec/data-contract.md (sheets) and spec/style-guide.md (zones, palette, fonts, IDs).
param([string[]]$Sheet, [switch]$NoScreens, [switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-common.ps1"
$doc = Connect-QaDoc; $app = $Global:QaApp
$appendix = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------- expectations
$ContractSheets = [ordered]@{ SH_DASH = 'Dashboard'; SH_SALES = 'Sales Analysis'; SH_CUST = 'Customers & Products'; SH_CN = 'Credit Notes'
                              SH_TEAM = 'Sales Team & Budget'; SH_REPORT = 'Reports'; SH_HELP = 'About & Data Model' }
# names follow spec/data-contract.md (the lead amends it, e.g. SH_TEAM 'Team & Budget' on 14/10)
try { $ct = Get-Content -Raw -Encoding UTF8 (Join-Path $QvBuildRoot 'spec\data-contract.md')
      foreach ($k in @($ContractSheets.Keys)) { $m = [regex]::Match($ct, '\|\s*`' + $k + '`\s*\|\s*([^|(]+?)\s*(?:\(|\|)'); if ($m.Success) { $ContractSheets[$k] = $m.Groups[1].Value.Trim() } } } catch {}
$Tag = @{ SH_DASH = 'DASH'; SH_SALES = 'SALES'; SH_CUST = 'CUST'; SH_CN = 'CN'; SH_TEAM = 'TEAM'; SH_REPORT = 'REP'; SH_HELP = 'HELP' }
$Analysis = @('SH_SALES','SH_CUST','SH_CN','SH_TEAM')
$CanvasW = 1690; $CanvasH = 755; $ContentBottom = 746
$TypeName = @{ 1 = 'ListBox'; 2 = 'MultiBox'; 3 = 'StatisticsBox'; 4 = 'TableBox'; 5 = 'Button'; 6 = 'TextObject'; 7 = 'CurrentSelections'; 8 = 'InputBox'
               9 = 'LineArrow'; 10 = 'PivotTable'; 11 = 'StraightTable'; 12 = 'BarChart'; 13 = 'PieChart'; 14 = 'ScatterChart'; 15 = 'LineChart'; 16 = 'ComboChart'
               17 = 'CustomObject'; 18 = 'BookmarkObject'; 20 = 'GridChart'; 21 = 'RadarChart'; 22 = 'GaugeChart'; 31 = 'SearchObject'; 34 = 'Slider'; 36 = 'Container' }
$ChartTypes = @(10, 11, 12, 13, 14, 15, 16, 20, 21, 22)
$NeedsCaption = @(1, 2, 3, 4, 7, 8, 10, 11, 12, 13, 14, 15, 16, 18, 20, 21, 22, 31, 34, 36)
$AllowedFonts = @('Segoe UI', 'Segoe UI Semibold')
$guide = Get-Content -Raw -Encoding UTF8 (Join-Path $QvBuildRoot 'spec\style-guide.md')
$Palette = @([regex]::Matches($guide, '#[0-9A-Fa-f]{6}') | ForEach-Object { $_.Value.ToUpper() } | Sort-Object -Unique) + @('#FFFFFF')
$HelpGlyph = [string][char]0x24D8

# ---------------------------------------------------------------- XML helpers
function XV($node, [string]$xp) { if (-not $node) { return $null }; $n = $node.SelectSingleNode($xp); if ($n) { return $n.InnerText } else { return $null } }
function Get-Hex($colNode) {
    if (-not $colNode) { return $null }
    if ((XV $colNode 'PrimaryCol/IsCalculated') -eq 'true') { return 'calc' }
    $r = XV $colNode 'PrimaryCol/Col/Red'; $g = XV $colNode 'PrimaryCol/Col/Green'; $b = XV $colNode 'PrimaryCol/Col/Blue'
    if ($null -eq $r) { return $null }
    return ('#{0:X2}{1:X2}{2:X2}' -f [int]$r, [int]$g, [int]$b)
}
function Get-ObjInfo($o, [string]$xmlDir) {
    $id = $o.GetObjectId(); $short = $id -replace '^Document\\', ''
    $t = [int]$o.GetObjectType(); $r = $o.GetRect()
    $f = Join-Path $xmlDir "$short.xml"; $o.WriteXmlPropertiesFile($f)
    $x = New-Object System.Xml.XmlDocument; $x.Load($f)
    $fr = $x.SelectSingleNode('//Frame')
    $info = [ordered]@{ Id = $short; Type = $t; TypeName = $TypeName[$t]; L = [int]$r.Left; T = [int]$r.Top; W = [int]$r.Width; H = [int]$r.Height
        Caption = (XV $fr 'Name/v'); ShowCaption = ((XV $fr 'ShowCaption') -eq 'true'); Zed = [int](XV $fr 'ZedLevel')
        ShowAlways = ((XV $fr 'Show/Always') -ne 'false'); ShowExpr = (XV $fr 'Show/Expression/v'); HelpText = (XV $fr 'HelpText/v')
        Text = $null; TextEval = $null; Title = $null; GraphMode = (XV $x '//GraphLayout/GraphMode'); Fonts = @(); Colors = @(); Actions = @()
        Dims = @(); Exprs = @(); Children = @(); CalcMs = $null; Rows = $null; Xml = $f }
    if ($info.GraphMode -and $t -notin $script:ChartTypes) { $script:ChartTypes += $t }   # e.g. mekko/funnel/block types not in the static list
    if ($info.GraphMode) { $info.TypeName = ($info.GraphMode -replace '^GRAPH_MODE_', '') + '_CHART'; if ($t -eq 10) { $info.TypeName = 'PivotTable' }; if ($t -eq 11) { $info.TypeName = 'StraightTable' } }
    if ($t -eq 6) { $info.Text = XV $x '//TextObjectProperties/Layout/Text/v' }
    if ($t -eq 5) { $info.Text = XV $x '//ButtonProperties/Text/v' }
    if ($t -in $ChartTypes) { if ((XV $x '//ChartProperties/Title/Show') -ne 'false') { $info.Title = XV $x '//ChartProperties/Title/Title/v' } }
    # fonts actually used (skip print/animation/trailing defaults and hidden chart parts)
    foreach ($fn in $x.SelectNodes('//*[FontName]')) {
        $path = @(); $p = $fn; while ($p -and $p.LocalName -ne '#document') { $path = ,$p.LocalName + $path; $p = $p.ParentNode }
        $ps = $path -join '/'
        if ($ps -match 'Print|Animation|TrailingText|SelectionStamp|Block|Gauge|Mekko|Funnel|StatisticsBox.*Tab|_OBSOLETE') { continue }
        if ($ps -match 'CaptionFont' -and -not $info.ShowCaption) { continue }
        $par = $fn.ParentNode; if ($par -and (XV $par 'Show') -eq 'false') { continue }
        $info.Fonts += [pscustomobject]@{ Path = ($path[-2..-1] -join '/'); Name = (XV $fn 'FontName'); Pt = ([double](XV $fn 'PointSize1000') / 1000); Bold = (XV $fn 'Bold') }
    }
    # colours that are visible on the object
    $cand = @()
    if ((XV $fr 'Background/UseColor') -eq 'true') { $cand += ,@('FrameBg', $fr.SelectSingleNode('Background/Color')) }
    if ($info.ShowCaption) { $cand += ,@('CaptionBg', $fr.SelectSingleNode('ActiveBgColor')); $cand += ,@('CaptionFg', $fr.SelectSingleNode('ActiveFgColor')) }
    if ($t -eq 6) { $cand += ,@('Bkg', $x.SelectSingleNode('//TextObjectProperties/Layout/BkgColor')); $cand += ,@('Text', $x.SelectSingleNode('//TextObjectProperties/Layout/TextColor')) }
    if ($t -eq 5) { $cand += ,@('Bkg', $x.SelectSingleNode('//ButtonProperties/BkgColor')); $cand += ,@('Text', $x.SelectSingleNode('//ButtonProperties/TextColor')) }
    foreach ($c in $cand) { $h = Get-Hex $c[1]; if ($h) { $info.Colors += [pscustomobject]@{ Role = $c[0]; Hex = $h } } }
    foreach ($a in $x.SelectNodes('//ActionItems/ActionItemDef')) {
        $prm = @($a.SelectNodes('Parameters//v') | ForEach-Object { $_.InnerText })
        $info.Actions += [pscustomobject]@{ Type = (XV $a 'Type'); Params = $prm }
    }
    foreach ($d in $x.SelectNodes('//Dimensions/ChartDimensionDataDef/PseudoDef')) { $info.Dims += [pscustomobject]@{ Name = (XV $d 'Name'); Kind = (XV $d 'Type') } }
    foreach ($m in $x.SelectNodes('//Expressions/ArrayOfMainExpressionData/MainExpressionData')) {
        $def = XV $m './/ExpressionData/Definition/v'; $lab = XV $m './/ExpressionVisual/Label/v'
        $np = $m.SelectSingleNode('.//ExpressionVisual/NumberPresentation')
        $info.Exprs += [pscustomobject]@{ Def = $def; Label = $lab; Fmt = (XV $np 'Fmt'); FmtType = (XV $np 'Type'); Enabled = ((XV $m './/ExpressionData/Enable') -ne 'false') }
    }
    $co = $x.SelectSingleNode('//ContainedObjects')
    if ($co) { $info.Children = @([regex]::Matches($co.OuterXml, '(?:Document\\)?([A-Za-z][A-Za-z0-9_]*)(?=<)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch '^(true|false|v)$' } | Sort-Object -Unique) }
    $info.Com = $o
    return [pscustomobject]$info
}
# runtime values (only after the sheet is active, so nothing is calculated on a sheet we decided not to open)
function Add-RuntimeInfo($info) {
    $o = $info.Com; $t = $info.Type
    try { $info.CalcMs = [double]$o.GetObjectCalcTime() } catch {}
    if ($t -in $ChartTypes -or $t -eq 4) { try { $info.Rows = [int]$o.GetRowCount() } catch {} }
    if ($t -eq 6) { try { $info.TextEval = [string]$o.GetText() } catch {} }
}
# --- field references (U-17): does an expression / dimension reference at least one data field (after $(v) expansion)?
function Expand-QaVars([string]$t) {
    for ($i = 0; $i -lt 6 -and $t -match '\$\(\s*v[A-Za-z0-9_]+\s*\)'; $i++) {
        $t = [regex]::Replace($t, '\$\(\s*(v[A-Za-z0-9_]+)\s*\)', { param($m) $r = $VarRaw[$m.Groups[1].Value]; if ($null -eq $r) { $m.Value -replace '\$', '#' } else { $r.TrimStart('=') } })
    }
    return $t
}
function Test-RefsField([string]$t) {
    if (-not $t) { return $false }
    $t = Expand-QaVars $t
    $t = [regex]::Replace($t, "'[^']*'", "''")
    foreach ($m in [regex]::Matches($t, '\[([^\]]+)\]|([A-Za-z_%][A-Za-z0-9_%]*)')) {
        $n = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        if ($DataFields.Contains($n) -or $groups.ContainsKey($n)) { return $true }
    }
    return $false
}
function Get-EvalText([string]$s) {
    if ($null -eq $s) { return '' }
    if ($s.StartsWith('=')) { return (QE $s.Substring(1)).Text }
    return $s
}
function Test-Intersect($a, $b) {
    $w = [math]::Min($a.L + $a.W, $b.L + $b.W) - [math]::Max($a.L, $b.L); $h = [math]::Min($a.T + $a.H, $b.T + $b.H) - [math]::Max($a.T, $b.T)
    return ($w -gt 0 -and $h -gt 0)
}
function Test-Contains($outer, $inner) { ($inner.L -ge $outer.L -and $inner.T -ge $outer.T -and ($inner.L + $inner.W) -le ($outer.L + $outer.W) -and ($inner.T + $inner.H) -le ($outer.T + $outer.H)) }
function Near($a, $b, [int]$tol = 2) { [math]::Abs([double]$a - [double]$b) -le $tol }
function RectTxt($o) { "$($o.L),$($o.T),$($o.W),$($o.H)" }

# ---------------------------------------------------------------- layout-spec (designer) expectations
$TagSheet = @{}; foreach ($k in $Tag.Keys) { $TagSheet[$Tag[$k]] = $k }
function Get-LayoutSpec {
    $f = Join-Path $QvBuildRoot 'spec\layout-spec.md'; if (-not (Test-Path $f)) { return @() }
    $out = New-Object System.Collections.Generic.List[object]; $sec = ''
    $add = { param($id, $type, $rect) $pre = ($id -split '_')[0]; if ($TagSheet.ContainsKey($pre)) { $out.Add([pscustomobject]@{ Sheet = $TagSheet[$pre]; Id = $id; Type = $type; Rect = $rect }) } }
    foreach ($line in (Get-Content -Encoding UTF8 $f)) {
        if ($line -match '^## 0\. ') { $sec = 'chrome' } elseif ($line -match '^## 0b\. ') { $sec = 'filter' } elseif ($line -match '^## [1-7]\. ') { $sec = 'sheet' } elseif ($line -match '^## 8\. ') { $sec = 'end' }
        if ($sec -eq 'end') { continue }
        $m = [regex]::Match($line, '^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|')
        if ($m.Success) {
            $id = $m.Groups[1].Value; $type = $m.Groups[2].Value; $rc = $m.Groups[3].Value
            if ($id -match '[*{]|\.\.\.|…') { continue }
            $rm = [regex]::Match($rc, '^(\d+),(\d+),(\d+),(\d+)$'); $rect = if ($rm.Success) { @([int]$rm.Groups[1].Value, [int]$rm.Groups[2].Value, [int]$rm.Groups[3].Value, [int]$rm.Groups[4].Value) } else { $null }
            $tags = if ($sec -eq 'chrome') { @($Tag.Values) } elseif ($sec -eq 'filter') { @('SALES','CUST','CN','TEAM','REP') } else { @('') }
            foreach ($t in $tags) { & $add ($id -replace '<T>', $t) $type $rect }
            continue
        }
        foreach ($pm in [regex]::Matches($line, '`([A-Z]+_[A-Z0-9_]+)`\s+(.*?)\bat\s+(\d+),(\d+),(\d+),(\d+)')) {
            & $add $pm.Groups[1].Value $pm.Groups[2].Value @([int]$pm.Groups[3].Value, [int]$pm.Groups[4].Value, [int]$pm.Groups[5].Value, [int]$pm.Groups[6].Value)
        }
    }
    $kx = @(10, 290, 570, 850, 1130, 1410); for ($n = 1; $n -le 6; $n++) { & $add "DASH_KPI${n}_BG" 'Text' @($kx[$n-1], 96, 270, 118) }
    $cx = @(230, 595, 960, 1325); for ($n = 1; $n -le 4; $n++) { & $add "CN_KPI${n}_BG" 'Text' @($cx[$n-1], 96, 355, 64) }
    return $out
}
$TypeKw = [ordered]@{ 'Current Selections' = 'CurrentSelections'; 'List Box' = 'ListBox'; 'Multi Box' = 'MultiBox'; 'Search Object' = 'SearchObject'; 'Statistics Box' = 'StatisticsBox'
    'Bookmark Object' = 'BookmarkObject'; 'Table Box' = 'TableBox'; 'Input Box' = 'InputBox'; 'Slider' = 'Slider'; 'Calendar' = 'Slider'; 'Container' = 'Container'
    'Straight table' = 'StraightTable'; 'Pivot table' = 'PivotTable'; 'Combo' = 'COMBO_CHART'; 'Bar' = 'BAR_CHART'; 'Line(?!/)' = 'LINE_CHART'; 'Pie' = 'PIE_CHART'
    'Scatter' = 'SCATTER_CHART'; 'Grid' = 'GRID_CHART'; 'Gauge' = 'GAUGE_CHART'; 'Radar' = 'RADAR_CHART'; 'Mekko' = 'MEKKO_CHART'; 'Block' = 'BLOCK_CHART'; 'Funnel' = 'FUNNEL_CHART'
    '^Text' = 'TextObject'; 'Button' = 'Button' }
function Get-AllowedTypes([string]$t) { @($TypeKw.Keys | Where-Object { $t -match "(?i)$_" } | ForEach-Object { $TypeKw[$_] }) }
$LayoutSpec = @(Get-LayoutSpec)

# ================================================================= U-01 sheets
$sheetsAll = @()
for ($i = 0; $i -lt $doc.NoOfSheets(); $i++) { $p = $doc.GetSheet($i).GetProperties(); $sheetsAll += [pscustomobject]@{ Idx = $i; Id = ($p.SheetId -replace '^Document\\', ''); Name = $p.Name } }
$present = @($sheetsAll | Where-Object { $ContractSheets.Contains($_.Id) })
foreach ($k in $ContractSheets.Keys) {
    $s = $sheetsAll | Where-Object Id -eq $k
    if ($s) { Test-QaEq 'U-01' "Sheet $k name" $ContractSheets[$k] $s.Name } else { Add-QaResult 'U-01' "Sheet $k exists" 'present' 'missing' $(if ($Sheet) { 'INFO' } else { 'FAIL' }) 'not built yet?' }
}
$order = @($present | Sort-Object Idx | ForEach-Object Id); $expOrder = @($ContractSheets.Keys | Where-Object { $order -contains $_ })
Test-Qa 'U-01' 'Sheet order D-A-R' ($expOrder -join ' > ') ($order -join ' > ') (($order -join ',') -eq ($expOrder -join ',')) -Note "all sheets: $(($sheetsAll | ForEach-Object Id) -join ', ')"
$leftover = @($sheetsAll | Where-Object { -not $ContractSheets.Contains($_.Id) })
Add-QaResult 'U-01' 'No leftover sheets (SH01 Main, ZZ_* sandboxes)' 'none' $(if ($leftover) { ($leftover | ForEach-Object { "$($_.Id) '$($_.Name)'" }) -join ', ' } else { 'none' }) $(if ($leftover) { 'WARN' } else { 'PASS' }) 'must be gone before final'

# ================================================================= per sheet (under lock)
$targets = if ($Sheet) { @($Sheet) } else { @($present | Sort-Object Idx | ForEach-Object Id) }
$groups = @{}
try { $gl = Invoke-QvRetry { $doc.GetGroups() }; for ($gi = 0; $gi -lt $gl.Count; $gi++) { $gp = $gl.Item($gi).GetProperties(); $groups[[string]$gp.Name] = [bool]$gp.IsCyclic } } catch { Add-QaResult 'U-00' 'Read groups via COM' 'ok' $_.Exception.Message 'WARN' 'checker error' }
$DataFields = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($f in (QT "Concat({1} DISTINCT `$Field, '~')").Split('~')) { if ($f -and $f -notlike '$*') { [void]$DataFields.Add($f) } }
$VarRaw = @{}; try { $vdl = Invoke-QvRetry { $doc.GetVariableDescriptions() }; for ($i = 0; $i -lt $vdl.Count; $i++) { $d = $vdl.Item($i); $VarRaw[[string]$d.Name] = [string]$d.RawValue } } catch { Add-QaResult 'U-00' 'Read variables via COM' 'ok' $_.Exception.Message 'WARN' 'checker error' }
$navRef = $null; $navRefFile = Join-Path $QaResDir 'ui-nav-ref.json'
if (Test-Path $navRefFile) { $navRef = Get-Content -Raw $navRefFile | ConvertFrom-Json }
$allObjs = @{}; $perf = New-Object System.Collections.Generic.List[object]

Enter-QaLock
try {
    $prevSheet = $null; try { $prevSheet = $doc.ActiveSheet().GetProperties().SheetId } catch {}
    Invoke-QvRetry { $doc.ClearAll($true) } | Out-Null
    foreach ($sid in $targets) {
        Update-QvLock -Owner qa
        $tag = $Tag[$sid]
        if (-not ($sheetsAll | Where-Object Id -eq $sid)) { Add-QaResult 'U-01' "Sheet $sid exists" 'present' 'missing' 'FAIL'; continue }
        $xmlDir = Join-Path $QaResDir "xml\$sid"; if (Test-Path $xmlDir) { Remove-Item -Recurse -Force $xmlDir }; New-Item -ItemType Directory -Path $xmlDir | Out-Null
        $sh = $doc.GetSheetById("Document\$sid")
        $objs = @(); foreach ($o in @($sh.GetSheetObjects())) { $objs += Get-ObjInfo $o $xmlDir }
        $allObjs[$sid] = $objs
        # U-17 field-less charts (static, before activation)
        $flDim = @(); $flExp = @()
        foreach ($o in ($objs | Where-Object { $_.Type -in $ChartTypes })) {
            foreach ($d in $o.Dims) { if ($d.Name -and -not (Test-RefsField $d.Name)) { $flDim += "$($o.Id) dim '$($d.Name)'" } }
            foreach ($x in ($o.Exprs | Where-Object { $_.Enabled -and $_.Def })) { if (-not (Test-RefsField $x.Def)) { $flExp += "$($o.Id) expr '$($x.Label)' = $($x.Def)" } }
        }
        Test-Qa 'U-17' "$sid no chart expression without a data field (hang risk)" 'none' "$($flExp.Count)" ($flExp.Count -eq 0) -Note (($flExp | Select-Object -First 15) -join ' || ')
        Test-Qa 'U-17' "$sid no chart dimension without a data field (calc dim)" 'none' "$($flDim.Count)" ($flDim.Count -eq 0) -Note (($flDim | Select-Object -First 15) -join ' || ')
        if ($flExp.Count -and -not $Force) {
            Add-QaResult 'U-17' "$sid NOT activated (safety)" 'activate' 'skipped' 'FAIL' 'field-less chart expression; rerun with -Force after the designer fixes or confirms it'
            continue
        }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Invoke-QvRetry { $doc.ActivateSheetById("Document\$sid") } | Out-Null
        [void]$app.WaitForIdle(); $switchMs = $sw.ElapsedMilliseconds
        Test-Qa 'P-05' "$sid sheet switch time" '< 3000 ms' "$switchMs ms" ($switchMs -lt 3000) -Soft
        if (-not $NoScreens) {
            Start-Sleep -Milliseconds 400
            $png = Join-Path $QaShotDir "${sid}_$QaStamp.png"; Save-QvScreenshot -Path $png | Out-Null
            Copy-Item $png (Join-Path $QaShotDir "${sid}_latest.png") -Force
            Add-QaResult 'U-14' "$sid screenshot" '-' $png 'INFO' 'visual review by QA'
        }
        foreach ($o in $objs) { Add-RuntimeInfo $o }
        Add-QaResult 'U-00' "$sid objects" '-' $objs.Count 'INFO' ((($objs | Group-Object TypeName | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', '))
        $byId = @{}; foreach ($o in $objs) { $byId[$o.Id] = $o }
        $childIds = @($objs | ForEach-Object { $_.Children } | Where-Object { $_ -and $byId.ContainsKey($_) } | Sort-Object -Unique)

        # U-02 bounds
        $oob = @($objs | Where-Object { $_.L -lt 0 -or $_.T -lt 0 -or ($_.L + $_.W) -gt $CanvasW -or ($_.T + $_.H) -gt $CanvasH })
        Test-Qa 'U-02' "$sid all objects inside $CanvasW x $CanvasH" 'none outside' "$($oob.Count) outside" ($oob.Count -eq 0) -Note (($oob | ForEach-Object { "$($_.Id) [$(RectTxt $_)]" }) -join '; ')
        $low = @($objs | Where-Object { ($_.T + $_.H) -gt $ContentBottom -and ($_.T + $_.H) -le $CanvasH })
        if ($low) { Add-QaResult 'U-02' "$sid content bottom <= $ContentBottom (style guide)" 'none below' (($low | ForEach-Object { "$($_.Id) bottom $($_.T + $_.H)" }) -join '; ') 'WARN' }

        # U-03 overlaps
        $ov = @(); $ovWarn = @()
        for ($i = 0; $i -lt $objs.Count; $i++) { for ($j = $i + 1; $j -lt $objs.Count; $j++) {
            $a = $objs[$i]; $b = $objs[$j]
            if (-not (Test-Intersect $a $b)) { continue }
            if ($a.Id -in $childIds -or $b.Id -in $childIds) { continue }                       # container children share the container area
            $outer = $null; $inner = $null
            if (Test-Contains $a $b) { $outer = $a; $inner = $b } elseif (Test-Contains $b $a) { $outer = $b; $inner = $a }
            if ($outer -and $outer.Type -eq 6 -and $outer.Zed -le $inner.Zed) { continue }      # background panel (text object, lower layer)
            if ($outer -and $outer.Type -eq 6 -and $outer.Zed -gt $inner.Zed) { $ov += "$($outer.Id) (panel above $($inner.Id): zed $($outer.Zed) > $($inner.Zed))"; continue }
            $msg = "$($a.Id) [$(RectTxt $a)] x $($b.Id) [$(RectTxt $b)]"
            $ka = [regex]::Match($a.Id, '^[A-Z]+_KPI\d+_').Value; $kb = [regex]::Match($b.Id, '^[A-Z]+_KPI\d+_').Value
            if ($ka -and $ka -eq $kb) { $ovWarn += "$msg (layers of one KPI tile)" }
            elseif ($a.Id -match '_DM_' -and $b.Id -match '_DM_') { $ovWarn += "$msg (diagram connector, deliberate)" }
            elseif (-not $a.ShowAlways -or -not $b.ShowAlways) { $ovWarn += "$msg (conditional)" } else { $ov += $msg }
        } }
        Test-Qa 'U-03' "$sid no overlapping objects" 'none (except background panels)' "$($ov.Count)" ($ov.Count -eq 0) -Note ($ov -join '; ')
        if ($ovWarn) { Add-QaResult 'U-03' "$sid overlaps involving conditional objects" 'none' "$($ovWarn.Count)" 'WARN' ($ovWarn -join '; ') }

        # U-04 titles / text
        $noCap = @(); $noUnit = @(); $noHelpTxt = @(); $emptyTxt = @()
        foreach ($o in $objs) {
            if ($o.Type -in $NeedsCaption -and $o.Id -match '_FLT_') { continue }
            if ($o.Type -eq 36 -and $o.Children.Count -gt 0) { continue }   # container: its tabs are the titles   # filter-panel objects are titled by the PanelHead strip above them
            if ($o.Type -in $NeedsCaption) {
                $cap = Get-EvalText $o.Caption; $ttl = Get-EvalText $o.Title
                $hasCap = ($o.ShowCaption -and $cap.Trim()) -or ($ttl -and $ttl.Trim()) -or ($o.Id -in $childIds -and $cap.Trim())
                if (-not $hasCap) { $noCap += $o.Id }
                elseif ($o.Type -in $ChartTypes -and ("$cap $ttl" -notmatch "\((?:[^)]*)(?:$([regex]::Escape($QaEuro))|%|count|pp|qty|units|#|days|EUR)" -and "$cap $ttl" -notmatch "$([regex]::Escape($QaEuro))|%")) { $noUnit += "$($o.Id) '$cap'" }
                if ($o.Type -in $ChartTypes -and -not ($o.HelpText -and $o.HelpText.Trim())) { $noHelpTxt += $o.Id }
            }
            elseif ($o.Type -eq 5 -and -not (Get-EvalText $o.Text).Trim()) { $emptyTxt += $o.Id }
            elseif ($o.Type -eq 6) {
                $isPanel = @($objs | Where-Object { $_.Id -ne $o.Id -and (Test-Contains $o $_) }).Count -gt 0
                $isBar = ($o.W -le 6 -or $o.H -le 6)
                if (-not $isPanel -and -not $isBar -and -not ([string]$o.TextEval).Trim() -and -not ([string]$o.Text).Trim()) { $emptyTxt += $o.Id }
            }
        }
        Test-Qa 'U-04' "$sid every object has a title (caption or chart title)" 'all' $(if ($noCap) { "$($noCap.Count) without" } else { 'all' }) ($noCap.Count -eq 0) -Note ($noCap -join ', ')
        Test-Qa 'U-04' "$sid chart titles state the unit" 'all' $(if ($noUnit) { "$($noUnit.Count) without unit" } else { 'all' }) ($noUnit.Count -eq 0) -Soft -Note ($noUnit -join '; ')
        Test-Qa 'U-04' "$sid charts have a HelpText" 'all' $(if ($noHelpTxt) { "$($noHelpTxt.Count) without" } else { 'all' }) ($noHelpTxt.Count -eq 0) -Soft -Note ($noHelpTxt -join ', ')
        Test-Qa 'U-04' "$sid text objects/buttons not empty (panels/bars excepted)" 'none empty' "$($emptyTxt.Count)" ($emptyTxt.Count -eq 0) -Soft -Note ($emptyTxt -join ', ')

        # U-05 fonts
        $badFont = @(); $accFont = @(); $fontUse = @{}
        foreach ($o in $objs) { foreach ($f in $o.Fonts) { $k = "$($f.Name) $($f.Pt)"; $fontUse[$k] = 1 + [int]$fontUse[$k]; if ($AllowedFonts -notcontains $f.Name) { if ($o.Type -in $ChartTypes -and $f.Path -match 'Axis|Legend|Grid|Chart') { $accFont += "$($o.Id):$($f.Path)" } else { $badFont += "$($o.Id):$($f.Path)=$($f.Name)" } } } }
        if ($accFont) { Add-QaResult 'U-05' "$sid chart axis/legend fonts not Segoe UI (accepted deviation Q-003, lead 14/10)" '-' "$($accFont.Count)" 'INFO' '' }
        Test-Qa 'U-05' "$sid fonts are Segoe UI (/Semibold)" 'Segoe UI only' "$($badFont.Count) other" ($badFont.Count -eq 0) -Note (($badFont | Select-Object -First 25) -join '; ')
        Add-QaResult 'U-05' "$sid font usage" '-' "$($fontUse.Count) variants" 'INFO' ((($fontUse.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)pt x$($_.Value)" }) -join ', '))
        $capSizes = @($objs | Where-Object { $_.ShowCaption -and $_.Type -in $NeedsCaption } | ForEach-Object { ($_.Fonts | Where-Object Path -match 'CaptionFont' | Select-Object -First 1) } | Where-Object { $_ -and $_.Pt -ne 9.5 })
        Test-Qa 'U-05' "$sid caption font 9.5 pt" 'all 9.5' "$($capSizes.Count) differ" ($capSizes.Count -eq 0) -Soft -Note (($capSizes | ForEach-Object { "$($_.Name) $($_.Pt)" }) -join ', ')

        # U-06 colours
        $offPal = @()
        foreach ($o in $objs) { foreach ($c in $o.Colors) { if ($c.Hex -ne 'calc' -and $Palette -notcontains $c.Hex) { $offPal += "$($o.Id).$($c.Role)=$($c.Hex)" } } }
        Test-Qa 'U-06' "$sid colours from the style-guide palette" 'palette only' "$($offPal.Count) off-palette" ($offPal.Count -eq 0) -Soft -Note (($offPal | Select-Object -First 25) -join '; ')

        # U-07 navigation + header band
        $nav = @($objs | Where-Object { $_.Id -match "^$($tag)_NAV_" })
        $navTargets = @{}
        foreach ($o in $objs) { foreach ($a in $o.Actions) { if ($a.Type -match 'ACTIVATE_SHEET|SHEET_ACTIVATE|ACTIVATESHEET') { foreach ($p in $a.Params) { $tgt = ($p -replace '^Document\\', ''); $navTargets[$tgt] = $o.Id } } } }
        $missingNav = @($ContractSheets.Keys | Where-Object { -not $navTargets.ContainsKey($_) })
        $badTgt = @($navTargets.Keys | Where-Object { -not ($sheetsAll | Where-Object Id -eq $_) })
        Test-Qa 'U-07' "$sid nav reaches every contract sheet" '7 targets' "$($navTargets.Count) targets" ($missingNav.Count -eq 0) -Note $(if ($missingNav) { 'missing: ' + ($missingNav -join ', ') } else { '' })
        Test-Qa 'U-07' "$sid nav targets exist" 'all exist' $(if ($badTgt) { $badTgt -join ', ' } else { 'all exist' }) ($badTgt.Count -eq 0)
        $navGeom = @($nav | Sort-Object L | ForEach-Object { "$($_.L),$($_.T),$($_.W),$($_.H)" })
        $navBad = @($nav | Where-Object { -not (Near $_.T 9) -or -not (Near $_.H 30) })
        Test-Qa 'U-07' "$sid nav buttons y=9 h=30 ($($tag)_NAV_*)" '7 buttons y=9 h=30' "$($nav.Count) buttons, $($navBad.Count) off" ($nav.Count -eq 7 -and $navBad.Count -eq 0) -Soft -Note (($navBad | ForEach-Object { "$($_.Id) [$(RectTxt $_)]" }) -join '; ')
        if ($sid -eq 'SH_DASH' -and $nav.Count) { ($navGeom | ConvertTo-Json) | Set-Content -Path $navRefFile -Encoding UTF8; $navRef = $navGeom }
        if ($navRef -and $sid -ne 'SH_DASH') { Test-Qa 'U-07' "$sid nav geometry identical to SH_DASH" ($navRef -join ' ') ($navGeom -join ' ') (($navRef -join ' ') -eq ($navGeom -join ' ')) -Soft }
        $selfBtn = $nav | Where-Object { @($_.Actions | Where-Object { ($_.Params -join ' ') -match "(^|\\| )$sid( |$)" }).Count } | ForEach-Object Id | Select-Object -First 1
        if ($selfBtn) { $bg = ($byId[$selfBtn].Colors | Where-Object Role -eq 'Bkg' | Select-Object -First 1).Hex; Test-Qa 'U-07' "$sid active nav button is Primary" '#2F6DB5' $bg ($bg -eq '#2F6DB5' -or $bg -eq 'calc') -Soft }
        $clear = @($objs | Where-Object { @($_.Actions | Where-Object { $_.Type -match 'CLEAR_ALL|CLEARALL' }).Count })
        $helpT = @($objs | Where-Object { @($_.Actions | Where-Object { $_.Type -match 'SET_VARIABLE|SETVARIABLE|SET_VALUE' -and ($_.Params -join ' ') -match 'vShowHelp' }).Count })
        Test-Qa 'U-07' "$sid header has Clear (Clear All) and Help toggle (vShowHelp)" 'both' "clear=$($clear.Count) help=$($helpT.Count)" ($clear.Count -ge 1 -and $helpT.Count -ge 1) -Soft
        $hdr = @($objs | Where-Object { $_.Id -match "^$($tag)_HDR_" -and $_.Type -eq 6 -and (Near $_.L 0) -and (Near $_.T 0) -and (Near $_.W 1690) -and (Near $_.H 48) })
        $hdrBg = if ($hdr) { ($hdr[0].Colors | Where-Object Role -eq 'Bkg' | Select-Object -First 1).Hex } else { $null }
        Test-Qa 'U-15' "$sid header band 0,0,1690,48 navy" '#1B2A41 band' $(if ($hdr) { "$($hdr[0].Id) $hdrBg" } else { 'missing' }) ($hdr.Count -ge 1 -and $hdrBg -eq '#1B2A41') -Soft
        $ttl = @($objs | Where-Object { $_.Id -match "^$($tag)_TTL(_|$)" } | Sort-Object T)
        $ttlTxt = if ($ttl) { (Get-EvalText ([string]$ttl[0].Text)) } else { '' }
        Test-Qa 'U-15' "$sid page title at 10,52 (TTL)" '10,52,620,22' $(if ($ttl) { "$($ttl[0].Id) [$(RectTxt $ttl[0])] '$ttlTxt'" } else { 'missing' }) ($ttl.Count -ge 1 -and (Near $ttl[0].L 10) -and (Near $ttl[0].T 52)) -Soft

        # U-08 help boxes
        $help = @($objs | Where-Object { $_.Type -eq 6 -and ($_.Id -match "^$($tag)_HELP_" -or ([string]$_.Text) -match 'What am I looking at' -or ([string]$_.Text).TrimStart().StartsWith($HelpGlyph)) })
        $sheetHelp = @($help | Where-Object { (Near $_.L 900) -and (Near $_.T 52) -and (Near $_.W 780) -and (Near $_.H 40) })
        Test-Qa 'U-08' "$sid has help/explanation boxes" '>= 1, sheet box at 900,52,780,40' "$($help.Count) boxes, sheet box: $($sheetHelp.Count)" ($help.Count -ge 1) -Note (($help | ForEach-Object { "$($_.Id) [$(RectTxt $_)]" }) -join '; ')
        if ($help.Count -ge 1 -and $sheetHelp.Count -eq 0) { Add-QaResult 'U-08' "$sid sheet-level help box position" '900,52,780,40' 'not found' 'WARN' }
        $helpNoCond = @($help | Where-Object { $_.ShowAlways -or ([string]$_.ShowExpr) -notmatch 'vShowHelp' })
        Test-Qa 'U-08' "$sid help boxes toggle with vShowHelp" 'show cond vShowHelp=1' "$($helpNoCond.Count) without" ($helpNoCond.Count -eq 0) -Soft -Note ($helpNoCond.Id -join ', ')
        $helpBg = @($help | Where-Object { ($_.Colors | Where-Object { $_.Role -eq 'Bkg' -and $_.Hex -ne '#EAF2FB' -and $_.Hex -ne 'calc' }) })
        Test-Qa 'U-08' "$sid help boxes InfoBg #EAF2FB" 'all' "$($helpBg.Count) differ" ($helpBg.Count -eq 0) -Soft -Note ($helpBg.Id -join ', ')

        # U-09 groups on Analysis sheets
        if ($sid -in $Analysis) {
            $used = @($objs | ForEach-Object { $_.Dims } | Where-Object { $_ -and $groups.ContainsKey([string]$_.Name) } | ForEach-Object { [string]$_.Name } | Sort-Object -Unique)
            $cyc = @($used | Where-Object { $groups[$_] }); $drl = @($used | Where-Object { -not $groups[$_] })
            $st = if ($cyc.Count -ge 1 -and $drl.Count -ge 1) { 'PASS' } elseif ($used.Count -ge 1) { 'WARN' } else { 'FAIL' }
            Add-QaResult 'U-09' "$sid uses cyclic and drill groups" '>=1 cyclic + >=1 drill' ("cyclic: {0} | drill: {1}" -f ($cyc -join ','), ($drl -join ',')) $st
        }
        if ($sid -in ($Analysis + @('SH_REPORT'))) {
            $flt = @($objs | Where-Object { $_.Id -match "^$($tag)_FLT_" -and $_.Type -eq 6 -and (Near $_.L 10) -and (Near $_.T 96) -and (Near $_.W 210) -and (Near $_.H 650) })
            $fltKinds = @($objs | Where-Object { $_.L -ge 10 -and ($_.L + $_.W) -le 222 -and $_.T -ge 96 } | ForEach-Object TypeName | Sort-Object -Unique)
            Test-Qa 'U-15' "$sid filter panel 10,96,210,650 with CS box, list boxes, multi box, search" 'panel + CurrentSelections, ListBox, MultiBox, SearchObject' ("panel={0}; {1}" -f $flt.Count, ($fltKinds -join ',')) ($flt.Count -ge 1 -and ($fltKinds -contains 'CurrentSelections') -and ($fltKinds -contains 'ListBox') -and ($fltKinds -contains 'MultiBox') -and ($fltKinds -contains 'SearchObject')) -Soft
        }

        # U-11 errors / empty / U-12 formats
        $errs = @(); $empty = @(); $fmtWarn = @()
        foreach ($o in $objs) {
            foreach ($s in @($o.Caption, $o.Title, $o.Text, $o.ShowExpr)) { if ($s -and $s.StartsWith('=')) { $e = QE $s.Substring(1); if ($e.IsErr) { $errs += "$($o.Id): '$s' -> $($e.Text)" } } }
            if ($o.TextEval -and ($o.TextEval -match 'Error in expression|^Error:|\$\(' )) { $errs += "$($o.Id) shows '$($o.TextEval)'" }
            foreach ($x in $o.Exprs) {
                if (-not $x.Enabled -or -not $x.Def) { continue }
                $def = $x.Def.TrimStart('=')
                $e = QE $def
                if ($e.IsErr -and $e.Text -notmatch 'Column|Above|Below|Before|After|RowNo|ColumnNo|Dimensionality|Top|Bottom|First|Last') { $errs += "$($o.Id) expr '$($x.Label)': $($e.Text)" }
                if ($o.Type -in $ChartTypes -and $o.Type -ne 22 -and $x.FmtType -in @('UNKNOWN', '', $null) -and $def -notmatch 'Num\s*\(|\$\(vFmt' -and $def -match 'Sum|Count|Avg|v[A-Z]') { $fmtWarn += "$($o.Id) '$($x.Label)'" }
            }
            if (($o.Type -in $ChartTypes -or $o.Type -eq 4) -and $o.ShowAlways -and $null -ne $o.Rows -and $o.Rows -le 0) { $empty += "$($o.Id) ($($o.TypeName))" }
        }
        Test-Qa 'U-11' "$sid no 'Error in expression' (captions, texts, chart expressions)" 'none' "$($errs.Count)" ($errs.Count -eq 0) -Note (($errs | Select-Object -First 15) -join ' || ')
        Test-Qa 'U-11' "$sid no empty charts/tables (no selections)" 'none' "$($empty.Count)" ($empty.Count -eq 0) -Note ($empty -join ', ')
        Test-Qa 'U-12' "$sid chart expressions have a number format" 'all set (or Num())' "$($fmtWarn.Count) default" ($fmtWarn.Count -eq 0) -Soft -Note (($fmtWarn | Select-Object -First 20) -join '; ')
        $kpiVals = @($objs | Where-Object { $_.Id -match '_KPI\d+_VAL' })
        $kpiNoUnit = @($kpiVals | Where-Object { ([string]$_.TextEval) -notmatch "$([regex]::Escape($QaEuro))|%|pp" })
        if ($kpiVals) { Test-Qa 'U-12' "$sid KPI values formatted with unit (EUR/%/pp)" 'all' "$($kpiNoUnit.Count) without unit" ($kpiNoUnit.Count -eq 0) -Soft -Note (($kpiVals | ForEach-Object { "$($_.Id)='$($_.TextEval)'" }) -join '; ') }

        # U-18 strict zero-defect scan (lead directive 14/10): texts, captions, KPI values, chart/table cell text
        $eu = [regex]::Escape($QaEuro)
        $hard = 'Error in expression|Allocated memory|^Error|NaN|\$\('
        $zeroEur = "$eu\s?-?0(?:[.,]0+)?(?:\s?[kKM])?(?![\d.,])"
        $rawNum = '(?<![\d.,:/\-A-Za-z])(?:\d{5,}(?![\d,])|\d+\.\d{4,})'
        $sHard = @(); $sZero = @(); $sKpi = @(); $sRaw = @(); $sCellZero = @()
        foreach ($o in $objs) {
            $vis = @(); foreach ($s0 in @($o.Caption, $o.Title)) { $t0 = Get-EvalText $s0; if ($t0) { $vis += $t0 } }
            if ($o.Type -eq 6) { if ($o.TextEval) { $vis += $o.TextEval } } elseif ($o.Type -eq 5) { $t0 = Get-EvalText $o.Text; if ($t0) { $vis += $t0 } }
            foreach ($t0 in $vis) {
                if ($t0 -match $hard) { $sHard += "$($o.Id): '$t0'" }
                if ($t0 -match $zeroEur) { $sZero += "$($o.Id): '$t0'" }
                if ($o.Type -eq 6 -and $t0 -match $rawNum) { $sRaw += "$($o.Id): '$($t0.Substring(0, [math]::Min(80, $t0.Length)))'" }
            }
            if ($o.Id -match '_KPI\d+_(VAL|DLT|CTX)$' -and $o.ShowAlways) { $tv = ([string]$o.TextEval).Trim(); if (-not $tv -or $tv -notmatch '\d') { $sKpi += "$($o.Id): '$tv'" } }
            if (($o.Type -in $ChartTypes -or $o.Type -eq 4) -and $null -ne $o.Rows -and $o.Rows -le 2000) {
                $tt = ''; try { $tt = [string]$o.Com.GetTableAsText($false) } catch {}
                foreach ($m in [regex]::Matches($tt, "[^\t\r\n]*(Error in expression|Allocated memory|NaN)[^\t\r\n]*")) { $sHard += "$($o.Id) cell: '$($m.Value)'" }
                $nz = [regex]::Matches($tt, "(?<=^|\t)$zeroEur(?=\t|\r|\n|$)", 'Multiline').Count; if ($nz) { $sCellZero += "$($o.Id): $nz cells" }
            }
        }
        Test-Qa 'U-18' "$sid no Error / Allocated memory / NaN / unexpanded `$(…) anywhere (texts, captions, chart cells)" 'none' "$($sHard.Count)" ($sHard.Count -eq 0) -Note (($sHard | Select-Object -First 15) -join ' || ')
        Test-Qa 'U-18' "$sid no '$QaEuro 0' in texts/captions/KPIs" 'none' "$($sZero.Count)" ($sZero.Count -eq 0) -Note (($sZero | Select-Object -First 15) -join ' || ')
        Test-Qa 'U-18' "$sid KPI value/delta/context texts not empty or '-'" 'none' "$($sKpi.Count)" ($sKpi.Count -eq 0) -Note ($sKpi -join ' || ')
        Test-Qa 'U-18' "$sid no raw unformatted numbers in text objects" 'none' "$($sRaw.Count)" ($sRaw.Count -eq 0) -Soft -Note (($sRaw | Select-Object -First 10) -join ' || ')
        if ($sCellZero) { Add-QaResult 'U-18' "$sid chart/table cells showing '$QaEuro 0' (review: legit zero or defect?)" 'review' ($sCellZero -join '; ') 'WARN' }

        # U-16 layout-spec conformance (designer's own spec: IDs, types, rects)
        $spec = @($LayoutSpec | Where-Object Sheet -eq $sid)
        if ($spec) {
            $miss = @(); $typeBad = @(); $rectBad = @()
            foreach ($e in $spec) {
                $o = $byId[$e.Id]
                if (-not $o) { $miss += $e.Id; continue }
                $allowed = Get-AllowedTypes $e.Type
                if ($allowed -and $allowed -notcontains $o.TypeName) { $typeBad += "$($e.Id): spec '$($e.Type)' vs $($o.TypeName)" }
                if ($e.Rect -and -not ((Near $o.L $e.Rect[0]) -and (Near $o.T $e.Rect[1]) -and (Near $o.W $e.Rect[2]) -and (Near $o.H $e.Rect[3]))) { $rectBad += "$($e.Id) [$(RectTxt $o)] spec [$($e.Rect -join ',')]" }
            }
            Test-Qa 'U-16' "$sid objects of layout-spec present" "$($spec.Count) specified" "$($spec.Count - $miss.Count) present" ($miss.Count -eq 0) -Note $(if ($miss) { 'missing: ' + ($miss -join ', ') } else { '' })
            Test-Qa 'U-16' "$sid object types as in layout-spec" 'all' "$($typeBad.Count) differ" ($typeBad.Count -eq 0) -Soft -Note ($typeBad -join '; ')
            Test-Qa 'U-16' "$sid object rects as in layout-spec (+-2 px)" 'all' "$($rectBad.Count) differ" ($rectBad.Count -eq 0) -Soft -Note (($rectBad | Select-Object -First 20) -join '; ')
            $extra = @($objs | Where-Object { $sid2 = $_.Id; -not ($spec | Where-Object Id -eq $sid2) } | ForEach-Object Id)
            Add-QaResult 'U-16' "$sid objects not in layout-spec" '-' $extra.Count 'INFO' (($extra | Select-Object -First 40) -join ', ')
        }

        # grid alignment of cards (10 px grid)
        $offGrid = @($objs | Where-Object { $_.Type -in ($ChartTypes + @(1, 2, 3, 4, 36)) -and $_.Id -notin $childIds -and (($_.L % 10) -ne 0 -or ($_.T % 10) -ne 0) } | ForEach-Object { "$($_.Id) [$(RectTxt $_)]" })
        Test-Qa 'U-03' "$sid cards on the 10 px grid" 'all' "$($offGrid.Count) off-grid" ($offGrid.Count -eq 0) -Soft -Note ($offGrid -join '; ')

        # P-04 calc time
        foreach ($o in $objs) { if ($null -ne $o.CalcMs) { $perf.Add([pscustomobject]@{ Sheet = $sid; Id = $o.Id; Type = $o.TypeName; Ms = $o.CalcMs }) } }
        $slow = @($objs | Where-Object { $_.CalcMs -gt 1000 })
        $vslow = @($objs | Where-Object { $_.CalcMs -gt 2000 })
        $st = if ($vslow) { 'FAIL' } elseif ($slow) { 'WARN' } else { 'PASS' }
        Add-QaResult 'P-04' "$sid object calc times" '<= 1000 ms (FAIL > 2000 ms)' ("max {0} ms" -f (($objs | Measure-Object CalcMs -Maximum).Maximum)) $st (($slow | ForEach-Object { "$($_.Id) $($_.CalcMs) ms" }) -join '; ')

        # object inventory for the report
        $appendix.Add(''); $appendix.Add("### $sid objects"); $appendix.Add('')
        $appendix.Add('| ID | Type | Rect | Zed | Caption / text | Calc ms | Rows |'); $appendix.Add('|---|---|---|---|---|---|---|')
        foreach ($o in ($objs | Sort-Object T, L)) {
            $lbl = if ($o.Type -in 5, 6) { [string]$o.Text } else { [string]$o.Caption }
            if ($lbl.Length -gt 60) { $lbl = $lbl.Substring(0, 60) + '...' }
            $appendix.Add("| $($o.Id) | $($o.TypeName) | $(RectTxt $o) | $($o.Zed) | $($lbl.Replace('|', '\|').Replace("`n", ' ').Replace("`r", ' ')) | $($o.CalcMs) | $($o.Rows) |")
        }
    }
} finally {
    if ($prevSheet) { try { $doc.ActivateSheetById($prevSheet) | Out-Null } catch {} }
    Exit-QaLock
}

# ================================================================= document level
if (-not $Sheet) {
    $types = @($allObjs.Values | ForEach-Object { $_ } | ForEach-Object TypeName | Sort-Object -Unique)
    Test-Qa 'U-10' 'Variety of object types (>= 15 distinct)' '>= 15' "$($types.Count): $($types -join ', ')" ($types.Count -ge 15)
}
$top = @($perf | Sort-Object Ms -Descending | Select-Object -First 10)
$appendix.Insert(0, ''); $appendix.Insert(1, '## Slowest objects (calc time)'); $appendix.Insert(2, ''); $appendix.Insert(3, '| Sheet | ID | Type | ms |'); $appendix.Insert(4, '|---|---|---|---|')
$k = 5; foreach ($p in $top) { $appendix.Insert($k, "| $($p.Sheet) | $($p.Id) | $($p.Type) | $($p.Ms) |"); $k++ }
$mem = $null; try { $mem = [math]::Round($app.GetCommittedMemory() / 1MB) } catch {}
$size = (Get-Item $QvDocPath).Length / 1MB
Add-QaResult 'P-03' 'Document size on disk / QV committed memory' '-' ("{0:n1} MB / {1} MB" -f $size, $mem) 'INFO' 'size is as of the last save'
Write-QaReport -Name $(if ($Sheet) { 'ui-' + ($Sheet -join '-') } else { 'ui' }) -Title "QA UI checks$(if ($Sheet) { ' - ' + ($Sheet -join ', ') })" -Appendix $appendix | Out-Null
