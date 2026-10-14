# lib-ext.ps1 - designer-b extra helpers on top of designer/lib-qv.ps1 (read-only). ASCII only.
# Dot-source AFTER lib-qv.ps1.
#   * New-QvbChart  : New-QvChart + chart-title fix (WindowTitle / Title.Title = caption) + optional extra configure block
#   * New-QvbFilterPanel : the common Analysis filter panel (layout-spec section 0b, rows 1-4)
#   * New-QvbListBox / New-QvbMultiBox / New-QvbCurSel / New-QvbSearch
#   * Add-QvbRefLine : reference line on a chart (best effort)

function Write-QvbLog([string]$Msg) {
    $f = (Join-Path $QvBuildRoot 'logs\build.log')
    Add-Content -Path $f -Value ("{0:HH:mm:ss} {1}" -f (Get-Date), $Msg)
}

# ---------- chart title fix: caption = window title, chart title hidden ----------
function Set-QvbTitle($p, [string]$Caption) {
    if (-not $Caption) { return }
    try { $p.GraphLayout.WindowTitle.v = $Caption } catch { Write-QvbLog "WindowTitle: $_" }
    try { $p.ChartProperties.Title.Title.v = $Caption } catch {}
    try { $p.ChartProperties.Title.Show = $false } catch {}
    try { $p.GraphLayout.Frame.Name.v = $Caption } catch {}
}

# Same parameters as New-QvChart (passed as a hashtable), plus -Extra { param($p) ... } for type-specific tweaks.
# NB: the configure block runs inside lib functions; it reads $__qvbCap/$__qvbExtra through PowerShell's dynamic scoping.
function New-QvbChart {
    param([hashtable]$A, [scriptblock]$Extra)
    $__qvbCap = $A.Caption
    $__qvbExtra = $Extra
    $__qvbExprs = @($A.Exprs)
    $A.Configure = {
        param($p)
        Set-QvbTitle $p $__qvbCap
        # lib bug: $x.Values on a hashtable is its .Values collection (always truthy) -> set labels explicitly
        for ($i = 0; $i -lt $__qvbExprs.Count; $i++) {
            $grp = $p.Expressions.Item($i)
            for ($j = 0; $j -lt $grp.Count; $j++) { $grp.Item($j).Data.ExpressionVisual.ShowAsTextInChart = [bool]$__qvbExprs[$i]['Values'] }
        }
        if ($__qvbExtra) { & $__qvbExtra $p }
    }
    $o = New-QvChart @A
    try { Update-QvLock -Owner designer-b } catch {}
    return $o
}

# ---------- reference line (best effort; logs members if the COM shape differs) ----------
function Add-QvbRefLine($p, [string]$Value, [string]$Hex = $QS.C.Text, [string]$Label = '', [int]$Width = 1) {
    try {
        $rl = $p.ChartProperties.RefLines
        [void]$rl.Add(); $r = $rl.Item($rl.Count - 1)
        $names = ($r | Get-Member -MemberType Property | ForEach-Object Name) -join ','
        Write-QvbLog "RefLine members: $names"
        foreach ($n in 'Definition','Expression','Def','Value') { try { $r.$n.v = $Value; break } catch {} }
        try { $r.PrimaryY = $true; $r.YAxis = $true } catch {}
        try { $r.Weight = $Width } catch {}
        try { Set-QvColorArea $r.Color $Hex } catch {}
        try { $r.Label.v = $Label } catch {}
        try { $r.ShowLabel = [bool]$Label } catch {}
        try { $r.Width = $Width } catch {}
        try { $r.PenWidth = $Width } catch {}
        try { $r.Show.Always = $true } catch {}
    } catch { Write-QvbLog "RefLine failed: $_" }
}

# ---------- list box ----------
# Cols > 1: fixed columns, values in rows (e.g. Year 3 cols, Month 6 cols x 2 rows)
function New-QvbListBox {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Field, [int]$Cols = 1, [double]$Size = 8, [string]$Caption, [int]$Align = 0)
    $o = $Sheet.CreateListBox()
    $fa = @{ BorderWidth = 0; FontSize = $Size; Bg = $QS.C.Card }
    if ($Caption) { $fa.Caption = $Caption; $fa.CaptionSize = 8; $fa.CaptionBg = $QS.C.PanelHead; $fa.CaptionFg = $QS.C.Muted } else { $fa.NoCaption = $true }
    return Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $fa -Configure {
        param($p)
        $p.Def.Name = $Field
        try { $p.Title.v = $(if ($Caption) { $Caption } else { $Field }) } catch {}
        $L = $p.Layout
        $L.ShowFrequency = $false
        try { $L.SuppressHorizontalScroll = $true } catch {}
        if ($Cols -gt 1) {
            $L.MultiColumn = $true; $L.FixedColumnsCount = $Cols; $L.OrderByRow = $true; $L.CellBorders = $true
            try { $L.TextAdjust = 1 } catch {}
        } else {
            $L.MultiColumn = $false
            try { $L.TextAdjust = $Align } catch {}
        }
        try { Set-QvColorArea $L.TextColor $QS.C.Text } catch {}
        Set-QvFontDef $L.Frame.Font $Size
    }
}

