# lib-eng.ps1 - engineer's helpers for panel objects (list box, multi box, current selections, search, calendar,
# statistics box, table box, container, bookmark object, line/arrow) and the 0b filter panel.
# Builds on lib-qv.ps1 (dot-sourced READ-ONLY). ASCII-only.
. "$PSScriptRoot\lib-qv.ps1"
$Global:QvTraceFile = Join-Path $QvBuildRoot 'logs\build.log'

function Step([string]$m) { Write-QvTrace "[eng] $m"; try { Update-QvLock -Owner engineer } catch {} }

# own parking sheet (blank, active while building, so COM calls do not wait for recalcs)
function Enter-EngParking($Doc) {
    $pk = Get-QvSheetById $Doc 'ZZ_engineer_Park'
    if (-not $pk) {
        $pk = $Doc.CreateSheet(); $pp = $pk.GetProperties(); $pp.Name = 'ZZ_engineer_Park (build in progress)'; $pp.SheetId = 'Document\ZZ_engineer_Park'; $pk.SetProperties($pp)
        $pk = Get-QvSheetById $Doc 'ZZ_engineer_Park'
    }
    $pk.Activate()
}
function Exit-EngParking($Doc, [string]$ActivateId) {
    if ($ActivateId) { $s = Get-QvSheetById $Doc $ActivateId; if ($s) { $s.Activate() } }
    $pk = Get-QvSheetById $Doc 'ZZ_engineer_Park'; if ($pk) { $pk.Remove() }
    $sb = Get-QvSheetById $Doc 'ZZ_engineer_Sandbox'; if ($sb) { $sb.Remove() }
}

$Global:EngFrameFlat = @{ NoCaption = $true; BorderWidth = 0; FontSize = 8 }

function New-EngListBox {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Field, [int]$Columns = 0, [string]$Caption, [double]$Size = 8)
    $o = $Sheet.CreateListBox()
    $fr = $EngFrameFlat.Clone(); if ($Caption) { $fr.Remove('NoCaption'); $fr.Caption = $Caption }
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $fr -Configure {
        param($p)
        $p.Def.Name = $Field
        $L = $p.Layout
        $L.ShowFrequency = $false
        if ($Columns -gt 0) { $L.MultiColumn = $true; $L.FixedColumnsCount = $Columns; $L.OrderByRow = $true; try { $L.SuppressHorizontalScroll = $true } catch {} }
        $L.TextAdjust = 1
        Set-QvFontDef $L.Frame.Font $Size
    } | Out-Null
    return (Get-QvObj $Doc $Id)
}

function New-EngMultiBox {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [array]$Fields, [int]$LabelW = 240, [int]$DataW = 270)
    $o = $Sheet.CreateMultiBox()
    foreach ($f in $Fields) { [void]$o.AddField($f.F) }
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $EngFrameFlat -Configure {
        param($p)
        for ($i = 0; $i -lt $Fields.Count; $i++) { $p.MemberAttributes.Item($i).Label.v = $Fields[$i].L }
        try { $p.Layout.Style = 1 } catch {}
        $p.Layout.ColWidthLabel = $LabelW; $p.Layout.ColWidthData = $DataW
        Set-QvFontDef $p.Layout.Frame.Font 8
    }
}

function New-EngCurSel {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect)
    $o = $Sheet.CreateCurrentSelectionBox()
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $EngFrameFlat -Configure {
        param($p)
        $L = $p.Layout
        $L.ShowStatusColumn = $false; $L.ShowLabelRow = $false; $L.ShowValueColumn = $true
        try { $L.ShowEraserIcon = $true; $L.ShowDropdownSelectIcon = $false } catch {}
        Set-QvFontDef $L.Frame.Font 8
        try { Set-QvColorArea $L.BkgColor $QS.C.White; Set-QvColorArea $L.TextColor $QS.C.Text } catch {}
    } | Out-Null
}

function New-EngSearch {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Placeholder = 'Search all fields')
    $o = $Sheet.CreateSearchObject()
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $EngFrameFlat -Configure {
        param($p)
        $p.SearchFieldText.v = $Placeholder
        try { $p.Appearance = 1 } catch {}
        Set-QvFontDef $p.Frame.Font 8.5
    } | Out-Null
}

# Calendar (slider object, calendar input style) on a date field
function New-EngCalendar {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Field = 'Date')
    $o = $Sheet.CreateSlider()
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $EngFrameFlat -Configure {
        param($p)
        $p.Name1.Name = $Field
        $p.Layout.InputStyle = 1
        try { $p.Layout.SelectionRange = 1 } catch {}
        Set-QvFontDef $p.Layout.Frame.Font 8
    } | Out-Null
}

