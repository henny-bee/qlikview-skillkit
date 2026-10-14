# build-SH_<TAG>.ps1 - template for one sheet. Idempotent: clears the sheet and rebuilds every object with fixed IDs.
# Copy to _build\build\build-SH_DASH.ps1, rename the TODOs, then run:   _build/tools/qvrun.sh _build/build/build-SH_DASH.ps1
# Field and measure names below (Sales, Region, Month, vSales_CYTD ...) are placeholders: use your data contract names.
param([string]$SheetId = 'SH_DASH', [string]$Tag = 'DASH', [string]$Title = 'Dashboard', [switch]$NoShot, [string]$Owner = 'designer')
. "$PSScriptRoot\..\tools\lib-qv.ps1"     # also loads qvcom.ps1
. "$PSScriptRoot\..\tools\lib-ext.ps1"    # list/multi box, current selections, search, filter panel
. "$PSScriptRoot\app-settings.ps1"        # app name, navigation, sheet order
$G = $QS.Glyph; $C = $QS.C; $T = $Tag

Enter-QvLock -Owner $Owner
try {
    $doc = Get-QvDoc
    Enter-QvParking $doc                                  # build on an inactive sheet: every COM call stays fast
    $sh = Reset-QvSheet $doc $SheetId $Title              # creates or clears the sheet; -AdoptId SH01 reuses the default sheet

    New-QvHeader $doc $sh $T -Title $Title -Subtitle 'Year to date vs same period last year' `
        -Help 'What am I looking at?  TODO: one or two sentences that explain this sheet and how to use it.'

    # ---- KPI tiles (values are QlikView expressions; single quotes keep $(...) for QlikView) ----
    New-QvKpiTile $doc $sh "${T}_KPI1" 10 96 -Label ("SALES  " + $G.Mid + "  CYTD") `
        -Value ('=' + (Get-QvMoneyM '$(vSales_CYTD)')) `
        -Delta ('=' + (Get-QvGrowthText '$(vSales_YoY)')) `
        -Context ("='PY ' & " + (Get-QvMoneyM '$(vSales_PYTD)')) `
        -StatusExpr 'If($(vSales_YoY)>=0,1,-1)' -HelpText 'TODO: definition of the KPI.' | Out-Null

    # ---- Chart: title names the measure AND unit; values divided by 1e6 for EUR M ----
    New-QvChart $doc $sh "${T}_CH_TREND" combo @(10,224,830,256) -Caption ("Sales by Month (" + $G.Eur + " M) " + $G.Dash + " CY vs PY") `
        -Dims @(@{ F='Month'; L='Month' }) -Legend -LegendPos 0 -YUnit ($G.Eur + ' M') `
        -HelpText 'Bars: current year. Line: prior year.' `
        -Exprs @(
            @{ D='Sum({$<Year={$(=Max(Year))}>} Sales)/1000000';   L='CY'; Fmt='moneyM'; Mode='bar';  Color=$C.Primary },
            @{ D='Sum({$<Year={$(=Max(Year)-1)}>} Sales)/1000000'; L='PY'; Fmt='moneyM'; Mode='line'; Color=$C.PY }
        ) | Out-Null

    # ---- Pie: share -> Fmt 'pct' (money format would show "EUR 0") ----
    New-QvChart $doc $sh "${T}_CH_MIX" pie @(850,224,420,256) -Caption 'Sales Share by Region (%)' -Legend `
        -Dims @(@{ F='Region'; L='Region' }) -Exprs @(@{ D='Sum(Sales)'; L='Share'; Fmt='pct'; Relative=$true; Values=$true }) | Out-Null

    # ---- Table with totals on top, a traffic light and a mini chart without a total ----
    New-QvChart $doc $sh "${T}_TB_REGION" straight @(10,490,830,256) -Caption 'Regions at a Glance' -XL `
        -Dims @(@{ F='Region'; L='Region' }) -Exprs @(
            @{ D='Sum(Sales)'; L='Sales (EUR)'; Fmt='money' },
            @{ D='$(vSales_YoY)'; L='YoY %'; Fmt='growth'; TextColorExpr=("If(`$(vSales_YoY)>=0," + (Get-QvRgbExpr $C.Good) + "," + (Get-QvRgbExpr $C.Bad) + ")") },
            @{ D='Sum(Sales)'; L='Trend'; Repr='minichart'; Mini=@{ Dim='YearMonth'; Mode='line' }; NoTotal=$true },
            # traffic light on YoY growth: red < 0, amber 0..+3 %, green >= +3 % (lights must VARY across rows)
            @{ D='$(vSales_YoY)'; L='Growth'; Repr='traffic'; NoTotal=$true;
               Gauge=@{ Min='-0.2'; Max='0.2'; SingleLed=$true; Seg=@(@('-0.2',$C.Bad),@('0',$C.Warn),@('0.03',$C.Good)) } }
        ) | Out-Null

    Set-QvSheetOrder $doc
} finally {
    try { Exit-QvParking $doc $SheetId } catch { Write-Warning "parking cleanup: $_" }
    try { $doc.ClearAll($true) } catch {}
    Exit-QvLock -Owner $Owner
}
if (-not $NoShot) {
    [void]$doc.ActivateSheetById("Document\$SheetId"); [void](Get-QvApp).WaitForIdle(); Start-Sleep 5
    Save-QvScreenshot -Path "$QvBuildRoot\shots\$SheetId.png"     # LOOK at it before you call the sheet done
}