# ---------- multi box ----------
# Fields: array of @('Field','Label')
function New-QvbMultiBox {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [array]$Fields, [double]$Size = 8)
    $o = $Sheet.CreateMultiBox()
    foreach ($f in $Fields) { [void]$o.AddField($f[0]) }
    return Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame @{ NoCaption = $true; BorderWidth = 0; FontSize = $Size; Bg = $QS.C.Card } -Configure {
        param($p)
        for ($i = 0; $i -lt $Fields.Count; $i++) {
            $m = $p.MemberAttributes.Item($i)
            $m.Label.v = $Fields[$i][1]
            $m.ShowFrequency = $false
        }
        $L = $p.Layout
        try { $L.ColWidthLabel = 220; $L.ColWidthData = 330 } catch {}
        Set-QvFontDef $L.Frame.Font $Size
    }
}

# ---------- current selections ----------
function New-QvbCurSel {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [double]$Size = 8)
    $o = $Sheet.CreateCurrentSelectionBox()
    return Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame @{ NoCaption = $true; BorderWidth = 0; FontSize = $Size; Bg = $QS.C.Card } -Configure {
        param($p)
        $L = $p.Layout
        try { $L.ShowStatusColumn = $false } catch {}
        try { $L.ShowLabelRow = $false } catch {}
        try { $L.ShowEraserIcon = $true } catch {}
        $cw = @(210, 210, 375)
        for ($i = 0; $i -lt 3; $i++) {
            try { [void]$L.GetType().InvokeMember('ColWidths', [Reflection.BindingFlags]::SetProperty, $null, $L, @([int]$i, [int]$cw[$i])) } catch { Write-QvbLog "cs colwidths($i): $($_.Exception.InnerException.Message) $_" }
        }
        try { Set-QvColorArea $L.TextColor $QS.C.Text } catch {}
        Set-QvFontDef $L.Frame.Font $Size
    }
}

# ---------- search object (all fields) ----------
function New-QvbSearch {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect)
    $o = $Sheet.CreateSearchObject()
    return Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame @{ NoCaption = $true; BorderWidth = 0; FontSize = 8.5; Bg = $QS.C.Card } -Configure {
        param($p)
        try { $p.Mode = 0 } catch {}   # all fields
        try { $p.SearchFieldText.v = 'Search all fields...' } catch {}
        try { $p.Appearance = 0 } catch {}
    }
}

# ---------- common filter panel (layout-spec 0b, sections 1-4 + header of section 5) ----------
# tables: show blank instead of '-' for null / missing cells (e.g. NoTotal totals)
function Set-QvbBlankNull($p) {
    foreach ($o in @($p.TableProperties, $p)) { try { $o.NullSymbol = ' ' } catch {}; try { $o.MissingSymbol = ' ' } catch {} }
}

# COM column widths are ~3 units per pixel
function ConvertTo-QvbCw([int]$Px) { return [int]($Px * 3) }

# removes leftover designer-b sandbox sheets (by name)
function Remove-QvbSandbox($Doc) {
    for ($k = $Doc.NoOfSheets() - 1; $k -ge 0; $k--) { $s0 = $Doc.GetSheet($k); if ($s0.GetProperties().Name -eq 'ZZ_designerb_Sandbox') { $s0.Remove() } }
}

# Common Analysis filter panel (x 10..220, y 96..746): current selections, period list boxes, a multi box of filters,
# search, and an optional 5th section header (e.g. 'Top N' for a slider/input box you add below it at y ~606).
#   -Filters  @( @('FieldName','Label'), ... )  up to ~8 rows        -Period  @( @('Year',3), @('Quarter',4), @('Month',6) )  (field, columns)
function New-QvbFilterPanel {
    param($Doc, $Sheet, [string]$Tag, [string]$Section5,
          [array]$Filters = @(@('CustomerRegion','Region'), @('CustomerCountry','Country'), @('ProductCategory','Category'), @('ProductGroup','Product group'),
                              @('Channel','Channel'), @('CustomerSegment','Segment'), @('SalesTeam','Sales team'), @('Brand','Brand')),
          [array]$Period = @(@('Year',3), @('Quarter',4), @('Month',6)))
    New-QvText $Doc $Sheet "${Tag}_FLT_BG" @(10,96,210,650) -Bg $QS.C.Panel | Out-Null
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H1" @(10,96,210,20) 'Current selections' | Out-Null
    New-QvbCurSel $Doc $Sheet "${Tag}_FLT_CS" @(14,118,202,84) | Out-Null
    try { Repair-QvCurSelWidths $Doc $Sheet "${Tag}_FLT_CS" @(14,118,202,84) } catch { Write-Warning "cur-sel widths: $_" }   # no h-scrollbar
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H2" @(10,206,210,20) 'Period' | Out-Null
    $y = 228
    foreach ($pf in $Period) {
        $h = if ([int]$pf[1] -ge 6) { 44 } else { 24 }
        New-QvbListBox $Doc $Sheet ("${Tag}_FLT_LB_" + ($pf[0].ToUpper() -replace '[^A-Z0-9]','')) @(14,$y,202,$h) $pf[0] -Cols ([int]$pf[1]) | Out-Null
        $y += $h + 2
    }
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H3" @(10,330,210,20) 'Filters' | Out-Null
    New-QvbMultiBox $Doc $Sheet "${Tag}_FLT_MB" @(14,352,202,172) $Filters | Out-Null
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H4" @(10,530,210,20) 'Search' | Out-Null
    New-QvbSearch $Doc $Sheet "${Tag}_FLT_SO" @(14,552,202,26) | Out-Null
    if ($Section5) { New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H5" @(10,584,210,20) $Section5 | Out-Null }
}