function New-EngStatBox {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Field, [string]$Caption)
    $o = $Sheet.CreateStatisticsBox()
    $fr = $EngFrameFlat.Clone(); if ($Caption) { $fr.Remove('NoCaption'); $fr.Caption = $Caption; $fr.CaptionSize = 8 }
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $fr -Configure {
        param($p)
        $p.FieldDef.Name = $Field
        if ($Caption) { $p.Title.v = $Caption }
        $p.Layout.ColWidthLabel = 200; $p.Layout.ColWidthValue = 330
        try { for ($i = 0; $i -lt $p.Rows.Count; $i++) { Set-QvNumFmt $p.Rows.Item($i).NumberPresentation $(if ($i -eq 0) { '#,##0' } else { 'money' }) } } catch {}
        Set-QvFontDef $p.Layout.Frame.Font 8
    } | Out-Null
}

# Table box: Cols = @( @{F='Field'; L='Label'; Fmt='money'} ... )
function New-EngTableBox {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Caption, [array]$Cols, [string]$CalcCond, [string]$HelpText)
    $o = $Sheet.CreateTableBox()
    foreach ($c in $Cols) { [void]$o.AddField($c.F) }
    $fr = @{ Caption = $Caption; FontSize = 8.5 }; if ($HelpText) { $fr.HelpText = $HelpText }
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame $fr -Configure {
        param($p)
        $p.Layout.Frame.XLIcon = $true
        for ($i = 0; $i -lt $Cols.Count; $i++) {
            $cl = $p.Layout.ColLayouts.Item($i)
            if ($Cols[$i].L) { $cl.Label.v = $Cols[$i].L }
            if ($Cols[$i].Fmt) { try { Set-QvNumFmt $cl.NumberPresentation $Cols[$i].Fmt } catch {} }
            if ($Cols[$i].W) { $cl.ColWidth = $Cols[$i].W }
        }
        if ($CalcCond) { $p.EvaluationCondition.v = $CalcCond }
        if ($script:MsgTooMany) { $em = $p.ErrorMessageOverrides; while ($em.Count -lt 6) { [void]$em.Add() }; $em.Item(5).v = $script:MsgTooMany }
    } | Out-Null
}

# Container: Items = @( @{ Id='REP_PT_PL'; T='P&L' } ... )
function New-EngContainer {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [array]$Items, [int]$TabMode = 1)
    $o = $Sheet.CreateContainer()
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame @{ NoCaption = $true; FontSize = 9 } -Configure {
        param($p)
        foreach ($it in $Items) {
            [void]$p.ContainedObjects.Add()
            $ci = $p.ContainedObjects.Item($p.ContainedObjects.Count - 1)
            $ci.Def.ObjectId = "Document\$($it.Id)"
            $ci.Text.v = $it.T
        }
        $p.Mode = 0
        try { $p.SingleObjectMode = $TabMode } catch {}
        try { $p.ShowObjectTypeIcons = $false } catch {}
        $p.SingleObjectActiveIndex = 0
        try { Set-QvColorArea $p.TabColor $QS.C.Panel; Set-QvColorArea $p.TextColor $QS.C.Text } catch {}
        Set-QvFontDef $p.Frame.Font 9 -Bold
    } | Out-Null
}

function New-EngBookmarkObj {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [string]$Caption)
    $o = $Sheet.CreateBookmarkObject()
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame @{ Caption = $Caption; FontSize = 9 } -Configure {
        param($p)
        $L = $p.Layout
        $L.ShowCreateButton = $false; $L.ShowDeleteButton = $false; $L.ShowUserBookmark = $false; $L.ShowBookmarkInfoText = $true
        Set-QvFontDef $L.ButtonFont 9; Set-QvFontDef $L.Frame.Font 9
    } | Out-Null
}

