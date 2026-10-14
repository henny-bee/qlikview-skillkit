# lib-qv.ps1 - reusable QlikView 12 COM builder library (owned by Designer)
# Usage (in a build script):
#   . "$PSScriptRoot\..\tools\lib-qv.ps1"   (from _build\build\build-SH_X.ps1)
#   Enter-QvLock -Owner designer; try { $doc = Get-QvDoc; $sh = Reset-QvSheet $doc 'SH_X' 'Name'; ... } finally { Exit-QvLock -Owner designer }
# Conventions:
#   * This file is ASCII-only. Non-ASCII glyphs come from $QS.Glyph (built with [char]) or Chr() inside QlikView expressions.
#   * Every object gets an explicit ID '<SHEETTAG>_<NAME>' (e.g. DASH_KPI_NS). Rects are pixels at 100% zoom: @(Left,Top,Width,Height).
#   * Colours are hex strings '#RRGGBB' from $QS.C (see spec/style-guide.md).
#   * In PowerShell, COM properties are called like methods only when they take parameters; plain props work as properties.

. "$PSScriptRoot\qvcom.ps1"

# ---- trace log (_build\logs\build.log): one line per build step, so slow or hanging steps can be found ----
$Global:QvTraceFile = Join-Path $QvBuildRoot 'logs\build.log'
$Global:QvTraceT0 = Get-Date
function Write-QvTrace([string]$Msg) {
    $dir = Split-Path $QvTraceFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Add-Content -Path $QvTraceFile -Value ("{0:HH:mm:ss.fff} +{1,6:0.0}s {2}" -f (Get-Date), ((Get-Date) - $QvTraceT0).TotalSeconds, $Msg)
}

# Refreshes the COM lock timestamp if THIS process holds it (whatever the owner name: designer-a, designer-b, engineer...).
function Update-QvMyLock {
    $f = Join-Path $QvLockDir 'owner.txt'
    try {
        $c = (Get-Content $f -Raw -ErrorAction Stop).Trim()
        if ($c -match '^(\S+) .*pid=(\d+)$' -and [int]$Matches[2] -eq $PID) { Set-Content -Path $f -Value "$($Matches[1]) $(Get-Date -Format o) pid=$PID" }
    } catch {}
}

# ======================================================================================================
# Style tokens (mirror of spec/style-guide.md - change here and in the guide together)
# ======================================================================================================
$Global:QS = @{
    Font      = 'Segoe UI'
    FontSemi  = 'Segoe UI Semibold'
    C = @{
        Navy       = '#1B2A41'   # header band
        Navy2      = '#2A3D5A'   # nav button (inactive)
        NavText    = '#C9D4E3'   # nav text (inactive)
        Primary    = '#2F6DB5'   # CY / main series / active nav
        PrimaryLt  = '#8DB6E2'   # light primary (2nd series, hover-ish)
        PY         = '#B4BFCB'   # prior year / comparison
        Budget     = '#E39B2D'   # budget / target
        Good       = '#2E9D6A'
        Bad        = '#D64545'
        Warn       = '#E39B2D'
        Canvas     = '#F2F4F7'   # sheet background
        Card       = '#FFFFFF'   # object background
        Border     = '#DCE2EA'   # 1px card border / grid lines
        Grid       = '#E9EDF2'   # chart grid lines
        Text       = '#1F2933'   # main text
        Muted      = '#6B7785'   # secondary text, labels
        Panel      = '#E6EBF1'   # filter panel background
        PanelHead  = '#D5DDE7'
        InfoBg     = '#EAF2FB'   # help box
        InfoBorder = '#B9D3EE'
        InfoText   = '#34506F'
        White      = '#FFFFFF'
    }
    # categorical series palette (8) - first is Primary
    Cat = @('#2F6DB5','#5AA3D8','#2E9D6A','#E39B2D','#8C6BB1','#D64545','#4DB6AC','#9AA5B1')
    Glyph = @{
        Eur   = [string][char]0x20AC
        Up    = [string][char]0x25B2
        Down  = [string][char]0x25BC
        Dot   = [string][char]0x25CF
        Info  = [string][char]0x24D8
        Mid   = [string][char]0x00B7
        Dash  = [string][char]0x2013
        Arrow = [string][char]0x2192
    }
    Canvas = @{ W = 1690; H = 755 }
}
$Global:QS.FmtMoney = $QS.Glyph.Eur + ' #,##0'
# Example of a FIXED colour per dimension value (same colour on every chart). Make one per categorical dimension you chart:
$Global:QS.ChannelColorExpr = "Pick(Match(Only(Channel),'Direct Sales','Distributor','E-Commerce','Retail Partner'), RGB(47,109,181), RGB(90,163,216), RGB(46,157,106), RGB(227,155,45))"

$Global:QS.FmtMoneyM = $QS.Glyph.Eur + ' #,##0.0'
$Global:QS.FmtPct   = '0.0%'
$Global:QS.FmtInt   = '#,##0'

# ======================================================================================================
# Colour / font helpers
# ======================================================================================================
function ConvertFrom-QvHex([string]$Hex) {
    $h = $Hex.TrimStart('#')
    return @([Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16))
}
# COM colour int = COLORREF (R + G*256 + B*65536)
function ConvertTo-QvColorRef([string]$Hex) { $c = ConvertFrom-QvHex $Hex; return [int]($c[0] + $c[1]*256 + $c[2]*65536) }
# QlikView RGB() expression for a hex colour (for calculated colours)
function Get-QvRgbExpr([string]$Hex) { $c = ConvertFrom-QvHex $Hex; "RGB($($c[0]),$($c[1]),$($c[2]))" }

# IColorDef (Col + IsCalculated + ColorExpr)
function Set-QvColDef {
    param($ColDef, [string]$Hex, [string]$Expr)
    if ($Hex) { $ColDef.Col = ConvertTo-QvColorRef $Hex }
    if ($Expr) { $ColDef.IsCalculated = $true; $ColDef.ColorExpr.v = $Expr } else { $ColDef.IsCalculated = $false }
}
# IColorAreaDef (Mode, PrimaryCol, SecondaryCol, Alpha) - solid fill
function Set-QvColorArea {
    param($Area, [string]$Hex, [string]$Expr, [int]$Alpha = 255)
    try { $Area.Mode = 0 } catch {}
    Set-QvColDef $Area.PrimaryCol $Hex $Expr
    try { $Area.Alpha = $Alpha } catch {}
}
function Set-QvFontDef {
    param($Font, [double]$Size = 9, [switch]$Bold, [switch]$Italic, [string]$Name = $QS.Font)
    $Font.FontName = $Name; $Font.PointSize1000 = [int]($Size * 1000); $Font.Bold = [bool]$Bold; $Font.Italic = [bool]$Italic; $Font.Underline = $false
}

