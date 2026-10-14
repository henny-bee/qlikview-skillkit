# build-SH_REPORT.ps1 - Reports (R of D-A-R), layout-spec section 6. Idempotent: clears the sheet and rebuilds every object.
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File build-SH_REPORT.ps1 [-NoShot]
param([switch]$NoShot)
. "$PSScriptRoot\..\tools\lib-eng.ps1"; . "$PSScriptRoot\app-settings.ps1"
$G = $QS.Glyph; $C = $QS.C; $E = $G.Eur
$SheetId = 'SH_REPORT'; $T = 'REP'

Enter-QvLock -Owner engineer
try {
    $doc = Get-QvDoc
    Enter-EngParking $doc
    $sh = Reset-QvSheet $doc $SheetId 'Reports'
    Step 'sheet reset'

    New-QvHeader $doc $sh $T -Active 'REP' -Title 'Reports' `
        -Subtitle ("Detail tables for export (XL icon in the caption) and printing   " + $G.Mid + "   all tables respect your selections") `
        -Help ("What am I looking at?  Choose a report tab. Use the XL icon in a table caption to export to Excel. The line-level lists (credit notes, invoice lines) appear once 50,000 lines or fewer are selected: pick a month, region or customer first.")
    Step 'header done'

    # ---------------- filter panel (0b) + section 5 ----------------
    New-EngFilterPanel $doc $sh $T -Section5 'Date range / stats'
    New-EngCalendar $doc $sh "${T}_FLT_CAL" @(14,606,202,26) 'Date'
    New-EngStatBox $doc $sh "${T}_FLT_SB" @(14,636,202,106) 'NetSales' -Caption ("Net Sales per line (" + $E + ")")
    Step 'panel section 5 done'

    # ---------------- report objects (created on the sheet, then moved into the container) ----------------
    $tab = @(230,126,1450,620)
    $pl = New-QvChart $doc $sh "${T}_PT_PL" pivot $tab -Caption ("P&L by Region and Year (" + $E + ")") -XL -Totals `
        -HelpText 'Rows: region (click + to open countries) and the P&L lines. Columns: years and total. Net margin = gross margin - credit notes + cost reversals.' `
        -Dims @(@{ F='CustomerRegion'; L='Region'; NoNull=$true }, @{ F='CustomerCountry'; L='Country'; NoNull=$true }, @{ F='Year'; L='Year'; NoNull=$true }) `
        -Exprs @(
            @{ D='$(vGrossSales)';   L='Gross Sales';   Fmt='money' },
            @{ D='$(vDiscount)';     L='Discount';      Fmt='money' },
            @{ D='$(vNetSales)';     L='Net Sales';     Fmt='money' },
            @{ D='$(vCreditAmount)'; L='Credit Notes';  Fmt='money' },
            @{ D='$(vNetRevenue)';   L='Net Revenue';   Fmt='money' },
            @{ D='$(vGrossMargin)';  L='Gross Margin';  Fmt='money' },
            @{ D='$(vNetMargin)';    L='Net Margin';    Fmt='money' },
            @{ D='$(vNetMarginPct)'; L='Net Margin %';  Fmt='pct' }
        ) -Configure {
            param($p)
            $tp = $p.TableProperties
            for ($k = 0; $k -lt $p.Dimensions.Count; $k++) { try { $p.Dimensions.Item($k).ShowPartialSums = 1 } catch { Write-Warning "partial sums: $_" } }
        }
    Set-EngPivotLayout $doc $sh $pl -ExprPos 2 -LeftDims 3 -Rect $tab | Out-Null
    Step 'PT_PL done'

    $pp = New-QvChart $doc $sh "${T}_PT_PROD" pivot $tab -Caption ("Net Revenue (" + $E + " thousand) and Net Margin % by Product Category and Quarter") -XL -Totals `
        -HelpText 'Rows: category (click + to open product groups). Columns: year and quarter (click + on a year). Budget is not used here, so every selection works.' `
        -Dims @(@{ F='ProductCategory'; L='Category'; NoNull=$true }, @{ F='ProductGroup'; L='Product group'; NoNull=$true }, @{ F='Year'; L='Year'; NoNull=$true }, @{ F='Quarter'; L='Quarter'; NoNull=$true }) `
        -Exprs @(
            @{ D='$(vNetRevenue)/1000'; L=("Net Revenue (" + $E + " k)"); Fmt='#,##0' },
            @{ D='$(vNetMarginPct)';    L='Net Margin %';  Fmt='pct' }
        ) -Configure {
            param($p)
            $tp = $p.TableProperties
            try { $tp.NumberOfLeftDimensions = 2 } catch { Write-Warning "leftdims: $_" }
            for ($k = 0; $k -lt $p.Dimensions.Count; $k++) { try { $p.Dimensions.Item($k).ShowPartialSums = 1 } catch {} }
        }
    try { [void]$pp.SetPixWidth(0, 170); [void]$pp.SetPixWidth(1, 170) } catch { Write-Warning "prod widths: $_" }
    Step 'PT_PROD done'

    $cu = New-QvChart $doc $sh "${T}_ST_CUST" straight $tab -Caption ("Customer Statement " + $G.Dash + " all periods in the selection (" + $E + ")") -XL `
        -HelpText 'One row per customer, sorted by net revenue. Totals on top. Click a customer to filter the whole app.' `
        -Dims @(@{ F='CustomerName'; L='Customer'; NoNull=$true; SortExpr='$(vNetRevenue)'; SortDesc=$true; ColWidth=760 }, @{ F='CustomerCountry'; L='Country'; NoNull=$true; ColWidth=360 }, @{ F='CustomerSegment'; L='Segment'; NoNull=$true }) `
        -Exprs @(
            @{ D='$(vInvoices)';       L='Invoices';       Fmt='int' },
            @{ D='$(vNetSales)';       L=("Net Sales (" + $E + ")");     Fmt='money' },
            @{ D='$(vCreditAmount)';   L=("Credit Notes (" + $E + ")");  Fmt='money' },
            @{ D='$(vNetRevenue)';     L=("Net Revenue (" + $E + ")");   Fmt='money' },
            @{ D='$(vGrossMarginPct)'; L='Gross Margin %'; Fmt='pct' },
            @{ D='$(vCreditRate)';     L='Credit Rate';    Fmt='pct'; TextColorExpr=("If(`$(vCreditRate)>0.07," + (Get-QvRgbExpr $C.Bad) + ",If(`$(vCreditRate)>0.05," + (Get-QvRgbExpr $C.Warn) + "," + (Get-QvRgbExpr $C.Text) + "))") }
        ) -Configure { param($p) $p.TableProperties.TableTotalPosition = 0 }
    Step 'ST_CUST done'

    $script:MsgTooMany = 'More than 50,000 lines are selected. Select a month, region, customer or product first (left panel).'
    New-EngTableBox $doc $sh "${T}_TB_CN" $tab -Caption 'Credit Note Lines (shown for 50,000 lines or fewer)' -CalcCond 'Count(CreditNoteLineID)<=50000' `
        -HelpText 'Table box: every credit-note line with its original invoice. Select a period, region or customer first (at most 50,000 lines).' `
        -Cols @(
            @{ F='CreditNoteNo'; L='Credit note'; W=380 }, @{ F='CreditNoteLineNo'; L='Line'; W=150 }, @{ F='CreditNoteDate'; L='Date'; W=260 }, @{ F='CN_OrigInvoiceNo'; L='Original invoice'; W=380 },
            @{ F='CustomerName'; L='Customer'; W=600 }, @{ F='ProductName'; L='Product'; W=600 }, @{ F='ReturnReason'; L='Reason'; W=420 },
            @{ F='CreditQty'; L='Qty'; Fmt='int' }, @{ F='CreditAmount'; L=("Amount (" + $E + ")"); Fmt='money' })
    Step 'TB_CN done'

    $iv = New-QvChart $doc $sh "${T}_ST_INV" straight $tab -Caption ("Invoice Lines (detail, shown for 50,000 lines or fewer) (" + $E + ")") -XL `
        -CalcCond 'Count(InvoiceLineID)<=50000' `
        -HelpText 'Invoice-line detail for export. Select a month, region, customer or product first (at most 50,000 lines).' `
        -Dims @(@{ F='InvoiceNo'; L='Invoice'; NoNull=$true; ColWidth=400 }, @{ F='InvoiceLineNo'; L='Line'; NoNull=$true; ColWidth=140 }, @{ F='InvoiceDate'; L='Date'; NoNull=$true; ColWidth=260 },
                @{ F='CustomerName'; L='Customer'; NoNull=$true; ColWidth=560 }, @{ F='ProductName'; L='Product'; NoNull=$true; ColWidth=600 }, @{ F='Channel'; L='Channel'; NoNull=$true; ColWidth=280 }) `
        -Exprs @(
            @{ D='Sum(Quantity)';    L='Qty';                          Fmt='int' },
            @{ D='If(Dimensionality()=0, '''', Only(UnitPrice))';  L=("Unit price (" + $E + ")");    Fmt=($E + ' #,##0.00') },
            @{ D='Sum(Discount)';    L=("Discount (" + $E + ")");      Fmt='money' },
            @{ D='Sum(NetSales)';    L=("Net Sales (" + $E + ")");     Fmt='money' },
            @{ D='Sum(GrossMargin)'; L=("Gross Margin (" + $E + ")");  Fmt='money' }
        ) -Configure { param($p) $p.TableProperties.TableTotalPosition = 0
            $em = $p.GraphLayout.ErrorMessageOverrides; while ($em.Count -lt 6) { [void]$em.Add() }
            $em.Item(5).v = $script:MsgTooMany }
    Step 'ST_INV done'

    New-EngContainer $doc $sh "${T}_CT_MAIN" @(230,96,1450,650) -Items @(
        @{ Id="${T}_PT_PL";   T='P&L by Region' },
        @{ Id="${T}_PT_PROD"; T='Category x Quarter' },
        @{ Id="${T}_ST_CUST"; T='Customer Statement' },
        @{ Id="${T}_TB_CN";   T='Credit Note Lines' },
        @{ Id="${T}_ST_INV";  T='Invoice Lines' })
    Step 'container done'

    # ---------------- column widths in pixels (container content ~1320 px wide): render each tab once, then size it ----------------
    [void]$doc.ActivateSheetById("Document\$SheetId")
    $ct = $doc.GetSheetObject("Document\${T}_CT_MAIN")
    $W = @{
        0 = @{ Id="${T}_PT_PL";   Pivot=@(170,150,170,175,225,225,225,225) }
        1 = @{ Id="${T}_PT_PROD"; Pivot=@(185,185,140,140,140,140,140,140,140,140) }
        2 = @{ Id="${T}_ST_CUST"; Straight=@(300,130,120,90,135,125,135,110,100) }
        4 = @{ Id="${T}_ST_INV";  Straight=@(130,45,85,215,230,105,65,100,105,125,125) }
    }
    foreach ($k in 0,1,2,4) {
        [void]$ct.ShowSingleObject($k); (Get-QvApp).WaitForIdle()
        $o = $doc.GetSheetObject("Document\" + $W[$k].Id)
        if ($W[$k].Pivot) { for ($c = 0; $c -lt $W[$k].Pivot.Count; $c++) { try { $o.SetPixWidth($c, [int16]$W[$k].Pivot[$c]) } catch { Write-Warning "pix $k/$c : $_" } } }
        else { try { $o.SetPixWidths(0, [object[]]$W[$k].Straight) } catch { Write-Warning "pixs $k : $_" } }
    }
    [void]$ct.ShowSingleObject(0)
    Step 'widths done'
} finally {
    try { Exit-EngParking $doc $SheetId } catch { Write-Warning "parking cleanup: $_" }
    Exit-QvLock -Owner engineer
}

if (-not $NoShot) {
    $doc = Get-QvDoc
    Invoke-QvRetry { $doc.ActivateSheetById("Document\$SheetId") } | Out-Null
    Save-QvScreenshot -Path "$QvBuildRoot\shots\SH_REPORT.png" | Out-Null
    "shot: $QvBuildRoot\shots\SH_REPORT.png"
}