# Line/arrow. Orient: 0 horizontal, 1 vertical (checked on screenshot). Arrow: ToPt style left default.
function New-EngLine {
    param($Doc, $Sheet, [string]$Id, [int[]]$Rect, [int]$Orient = 0, [int]$Weight = 2, [string]$Color = $QS.C.Muted, [int]$FromPt = -1, [int]$ToPt = -1)
    $o = $Sheet.CreateLineArrowObject()
    Complete-QvObj -Doc $Doc -Obj $o -Id $Id -Rect $Rect -Frame @{ NoCaption = $true; BorderWidth = 0; BgAlpha = 0 } -Configure {
        param($p)
        $L = $p.Layout
        $L.ArrowOrient = $Orient; $L.LineWeight = $Weight
        if ($FromPt -ge 0) { $L.FromPt = $FromPt }; if ($ToPt -ge 0) { $L.ToPt = $ToPt }
        Set-QvColorArea $L.LineColor $Color
        try { $L.BkgAlpha = 0 } catch {}
    } | Out-Null
}

# Section 0b: filter panel x 10..220, y 96..746 (sections 1-4). Section 5 is sheet-specific.
function New-EngFilterPanel {
    param($Doc, $Sheet, [string]$Tag, [string]$Section5)
    New-QvText $Doc $Sheet "${Tag}_FLT_BG" @(10,96,210,650) -Bg $QS.C.Panel | Out-Null
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H1" @(10,96,210,20) 'Current selections' | Out-Null
    New-EngCurSel $Doc $Sheet "${Tag}_FLT_CS" @(14,118,202,84)
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H2" @(10,206,210,20) 'Period' | Out-Null
    New-EngListBox $Doc $Sheet "${Tag}_FLT_LB_YEAR" @(14,228,202,24) 'Year' -Columns 3 | Out-Null
    New-EngListBox $Doc $Sheet "${Tag}_FLT_LB_QTR" @(14,254,202,24) 'Quarter' -Columns 4 | Out-Null
    New-EngListBox $Doc $Sheet "${Tag}_FLT_LB_MONTH" @(14,280,202,44) 'Month' -Columns 6 | Out-Null
    Step 'panel: period done'
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H3" @(10,330,210,20) 'Filters' | Out-Null
    New-EngMultiBox $Doc $Sheet "${Tag}_FLT_MB" @(14,352,202,172) @(
        @{F='CustomerRegion';L='Region'}, @{F='CustomerCountry';L='Country'}, @{F='ProductCategory';L='Category'}, @{F='ProductGroup';L='Product group'},
        @{F='Channel';L='Channel'}, @{F='CustomerSegment';L='Segment'}, @{F='SalesTeam';L='Sales team'}, @{F='Brand';L='Brand'}) | Out-Null
    New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H4" @(10,530,210,20) 'Search' | Out-Null
    New-EngSearch $Doc $Sheet "${Tag}_FLT_SO" @(14,552,202,26)
    if ($Section5) { New-QvSectionHead $Doc $Sheet "${Tag}_FLT_H5" @(10,584,210,20) $Section5 | Out-Null }
    Step 'panel: done'
}

# Pivot layout that COM does not expose (ExpressionPosition): round-trip through the XML properties file.
function Set-EngPivotLayout {
    param($Doc, $Sheet, $Obj, [int]$ExprPos = 255, [int]$LeftDims = 255, [int[]]$Rect)
    $id = $Obj.GetObjectId()
    $path = Join-Path $env:TEMP ("qv_pivot_" + ($id -replace '.*\\','') + '.xml')
    $Obj.WriteXmlPropertiesFile($path)
    $x = [IO.File]::ReadAllText($path)
    $x = $x -replace '<ExpressionPosition>\d+</ExpressionPosition>', "<ExpressionPosition>$ExprPos</ExpressionPosition>"
    $x = $x -replace '<NumberOfLeftDimensions>\d+</NumberOfLeftDimensions>', "<NumberOfLeftDimensions>$LeftDims</NumberOfLeftDimensions>"
    [IO.File]::WriteAllText($path, $x, (New-Object Text.UTF8Encoding($true)))
    $Obj.Close()
    $before = @($Sheet.GetSheetObjects() | ForEach-Object { $_.GetObjectId() })
    [void]$Sheet.CreateObjectFromXmlPropertiesFile($path)
    $n = $Sheet.GetSheetObjects() | Where-Object { $before -notcontains $_.GetObjectId() } | Select-Object -First 1
    if (-not $n) { throw "pivot from xml: new object not found" }
    if ($n.GetObjectId() -ne $id) {
        $p = $n.GetProperties(); $p.GraphLayout.Frame.ObjectId = $id; $n.SetProperties($p)
    }
    if ($n.GetObjectId() -ne $id) { Write-Warning "pivot from xml got id $($n.GetObjectId()), wanted $id" }
    if ($Rect) { Set-QvRect $n $Rect }
    return $n
}