# ======================================================================================================
# Frame helpers (every sheet object has a Frame somewhere in its properties)
# ======================================================================================================
function Get-QvFrame($Props) {
    foreach ($path in 'GraphLayout','Layout') {
        try { $f = $Props.$path.Frame; if ($f) { return $f } } catch {}
    }
    return $Props.Frame
}
# Flat card look: white background, thin border colour, no rounded corners, no shadow, Segoe UI caption.
function Set-QvFrameStyle {
    param($Frame, [string]$Caption, [switch]$NoCaption, [string]$Bg = $QS.C.Card, [int]$BgAlpha = 255,
          [int]$BorderWidth = 1, [string]$BorderColor = $QS.C.Border, [double]$FontSize = 9, [double]$CaptionSize = 9.5,
          [string]$HelpText, [string]$ShowCond, [switch]$KeepIcons, [string]$CaptionBg = $QS.C.Card, [string]$CaptionFg = $QS.C.Text)
    if ($Caption -ne $null -and $Caption -ne '') { $Frame.Name.v = $Caption }
    $Frame.ShowCaption = -not $NoCaption -and ($Caption -ne $null -and $Caption -ne '')
    $Frame.BorderWidth = $BorderWidth
    try { $Frame.BorderEffect = 0 } catch {}
    try { $Frame.ShadowIntensity = 0 } catch {}
    $Frame.RoundedShape = $false
    $Frame.FixCorner = $true; $Frame.FixCornerSize = 0
    Set-QvColorArea $Frame.Color $BorderColor
    Set-QvFontDef $Frame.Font $FontSize
    Set-QvFontDef $Frame.CaptionFont $CaptionSize -Bold
    # caption colours: inactive + active identical (calm)
    Set-QvColorArea $Frame.BgColor $CaptionBg;       Set-QvColorArea $Frame.ActiveBgColor $CaptionBg
    Set-QvColorArea $Frame.FgColor $CaptionFg;       Set-QvColorArea $Frame.ActiveFgColor $CaptionFg
    try { $Frame.Background.UseColor = $true; Set-QvColorArea $Frame.Background.Color $Bg -Alpha $BgAlpha } catch {}
    if (-not $KeepIcons) {
        foreach ($i in 'AllowMinimize','AllowMaximize','PrintIcon','XLIcon','CopyIcon','SearchIcon','ClearIcon','LockIcon','MenuIcon','SelectAllIcon','SelectPossibleIcon','SelectExcludedIcon','ClearOtherIcon','CopyImageIcon') { try { $Frame.$i = $false } catch {} }
    }
    if ($HelpText) { $Frame.HelpText.v = $HelpText; try { $Frame.AllowInfo = $true } catch {} }
    if ($ShowCond) { $Frame.Show.Always = $false; $Frame.Show.Expression.v = $ShowCond } else { $Frame.Show.Always = $true }
}

# ======================================================================================================
# Object basics: ID, rect, removal
# ======================================================================================================
function Set-QvRect($Obj, [int[]]$Rect) {
    $r = $Obj.GetRect(); $r.Left = $Rect[0]; $r.Top = $Rect[1]; $r.Width = $Rect[2]; $r.Height = $Rect[3]; $Obj.SetRect($r)
}
function Get-QvObj($Doc, [string]$Id) {
    $full = if ($Id -like 'Document\*') { $Id } else { "Document\$Id" }
    try { return $Doc.GetSheetObject($full) } catch { return $null }
}
function Remove-QvObj($Doc, [string]$Id) {
    $o = Get-QvObj $Doc $Id
    if ($o) { $o.Close() }
}
# Applies ObjectId + frame style + rect in one go. $Configure is a scriptblock receiving ($props) for type-specific settings.
function Complete-QvObj {
    param($Doc, $Obj, [string]$Id, [int[]]$Rect, [hashtable]$Frame = @{}, [scriptblock]$Configure)
    $full = "Document\$Id"
    Write-QvTrace "obj $Id : configure"
    Update-QvMyLock
    $existing = Get-QvObj $Doc $Id
    if ($null -ne $existing -and $existing.GetObjectId() -ne $Obj.GetObjectId()) { $existing.Close() }
    $p = $Obj.GetProperties()
    $f = Get-QvFrame $p
    $f.ObjectId = $full
    Set-QvFrameStyle -Frame $f @Frame
    if ($Configure) { & $Configure $p }
    Write-QvTrace "obj $Id : SetProperties"
    $Obj.SetProperties($p)
    if ($Obj.GetObjectId() -ne $full) { throw "Object id not applied: wanted $full, got $($Obj.GetObjectId())" }
    if ($Rect) { Set-QvRect $Obj $Rect }
    Write-QvTrace "obj $Id : done"
    return $Obj
}

# ======================================================================================================
# Sheets
# ======================================================================================================
function Get-QvSheetById($Doc, [string]$SheetId) {
    for ($i = 0; $i -lt $Doc.NoOfSheets(); $i++) {
        $s = $Doc.GetSheet($i)
        if ($s.GetProperties().SheetId -eq "Document\$SheetId") { return $s }
    }
    return $null
}
# A blank, temporary sheet that stays active while a sheet is (re)built. Objects on an inactive sheet are not
# calculated, so each COM call returns fast (otherwise every call waits for QlikView to recalc the visible sheet).
function Enter-QvParking($Doc) {
    $pk = Get-QvSheetById $Doc 'ZZ_designer_Park'
    if (-not $pk) {
        $pk = $Doc.CreateSheet(); $pp = $pk.GetProperties(); $pp.Name = 'ZZ_designer_Park (build in progress)'; $pp.SheetId = 'Document\ZZ_designer_Park'; $pk.SetProperties($pp)
        $pk = Get-QvSheetById $Doc 'ZZ_designer_Park'
    }
    $pk.Activate()
    Write-QvTrace 'parking sheet active'
}
function Exit-QvParking($Doc, [string]$ActivateId) {
    if ($ActivateId) { $s = Get-QvSheetById $Doc $ActivateId; if ($s) { $s.Activate() } }
    $pk = Get-QvSheetById $Doc 'ZZ_designer_Park'
    if ($pk) { $pk.Remove() }
    Write-QvTrace 'parking sheet removed'
}

# Creates the sheet if missing (or adopts $AdoptId, e.g. SH01), removes all its objects, applies sheet styling.
function Reset-QvSheet {
    param($Doc, [string]$SheetId, [string]$Name, [string]$AdoptId, [string]$TabColor = $QS.C.Navy, [string]$TabText = $QS.C.White, [string]$ShowCond)
    $sh = Get-QvSheetById $Doc $SheetId
    if (-not $sh -and $AdoptId) { $sh = Get-QvSheetById $Doc $AdoptId }
    if (-not $sh) { $sh = $Doc.CreateSheet() }
    # remove objects (iterate backwards)
    $objs = $sh.GetSheetObjects()
    for ($i = $objs.Count - 1; $i -ge 0; $i--) { try { $objs[$i].Close() } catch { Write-Warning "close failed: $_" } }
    $p = $sh.GetProperties()
    $p.Name = $Name
    $p.SheetId = "Document\$SheetId"
    $p.UseApplicationBkg = $false
    $p.UseColorBkg = $true
    Set-QvColorArea $p.BkgColor $QS.C.Canvas
    Set-QvFontDef $p.SheetFont 9
    try {
        $p.TabAttr.Mode = 2
        Set-QvColorArea $p.TabAttr.BgColor $TabColor
        Set-QvColorArea $p.TabAttr.FgColor $TabText
    } catch { Write-Warning "tab colour: $_" }
    if ($ShowCond) { $p.Show.Always = $false; $p.Show.Expression.v = $ShowCond }
    $sh.SetProperties($p)
    return (Get-QvSheetById $Doc $SheetId)
}
function Remove-QvSheet($Doc, [string]$SheetId) {
    $sh = Get-QvSheetById $Doc $SheetId
    if ($sh) { $sh.Remove() }
}

# ======================================================================================================
# Text objects (labels, panels, KPI tiles, help boxes)
# ======================================================================================================
# HAlign: 0 left, 1 centre, 2 right.  VAlign: 0 top, 4 centre, 8 bottom (Win32 DT_ flags; verified in sandbox)
function New-QvText {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Text = '',
          [string]$Bg = $QS.C.Card, [int]$BgAlpha = 255, [string]$Fg = $QS.C.Text, [string]$FgExpr,
          [double]$Size = 9, [switch]$Bold, [switch]$Italic, [string]$FontName = $QS.Font,
          [int]$HAlign = 0, [int]$VAlign = 4, [int]$Margin = 4,
          [int]$BorderWidth = 0, [string]$BorderColor = $QS.C.Border,
          [string]$Caption, [string]$ShowCond, [string]$HelpText, [string]$BgExpr, [array]$Actions, [int]$Layer = 0)
    $o = $Sheet.CreateTextObject()
    $frameArgs = @{ BorderWidth = $BorderWidth; BorderColor = $BorderColor; Bg = $Bg; BgAlpha = $BgAlpha; FontSize = $Size }
    if ($Caption) { $frameArgs.Caption = $Caption } else { $frameArgs.NoCaption = $true }
    if ($ShowCond) { $frameArgs.ShowCond = $ShowCond }
    if ($HelpText) { $frameArgs.HelpText = $HelpText }
    $o = Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $frameArgs -Configure {
        param($p)
        $L = $p.Layout
        $L.Text.v = $Text
        Set-QvFontDef $L.Frame.Font $Size -Bold:$Bold -Italic:$Italic -Name $FontName
        Set-QvColorArea $L.TextColor $Fg $FgExpr
        Set-QvColorArea $L.BkgColor $Bg $BgExpr -Alpha $BgAlpha
        $L.BkgAlpha = $BgAlpha
        $L.TextAdjustHorizontal = $HAlign; $L.TextAdjustVertical = $VAlign
        $L.TopMargin = $Margin; $L.BottomMargin = $Margin; $L.LeftMargin = $Margin; $L.RightMargin = $Margin
        if ($Actions) { Add-QvActions $L.ActionItems $Actions }
    }
    if ($Layer -ne 0) { $o.SetLayer($Layer) }
    return $o
}

# Actions: array of @{ Type = 'sheet'|'clear'|'setvar'|'bookmark'|'back'|'forward'|'clearfield'|'select'; P = @('param1','param2') }
$Global:QvActionCode = @{ clear = 4; back = 6; forward = 7; bookmark = 14; sheet = 18; setvar = 31; select = 32; clearfield = 36; clearother = 26; lockall = 2; unlockall = 3 }
function Add-QvActions($ActionItems, [array]$Actions) {
    while ($ActionItems.Count -gt 0) { $ActionItems.RemoveAt(0) }
    foreach ($a in $Actions) {
        [void]$ActionItems.Add()
        $ai = $ActionItems.Item($ActionItems.Count - 1)
        $ai.Type = $QvActionCode[$a.Type]
        foreach ($prm in @($a.P)) { if ($prm -ne $null) { [void]$ai.Parameters.Add(); $ai.Parameters.Item($ai.Parameters.Count - 1).v = [string]$prm } }
    }
}

# ======================================================================================================
# Buttons
# ======================================================================================================
function New-QvButton {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Text, [array]$Actions,
          [string]$Bg = $QS.C.Primary, [string]$BgExpr, [string]$Fg = $QS.C.White, [string]$FgExpr,
          [double]$Size = 9, [switch]$Bold, [string]$ShowCond, [string]$HelpText, [string]$EnableCond)
    $o = $Sheet.CreateButton()
    $frameArgs = @{ NoCaption = $true; BorderWidth = 0; Bg = $Bg; FontSize = $Size }
    if ($ShowCond) { $frameArgs.ShowCond = $ShowCond }
    if ($HelpText) { $frameArgs.HelpText = $HelpText }
    return Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $frameArgs -Configure {
        param($p)
        $p.Text.v = $Text
        $p.BtnStyle = 1   # BS_PLAIN (flat)
        Set-QvFontDef $p.Frame.Font $Size -Bold:$Bold
        Set-QvColorArea $p.TextColor $Fg $FgExpr
        Set-QvColorArea $p.BkgColor $Bg $BgExpr
        $p.BkgAlpha = 255
        if ($EnableCond) { $p.EnableCondition.v = $EnableCond }
        if ($Actions) { Add-QvActions $p.ActionItems $Actions }
    }
}

# ======================================================================================================
# Number formats
# ======================================================================================================
# Kind: money | moneyM | pct | pp | int | dec1 | raw (expression default) | '<custom format>'
function Set-QvNumFmt($NumPres, [string]$Kind) {
    if (-not $Kind) { return }
    $NumPres.Dec = '.'; $NumPres.Thou = ','; $NumPres.UseThou = 1
    switch ($Kind) {
        'money' { $NumPres.Type = 12; $NumPres.nDec = 0; $NumPres.Fmt = $QS.FmtMoney }
        'pct'   { $NumPres.Type = 11; $NumPres.nDec = 1; $NumPres.Fmt = '0.0%' }
        'pct0'  { $NumPres.Type = 11; $NumPres.nDec = 0; $NumPres.Fmt = '0%' }
        'int'   { $NumPres.Type = 10; $NumPres.nDec = 0; $NumPres.Fmt = '#,##0' }
        'dec1'  { $NumPres.Type = 11; $NumPres.nDec = 1; $NumPres.Fmt = '#,##0.0' }
        'growth'{ $NumPres.Type = 11; $NumPres.nDec = 1; $NumPres.Fmt = '+0.0%;-0.0%' }
        'pp'    { $NumPres.Type = 11; $NumPres.nDec = 1; $NumPres.Fmt = '+0.0 pp;-0.0 pp' }
        'moneyM'  { $NumPres.Type = 11; $NumPres.nDec = 0; $NumPres.Fmt = $QS.Glyph.Eur + ' #,##0 M' }     # value already / 1e6
        'moneyM1' { $NumPres.Type = 11; $NumPres.nDec = 1; $NumPres.Fmt = $QS.Glyph.Eur + ' #,##0.0 M' }   # value already / 1e6
        'raw'   { $NumPres.Type = 0 }
        default { $NumPres.Type = 2; $NumPres.Fmt = $Kind }
    }
}

# ======================================================================================================
# Charts
# ======================================================================================================
# Type: bar line combo pie scatter grid gauge radar mekko funnel block pivot straight
# Dims : array of strings or hashtables @{ F='Field|group|=calc'; L='Label'; Limit='vTopN' (largest N); SortExpr='...'; SortDesc=$true; NoNull=$true }
# Exprs: array of hashtables
#   @{ D='def'; L='label'; Fmt='money|pct|int|growth|pp|raw|<fmt>'; Color='#hex'; ColorExpr='RGB(...)'; TextColorExpr='...';
#      Mode='bar|line|symbol|linesymbol'; Right=$true (secondary axis); Invisible=$true;
#      Repr='minichart|traffic|lineargauge|circgauge|digits'; Gauge=@{Min='0';Max='1';Seg=@(@('0','#D64545'),@('0.95','#E39B2D'),@('1','#2E9D6A'))};
#      Mini=@{ Dim='YearMonth'; Mode='line|bar' };
#      Cycle=@( @{D=...;L=...;Fmt=...}, ... )   # cyclic expression group members after the first
#      Sort=$true (sort chart by this expression, desc) }
$Global:QvChartCreate = @{ bar='CreateBarChart'; line='CreateLineChart'; combo='CreateComboChart'; pie='CreatePieChart'; scatter='CreateScatterChart';
    grid='CreateGridChart'; gauge='CreateGaugeChart'; radar='CreateRadarChart'; pivot='CreatePivotTable'; straight='CreateStraightTable';
    mekko='CreateBarChart'; funnel='CreateBarChart'; block='CreateBarChart' }
$Global:QvGraphMode = @{ mekko = 12; funnel = 11; block = 10 }

function Set-QvExprCommon($e, [hashtable]$x, [string]$Type) {
    # NoTotal=$true: the total row stays empty (used for mini-chart columns; QlikView would print the raw total number)
    $e.Data.ExpressionData.Definition.v = $(if ($x.NoTotal) { "If(Dimensionality()=0, Null(), $($x.D))" } else { $x.D })
    if ($x.L) { $e.Data.ExpressionVisual.Label.v = $x.L }
    if ($x.Fmt) { Set-QvNumFmt $e.Data.ExpressionVisual.NumberPresentation $x.Fmt }
    if ($x.Color) { $e.Data.AttributeExpressions.BkgColorExp.Definition.v = (Get-QvRgbExpr $x.Color) }
    if ($x.ColorExpr) { $e.Data.AttributeExpressions.BkgColorExp.Definition.v = $x.ColorExpr }
    if ($x.TextColorExpr) { $e.Data.AttributeExpressions.TextColorExp.Definition.v = $x.TextColorExpr }
    if ($x.TextFmtExpr) { $e.Data.AttributeExpressions.TextFmtExp.Definition.v = $x.TextFmtExpr }
    if ($x.Invisible) { $e.Data.ExpressionVisual.Invisible = $true }
    if ($x.Comment) { $e.Data.ExpressionData.Comment = $x.Comment }
    if ($x.Relative) { $e.Data.ExpressionData.Relative = $true }
    $v = $e.Data.ExpressionVisual
    switch ($x.Mode) {
        'bar'        { $v.ShowAsBar = $true;  $v.ShowAsLine = $false; $v.ShowAsSymbol = $false }
        'line'       { $v.ShowAsBar = $false; $v.ShowAsLine = $true;  $v.ShowAsSymbol = $false }
        'symbol'     { $v.ShowAsBar = $false; $v.ShowAsLine = $false; $v.ShowAsSymbol = $true }
        'linesymbol' { $v.ShowAsBar = $false; $v.ShowAsLine = $true;  $v.ShowAsSymbol = $true }
    }
    if ($x.Right) { $v.PrimaryAxis = $false }
    # values on data points: OFF unless asked (QlikView 12 defaults them to ON for new expressions)
    $v.ShowAsTextInChart = [bool]$x['Values']
    # axis styling for this expression (y axis)
    $ax = $e.Data.AxisData
    Set-QvFontDef $ax.Font 8
    Set-QvColorArea $ax.TextColor $QS.C.Muted
    Set-QvColorArea $ax.Color $QS.C.Border
    $ax.Grid = [bool]($Type -in 'bar','line','combo','scatter') -and -not $x.Right
    if ($x['NoAxis']) { $ax.Show = $false }            # e.g. radar scale labels
    if ($x['NoForce0']) { $ax.Force0 = $false }        # e.g. scatter axes (avoid 0%/0% collision at the origin)
    if ($x.AxisMin) { $ax.Min.v = $x.AxisMin }
    if ($x.AxisMax) { $ax.Max.v = $x.AxisMax }
    if ($x.Fmt) { Set-QvNumFmt $ax.NumberPresentation $x.Fmt }
    # cell representation (tables)
    switch ($x.Repr) {
        'traffic'     { $v.ImageRepresentation.Presentation = 5 }
        'circgauge'   { $v.ImageRepresentation.Presentation = 3 }
        'lineargauge' { $v.ImageRepresentation.Presentation = 4 }
        'digits'      { $v.ImageRepresentation.Presentation = 6 }
        'minichart'   { $v.ImageRepresentation.Presentation = 7 }
    }
    if ($x.Gauge) { Set-QvGaugeSettings $v.GaugeSettings $x.Gauge }
    if ($x.Mini) {
        $mc = $v.MiniChartCellSettings
        while ($mc.Dimension.Count -gt 0) { $mc.Dimension.RemoveAt(0) }
        [void]$mc.Dimension.Add(); $mc.Dimension.Item(0).Name = $x.Mini.Dim
        $lay = $mc.Layout
        if ($x.Mini.Mode -eq 'bar') { $lay.GraphMode = 0; $lay.ShowAsBar = $true; $lay.ShowAsLine = $false }
        else { $lay.GraphMode = 4; $lay.ShowAsLine = $true; $lay.ShowAsBar = $false; $lay.ShowAsSymbol = $false }
        foreach ($an in 'XAxis','YAxis') { try { Set-QvFontDef $lay.$an.Font 8 } catch {} }
        $lay.HighlightMaxPoint = $false; $lay.HighlightMinPoint = $false; $lay.HighlightEndPoint = $true
        try { Set-QvColorArea $lay.EndColor $QS.C.Primary; Set-QvColorArea $lay.MaxColor $QS.C.Good; Set-QvColorArea $lay.MinColor $QS.C.Bad } catch {}
        try { [void]$lay.ColorMap.Count; if ($lay.ColorMap.Count -gt 0) { Set-QvColorArea $lay.ColorMap.Item(0) $QS.C.Primary } } catch {}
    }
    if ($x.ColWidth) { $v.ColWidth = $x.ColWidth }
}

# Gauge settings: @{ Min='0'; Max='1'; Seg=@( @('lowerBound','#hex','name'), ... ); Mode=... ; NoScale=$true }
function Set-QvGaugeSettings($GS, [hashtable]$Cfg) {
    if ($Cfg.Min -ne $null) { $GS.GaugeMin.v = [string]$Cfg.Min }
    if ($Cfg.Max -ne $null) { $GS.GaugeMax.v = [string]$Cfg.Max }
    if ($Cfg.Seg) {
        $segs = $GS.GaugeSegments
        while ($segs.Count -gt $Cfg.Seg.Count) { $segs.RemoveAt($segs.Count - 1) }
        while ($segs.Count -lt $Cfg.Seg.Count) { [void]$segs.Add() }
        for ($i = 0; $i -lt $Cfg.Seg.Count; $i++) {
            $s = $segs.Item($i); $d = $Cfg.Seg[$i]
            $s.LowerBound.v = [string]$d[0]
            Set-QvColorArea $s.Color $d[1]
            if ($d.Count -gt 2) { $s.Name.v = $d[2] }
        }
        $GS.AutoSegmentWidth = $false
    }
    $GS.HideOutlines = $true
    $GS.HideBoundaries = $true
    if ($Cfg.NoScale) { $GS.ShowGaugeScale = $false; $GS.ShowGaugeLabels = $false }
    if ($Cfg.Ticks) { $GS.GaugeTickCount = $Cfg.Ticks }
    if ($Cfg.Span) { $GS.GaugeSpan = $Cfg.Span }
    if ($Cfg.Fill) { $GS.GaugeFillToValue = $true }
    if ($Cfg.Indicator) { Set-QvColorArea $GS.GaugeIndicatorColor $Cfg.Indicator }
    if ($Cfg.IndicatorWidth) { $GS.GaugeIndicatorWidth = $Cfg.IndicatorWidth }
    if ($Cfg.LedCount) { $GS.GaugeLEDCount = $Cfg.LedCount }
    if ($Cfg.SingleLed) { $GS.GaugeSingleLed = $true }
}

function New-QvChart {
    param($Doc, $Sheet, [string]$Id, [Parameter(Mandatory)][string]$Type, [int[]]$Rect, [string]$Caption,
          [array]$Dims = @(), [array]$Exprs = @(), [switch]$Legend, [int]$LegendPos = 3, [switch]$Horizontal, [switch]$Stacked,
          [string]$HelpText, [string]$ShowCond, [string]$CalcCond, [string[]]$Colors, [switch]$NoCaption, [switch]$XL,
          [switch]$Maximize, [hashtable]$Gauge, [int]$GaugeMode = 4, [array]$Texts, [switch]$NoXAxis, [switch]$Values,
          [int]$LineWidth = 2, [scriptblock]$Configure, [string]$Bg = $QS.C.Card, [int]$BgAlpha = 255, [switch]$Totals, [double]$FontSize = 0, [string]$YUnit, [int]$YUnitTop = 38)
    Write-QvTrace "chart $Id ($Type): create"
    $o = $Sheet.($QvChartCreate[$Type])()
    $tmpId = $o.GetObjectId()
    if ($QvGraphMode.ContainsKey($Type)) {
        $p = $o.GetProperties(); $p.GraphLayout.GraphMode = $QvGraphMode[$Type]; $o.SetProperties($p)
        $o = $Doc.GetSheetObject($tmpId)
    }
    # dimensions via methods (fields and groups), calculated ones via properties
    foreach ($d in $Dims) {
        $f = if ($d -is [hashtable]) { $d.F } else { [string]$d }
        if ($f.StartsWith('=')) { continue }
        if ($f -match '^(cyc|drl)_') { [void]$o.AddGroupDimension($f) } else { [void]$o.AddDimension($f) }
    }
    Write-QvTrace "chart $Id : dims added"
    foreach ($x in $Exprs) { [void]$o.AddExpression($x.D) }
    Write-QvTrace "chart $Id : exprs added" 
    $frameArgs = @{ Bg = $Bg; BgAlpha = $BgAlpha }
    if ($FontSize -gt 0) { $frameArgs.FontSize = $FontSize }
    if ($Caption -and -not $NoCaption) { $frameArgs.Caption = $Caption } else { $frameArgs.NoCaption = $true }
    if ($HelpText) { $frameArgs.HelpText = $HelpText }
    if ($ShowCond) { $frameArgs.ShowCond = $ShowCond }
    # y-axis unit label (QlikView ignores text in axis number formats such as 'EUR #,##0 M'): small muted text above the axis
    if ($YUnit) { $Texts = @($Texts | Where-Object { $_ }) + @(@{ T = $YUnit; P = @(4, $YUnitTop, 44, 14); Size = 8; Color = $QS.C.Muted; Align = 0 }) }
    $chartUserCfg = $Configure   # NB: inside the scriptblock below '$Configure' would resolve to Complete-QvObj's own parameter
    $o = Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $frameArgs -Configure {
        param($p)
        $fr = $p.GraphLayout.Frame
        if ($XL) { $fr.XLIcon = $true }
        if ($Maximize) { $fr.AllowMaximize = $true }
        $fr.AllowMinimize = $false
        # calculated dimensions + labels/limits for all dimensions
        # NB: field/group dims were added first (in order) by AddDimension; calculated dims are appended after them.
        $di = 0
        foreach ($d in $Dims) {
            $h = if ($d -is [hashtable]) { $d } else { @{ F = [string]$d } }
            if ($h.F.StartsWith('=')) { [void]$p.Dimensions.Add(); $dd = $p.Dimensions.Item($p.Dimensions.Count - 1); $dd.PseudoDef.Name = $h.F }
            else { $dd = $p.Dimensions.Item($di); $di++ }
            if ($h.L) { $dd.Title.v = $h.L }
            if ($h.NoNull -or $h.F.StartsWith('=')) { $dd.NullSuppression = $true }
            if ($h.Limit) { try { $dd.MaxNumShown.v = $h.Limit } catch { Write-Warning "dim limit: $_" } }
            if ($h.SortExpr) { $sc = $dd.SortCriteria; $sc.SortByExpression = $(if ($h.SortDesc) { -1 } else { 1 }); $sc.Expression.v = $h.SortExpr; $sc.SortByNumeric = 0; $sc.SortByAscii = 0; $sc.SortByLoadOrder = 0 }
            if ($h.ColWidth) { try { $dd.ColWidth = $h.ColWidth } catch { Write-QvTrace "dim ColWidth: $_" } }
        }
        # expressions
        for ($i = 0; $i -lt $Exprs.Count; $i++) {
            $x = $Exprs[$i]
            $grp = $p.Expressions.Item($i)
            Write-QvTrace "chart $Id : expr $i"
            Set-QvExprCommon $grp.Item(0) $x $Type
            if ($x['Values'] -or $Values) { $grp.Item(0).Data.ExpressionVisual.ShowAsTextInChart = $true }
            if ($x.Cycle) {
                foreach ($c in $x.Cycle) {
                    [void]$grp.Add()
                    $m = $grp.Item($grp.Count - 1)
                    $cc = @{}; foreach ($k in $x.Keys) { if ($k -notin 'Cycle','D','L','Fmt') { $cc[$k] = $x[$k] } }
                    foreach ($k in $c.Keys) { $cc[$k] = $c[$k] }
                    Set-QvExprCommon $m $cc $Type
                }
            }
        }
        Write-QvTrace "chart $Id : chartprops"
        $cp = $p.ChartProperties
        # Caption fix (round 2): a chart's caption comes from GraphLayout.WindowTitle; when that is empty QlikView
        # falls back to the first expression label. Frame.Name alone is overwritten.
        if ($Caption) {
            $p.GraphLayout.WindowTitle.v = $Caption
            try { $cp.Title.Title.v = $Caption } catch {}
            $p.GraphLayout.Frame.Name.v = $Caption
        }
        $cp.Title.Show = $false
        $cp.Legend.Show = [bool]$Legend
        $cp.Legend.DockedPosition = $LegendPos
        Set-QvFontDef $cp.Legend.Font 8
        Set-QvColorArea $cp.Legend.TextColor $QS.C.Text
        Set-QvFontDef $cp.XAxis.Font 8
        Set-QvColorArea $cp.XAxis.TextColor $QS.C.Muted
        Set-QvColorArea $cp.XAxis.Color $QS.C.Border
        if ($NoXAxis) { $cp.XAxis.Show = $false }
        try { Set-QvColorArea $cp.BackgroundColor $Bg -Alpha $BgAlpha } catch {}
        try { Set-QvColorArea $cp.PlotAreaColor $Bg -Alpha $BgAlpha } catch {}
        try { Set-QvColorArea $cp.GridColor $QS.C.Grid } catch {}
        try { $cp.BarChartMode = 0; $cp.LineChartMode = 0; $cp.ComboChartMode = 0; $cp.PieChartMode = 0; $cp.ScatterChartMode = 5; $cp.GridChartMode = 6; $cp.RadarChartMode = 0 } catch {}
        $cp.LineWidth = $LineWidth * 5
        if ($Horizontal) { $cp.Horizontal = $true }
        if ($Stacked) { $cp.BarModeStacked = $true }
        Write-QvTrace "chart $Id : colormap"
        # colour map
        $pal = if ($Colors) { $Colors } else { $QS.Cat }
        for ($i = 0; $i -lt [Math]::Min($cp.ColorMap.Count, 18); $i++) { Set-QvColorArea $cp.ColorMap.Item($i) $pal[$i % $pal.Count] }
        if ($Type -eq 'gauge') {
            $cp.GaugeChartMode = $GaugeMode
            if ($Gauge) { Set-QvGaugeSettings $cp.GaugeSettings $Gauge }
        }
        if ($Texts) {
            foreach ($t in $Texts) {
                [void]$cp.Texts.Add(); $ti = $cp.Texts.Item($cp.Texts.Count - 1)
                $ti.Text.v = $t.T
                # R = chart-text units; P = pixels (1 px ~ 2.86 units, measured)
                $rr = if ($t.P) { @($t.P | ForEach-Object { [int]($_ * 2.86) }) } else { $t.R }
                $ti.Position.Left = $rr[0]; $ti.Position.Top = $rr[1]; $ti.Position.Width = $rr[2]; $ti.Position.Height = $rr[3]
                Set-QvFontDef $ti.Font $(if ($t.Size) { $t.Size } else { 9 }) -Bold:([bool]$t.Bold)
                Set-QvColorArea $ti.TextColor $(if ($t.Color) { $t.Color } else { $QS.C.Text }) $t.ColorExpr
                $ti.Transparent = $true; $ti.TextAdjust = $(if ($t.Align -ne $null) { $t.Align } else { 1 })
            }
        }
        if ($CalcCond) { $p.EvaluationCondition.v = $CalcCond }
        if ($Type -in 'straight','pivot') {
            $tp = $p.TableProperties
            if ($Totals -or $Type -eq 'straight') { try { $tp.TableTotalPosition = 0 } catch {} }   # 0 = totals on top (style guide)
            $tp.ShowSortIndicators = $false
            # blank null/missing symbols: QlikView's default '-' shows up in totals of NoTotal / rate columns
            foreach ($o2 in @($tp, $p)) { try { $o2.NullSymbol = ' ' } catch {}; try { $o2.MissingSymbol = ' ' } catch {} }
        }
        if ($chartUserCfg) { & $chartUserCfg $p }
    }
    return $o
}

# ======================================================================================================
# Composite chrome: header band + navigation + page title + help box (identical on every sheet)
# ======================================================================================================
# PROJECT SETTINGS - override any of these in your build script BEFORE calling New-QvHeader / Set-QvSheetOrder:
#   $Global:QvAppInfo = @{ Name='Acme Sales'; Sub='SALES COCKPIT'; Stamp="='Data through ' & vDataEndDate" }
#   $Global:QvNav = @( @{Key='DASH'; Sheet='SH_DASH'; Text='Dashboard'; W=110}, ... )   # X is computed when omitted
#   $Global:QvSheetOrder = @('SH_DASH', ...)
if (-not $Global:QvAppInfo) {
    $Global:QvAppInfo = @{ Name = 'My QlikView App'; Sub = ('DASHBOARD  ' + $QS.Glyph.Mid + '  ANALYSIS  ' + $QS.Glyph.Mid + '  REPORTS');
                           Stamp = ("='Data through ' & vDataEndDate & '   " + $QS.Glyph.Mid + "   all amounts in EUR'") }
}
if (-not $Global:QvNav) {
    $Global:QvNav = @(
        @{ Key='DASH';  Sheet='SH_DASH';   Text='Dashboard'; W=110 },
        @{ Key='ANA';   Sheet='SH_ANA';    Text='Analysis';  W=100 },
        @{ Key='REP';   Sheet='SH_REPORT'; Text='Reports';   W=96  },
        @{ Key='HELP';  Sheet='SH_HELP';   Text='About';     W=84  }
    )
}
function New-QvHeader {
    param($Doc, $Sheet, [string]$Tag, [string]$Title, [string]$Subtitle, [string]$Help, [string]$Active = $Tag)
    $G = $QS.Glyph
    New-QvText $Doc $Sheet "${Tag}_HDR_BG" @(0,0,1690,48) -Bg $QS.C.Navy | Out-Null
    New-QvText $Doc $Sheet "${Tag}_HDR_APP" @(14,4,200,24) -Text $QvAppInfo.Name -BgAlpha 0 -Fg $QS.C.White -Size 14 -Bold -Margin 2 | Out-Null
    New-QvText $Doc $Sheet "${Tag}_HDR_SUB" @(14,28,200,16) -Text $QvAppInfo.Sub -BgAlpha 0 -Fg $QS.C.NavText -Size 7.5 -Margin 2 -VAlign 0 | Out-Null
    $nx = 230
    foreach ($n in $QvNav) {
        if (-not $n.X) { $n.X = $nx }; $nx = $n.X + $n.W + 4
        $isOn = ($n.Key -eq $Active)
        $bg = if ($isOn) { $QS.C.Primary } else { $QS.C.Navy2 }
        $fg = if ($isOn) { $QS.C.White } else { $QS.C.NavText }
        New-QvButton $Doc $Sheet "${Tag}_NAV_$($n.Key)" @($n.X,9,$n.W,30) -Text $n.Text -Actions @(@{ Type='sheet'; P=@($n.Sheet) }) -Bg $bg -Fg $fg -Bold:$isOn -Size 9 | Out-Null
    }
    New-QvText $Doc $Sheet "${Tag}_HDR_STAMP" @(1084,9,340,30) -Text $QvAppInfo.Stamp -BgAlpha 0 -Fg $QS.C.NavText -Size 8 -HAlign 2 | Out-Null
    New-QvButton $Doc $Sheet "${Tag}_HDR_CLEAR" @(1432,9,116,30) -Text 'Clear selections' -Actions @(@{ Type='clear' }) -Bg $QS.C.Navy2 -Fg $QS.C.White -Size 8.5 | Out-Null
    New-QvButton $Doc $Sheet "${Tag}_HDR_HELP" @(1554,9,126,30) -Text ("=If(vShowHelp=1,'" + $G.Info + "  Hide help','" + $G.Info + "  Show help')") -Actions @(@{ Type='setvar'; P=@('vShowHelp','=If(vShowHelp=1,0,1)') }) -Bg $QS.C.Navy2 -Fg $QS.C.White -Size 8.5 | Out-Null
    New-QvText $Doc $Sheet "${Tag}_TTL" @(10,52,700,25) -Text $Title -BgAlpha 0 -Fg $QS.C.Text -Size 13 -Bold -Margin 2 | Out-Null
    New-QvText $Doc $Sheet "${Tag}_SUB" @(10,77,700,17) -Text $Subtitle -BgAlpha 0 -Fg $QS.C.Muted -Size 8.5 -Margin 2 -VAlign 0 | Out-Null
    if ($Help) { New-QvHelp $Doc $Sheet "${Tag}_HELP_SHEET" @(900,52,780,40) $Help | Out-Null }
}
# "What am I looking at?" box: shown when vShowHelp=1
function New-QvHelp {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Text, [double]$Size = 8)
    $t = $Text
    if (-not $t.StartsWith('=') -and -not $t.StartsWith($QS.Glyph.Info)) { $t = $QS.Glyph.Info + '  ' + $t }
    New-QvText $Doc $Sheet $Id $Rect -Text $t -Bg $QS.C.InfoBg -Fg $QS.C.InfoText -Size $Size -Margin 6 -VAlign 4 -ShowCond 'vShowHelp=1'
}
# Panel section header strip
function New-QvSectionHead {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Text, [string]$Bg = $QS.C.PanelHead)
    New-QvText $Doc $Sheet $Id $Rect -Text $Text.ToUpper() -Bg $Bg -Fg $QS.C.Muted -Size 7.5 -Bold -Margin 2 -HAlign 0
}

# ======================================================================================================
# KPI tile (layered text objects). Value/Delta/Context are QlikView expressions (start with '=').
#   StatusExpr: expression returning 1 (good), 0 (warn), -1 (bad) - drives accent bar and delta colour.
# ======================================================================================================
function Get-QvStatusColorExpr([string]$StatusExpr) {
    "If(($StatusExpr)>0, $(Get-QvRgbExpr $QS.C.Good), If(($StatusExpr)<0, $(Get-QvRgbExpr $QS.C.Bad), $(Get-QvRgbExpr $QS.C.Warn)))"
}
function New-QvKpiTile {
    param($Doc, $Sheet, [string]$Id, [int]$X, [int]$Y, [int]$W = 270, [int]$H = 118,
          [string]$Label, [string]$Value, [string]$Delta, [string]$Context, [string]$StatusExpr, [string]$HelpText, [double]$ValueSize = 20)
    $col = if ($StatusExpr) { Get-QvStatusColorExpr $StatusExpr } else { $null }
    New-QvText $Doc $Sheet "${Id}_BG" @($X,$Y,$W,$H) -Bg $QS.C.Card -HelpText $HelpText | Out-Null
    New-QvText $Doc $Sheet "${Id}_BAR" @($X,$Y,4,$H) -Bg $QS.C.Primary -BgExpr $col | Out-Null
    New-QvText $Doc $Sheet "${Id}_LBL" @(($X+14),($Y+8),($W-24),20) -Text $Label -BgAlpha 0 -Fg $QS.C.Muted -Size 8.5 -Bold -Margin 0 | Out-Null
    New-QvText $Doc $Sheet "${Id}_VAL" @(($X+14),($Y+28),($W-24),42) -Text $Value -BgAlpha 0 -Fg $QS.C.Text -Size $ValueSize -Bold -Margin 0 | Out-Null
    if ($Delta) { New-QvText $Doc $Sheet "${Id}_DLT" @(($X+14),($Y+72),($W-24),20) -Text $Delta -BgAlpha 0 -Fg $QS.C.Text -FgExpr $col -Size 8.5 -Bold -Margin 0 | Out-Null }
    if ($Context) { New-QvText $Doc $Sheet "${Id}_CTX" @(($X+14),($Y+92),($W-24),20) -Text $Context -BgAlpha 0 -Fg $QS.C.Muted -Size 8 -Margin 0 | Out-Null }
}
# Compact KPI (h ~ 64): label + value left, delta right
function New-QvMiniKpi {
    param($Doc, $Sheet, [string]$Id, [int]$X, [int]$Y, [int]$W = 355, [int]$H = 64,
          [string]$Label, [string]$Value, [string]$Delta, [string]$StatusExpr)
    $col = if ($StatusExpr) { Get-QvStatusColorExpr $StatusExpr } else { $null }
    New-QvText $Doc $Sheet "${Id}_BG" @($X,$Y,$W,$H) -Bg $QS.C.Card | Out-Null
    New-QvText $Doc $Sheet "${Id}_BAR" @($X,$Y,4,$H) -Bg $QS.C.Primary -BgExpr $col | Out-Null
    New-QvText $Doc $Sheet "${Id}_LBL" @(($X+14),($Y+6),($W-24),18) -Text $Label -BgAlpha 0 -Fg $QS.C.Muted -Size 8 -Bold -Margin 0 | Out-Null
    New-QvText $Doc $Sheet "${Id}_VAL" @(($X+14),($Y+24),180,34) -Text $Value -BgAlpha 0 -Fg $QS.C.Text -Size 16 -Bold -Margin 0 | Out-Null
    if ($Delta) { New-QvText $Doc $Sheet "${Id}_DLT" @(($X+190),($Y+30),($W-200),24) -Text $Delta -BgAlpha 0 -Fg $QS.C.Text -FgExpr $col -Size 8.5 -Bold -Margin 0 -HAlign 2 | Out-Null }
}

# ======================================================================================================
# Expression snippets (QlikView) used by tiles
# ======================================================================================================
# money in millions: 'EUR 123.4 M' (euro sign)
function Get-QvMoneyM([string]$e) { "Num(($e)/1000000,'" + $QS.Glyph.Eur + " #,##0.0') & ' M'" }
# growth with arrow: '(up-triangle) +5.2% vs PY'
function Get-QvGrowthText([string]$e, [string]$Suffix = ' vs PY') {
    "If(($e)>=0, Chr(9650), Chr(9660)) & ' ' & Num($e,'+0.0%;-0.0%') & '$Suffix'"
}
function Get-QvPpText([string]$e, [string]$Suffix = ' vs PY') {
    "If(($e)>=0, Chr(9650), Chr(9660)) & ' ' & Num($e,'+0.0;-0.0') & ' pp$Suffix'"
}

# ======================================================================================================
# Round 2 (designer-a): input objects + container
# ======================================================================================================
# Slider bound to a variable (discrete steps), e.g. New-QvSlider $doc $sh 'SALES_FLT_SL_TOPN' @(14,606,202,44) 'vTopN' 3 25 1
function New-QvSlider {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Variable, [double]$Min = 1, [double]$Max = 10, [double]$Step = 1,
          [string]$Caption, [string]$HelpText, [double]$Size = 8)
    $o = $Sheet.CreateSlider()
    $fa = @{ BorderWidth = 0; FontSize = $Size; Bg = $QS.C.Card }
    if ($Caption) { $fa.Caption = $Caption; $fa.CaptionSize = 8 } else { $fa.NoCaption = $true }
    if ($HelpText) { $fa.HelpText = $HelpText }
    return Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $fa -Configure {
        param($p)
        $p.Name1.Name = $Variable          # QlikView detects that the name is a variable (Type IS_VAR)
        $L = $p.Layout
        $L.Min.v = [string]$Min; $L.Max.v = [string]$Max
        $L.UseStaticStep = $true; $L.Step.v = [string]$Step
        try { $L.FixedRange = $false } catch {}
        try { $L.ShowTickMarks = $true; $L.ShowTickMarkValues = $true; $L.ShowScrollButtons = $true; $L.ShowPopupValues = $true } catch {}
        try { Set-QvColorArea $L.SliderColor $QS.C.Primary; Set-QvColorArea $L.ThumbColor $QS.C.Primary; Set-QvColorArea $L.ScaleBkgColor $QS.C.Panel } catch {}
        try { Set-QvColorArea $L.TickMarkColor $QS.C.Muted } catch {}
        Set-QvFontDef $L.Frame.Font $Size
    }
}

# Input box for one or more variables: -Variables @('vTopN') -Labels @('Top N customers')
function New-QvInputBox {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string[]]$Variables, [string[]]$Labels, [string]$Caption, [string]$HelpText,
          [double]$Size = 9, [int]$LabelPx = 120)
    $o = $Sheet.CreateInputBox()
    foreach ($v in $Variables) { [void]$o.AddVariable($v) }
    $fa = @{ BorderWidth = 0; FontSize = $Size; Bg = $QS.C.Card }
    if ($Caption) { $fa.Caption = $Caption; $fa.CaptionSize = 8 } else { $fa.NoCaption = $true }
    if ($HelpText) { $fa.HelpText = $HelpText }
    return Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $fa -Configure {
        param($p)
        $L = $p.Layout
        for ($i = 0; $i -lt $Variables.Count; $i++) {
            $m = $L.MemberAttributes.Item($i)
            if ($Labels -and $Labels.Count -gt $i) { $m.Label.v = $Labels[$i] }
            try { Set-QvColorArea $m.BkgColor $QS.C.White; Set-QvColorArea $m.TextColor $QS.C.Text } catch {}
        }
        try { $L.ColWidthLabel = [int]($LabelPx * 300 / 96); $L.ColWidthData = [int](($Rect[2] - $LabelPx - 26) * 300 / 96) } catch {}
        try { $L.ShowEqualSign = $false } catch {}
        Set-QvFontDef $L.Frame.Font $Size
    }
}

# Container (single object, tabs). Items: @( @{ Id='SALES_CH_SCATTER'; Text='Discount vs margin' }, ... )
# The contained objects must exist first; the lib moves them to the container rect (they are shown inside the container).
function New-QvContainer {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [array]$Items, [string]$Caption, [string]$HelpText, [int]$TabMode = 0)
    # TabMode = SingleObjectMode (QlikView default 1 = TABS_LEFT; 0 = tabs at top)
    $o = $Sheet.CreateContainer()
    $fa = @{ BorderWidth = 0 }
    if ($Caption) { $fa.Caption = $Caption } else { $fa.NoCaption = $true }
    if ($HelpText) { $fa.HelpText = $HelpText }
    $o = Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $fa -Configure {
        param($p)
        $co = $p.ContainedObjects
        while ($co.Count -gt 0) { $co.RemoveAt(0) }
        foreach ($it in $Items) {
            [void]$co.Add(); $ci = $co.Item($co.Count - 1)
            $ci.Def.ObjectId = "Document\$($it.Id)"
            if ($it.Text) { $ci.Text.v = $it.Text }
        }
        try { $p.Mode = 0; $p.SingleObjectMode = $TabMode; $p.ShowObjectTypeIcons = $false } catch {}
        try { Set-QvColorArea $p.TabColor $QS.C.Panel; Set-QvColorArea $p.TextColor $QS.C.Text } catch {}
    }
    return $o
}

# Puts the sheet tabs in D-A-R order (call while holding the lock). Sheets not in the list keep their relative order at the end.
if (-not $Global:QvSheetOrder) { $Global:QvSheetOrder = @($QvNav | ForEach-Object { $_.Sheet }) }
function Set-QvSheetOrder($Doc) {
    $k = 0
    foreach ($sid in $QvSheetOrder) {
        $idx = -1
        for ($i = 0; $i -lt $Doc.NoOfSheets(); $i++) { if ($Doc.GetSheet($i).GetProperties().SheetId -eq "Document\$sid") { $idx = $i; break } }
        if ($idx -lt 0) { continue }
        $s = $Doc.GetSheet($idx)
        while ($idx -gt $k) { $s.Promote(); $idx-- }
        $k++
    }
}


# Current Selections box: ColWidths is read-only via COM, so round-trip the object through its XML.
# Widths in px (field, status, value). Keeps the ObjectId and rect.
function Repair-QvCurSelWidths {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [int[]]$WidthsPx = @(66, 0, 120))
    # Get-QvObj (doc-level lookup) returns null for a just-created object while another sheet (parking) is active,
    # so look it up on its own sheet first.
    $o = $null; foreach ($x in $Sheet.GetSheetObjects()) { if ($x.GetObjectId() -eq "Document\$Id") { $o = $x } }
    if (-not $o) { $o = Get-QvObj $Doc $Id }
    if (-not $o) { Write-Warning "Repair-QvCurSelWidths: $Id not found"; return }
    $tmp = Join-Path $env:TEMP "qv_cs_$Id.xml"
    $o.WriteXmlPropertiesFile($tmp)
    $xml = [IO.File]::ReadAllText($tmp)
    $ints = ($WidthsPx | ForEach-Object { "<int>$([int][Math]::Round($_ * 300 / 96))</int>" }) -join ''
    $xml = [regex]::Replace($xml, '<ColWidths>[\s\S]*?</ColWidths>', "<ColWidths>$ints</ColWidths>")
    [IO.File]::WriteAllText($tmp, $xml)
    $before = @{}; foreach ($x in $Sheet.GetSheetObjects()) { $before[$x.GetObjectId()] = 1 }
    $o.Close()
    [void]$Sheet.CreateObjectFromXmlPropertiesFile($tmp)
    $n = $null; foreach ($x in $Sheet.GetSheetObjects()) { if (-not $before.ContainsKey($x.GetObjectId())) { $n = $x } }
    if (-not $n) { Write-Warning "Repair-QvCurSelWidths: $Id not recreated"; return }
    if ($n.GetObjectId() -ne "Document\$Id") { $pp = $n.GetProperties(); (Get-QvFrame $pp).ObjectId = "Document\$Id"; $n.SetProperties($pp) }
    Set-QvRect $n $Rect
    Remove-Item $tmp -ErrorAction SilentlyContinue
}
