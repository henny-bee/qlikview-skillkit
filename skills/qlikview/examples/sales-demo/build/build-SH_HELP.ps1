# build-SH_HELP.ps1 - About & Data Model (layout-spec section 7). Idempotent. UTF-8 with BOM (contains non-ASCII text).
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File build-SH_HELP.ps1 [-NoShot]
param([switch]$NoShot)
. "$PSScriptRoot\..\tools\lib-eng.ps1"; . "$PSScriptRoot\app-settings.ps1"
$G = $QS.Glyph; $C = $QS.C
$SheetId = 'SH_HELP'; $T = 'HELP'
$NL = "`r`n"

$about = @(
 'CL Distribution is a fictional pan-European B2B distributor of IT hardware, software and services. This demo app turns 1,000,000 transactions into a guided Dashboard → Analysis → Reports story.',
 '',
 '•  Data: 900,000 invoice lines + 100,000 credit-note lines = 1,000,000 transactions, plus a budget per sales rep and month (1,440 rows).',
 '•  Period: transactions 01/01/2024 – 30/09/2026, budget for all of 2026. CYTD = 1 Jan – 30 Sep 2026, PYTD = the same period of 2025.',
 '•  5,000 customers in 7 regions · 600 products in 6 categories · 40 sales reps in 8 teams · 4 channels.',
 '•  Currency EUR. The load script generates the data deterministically: every reload gives the same totals.'
) -join $NL

$howto = @(
 'SELECT AND FILTER',
 '•  Click any value, bar, slice or table row to select it. Every sheet follows the selection (green = selected, white = possible, grey = excluded).',
 '•  The left panel on the Analysis and Reports sheets shows the current selections, the period list boxes, a multi box with 8 filters and a search over all fields.',
 '•  "Clear selections" in the header removes every filter. Back / Forward in the toolbar step through your selections.',
 '',
 'NAVIGATE',
 '•  The header buttons open each sheet: Dashboard | Analysis | Reports | About.',
 '•  "Show help" / "Hide help" switches the blue "What am I looking at?" boxes on and off.',
 '•  Top N: the slider on Sales Analysis or the input box on Customers & Products.',
 '',
 'EXPORT',
 '•  The XL icon in a table caption sends the table to Excel. The line-level lists on Reports need 50,000 lines or fewer: select a month, region or customer first.',
 '',
 'DEMO STORIES',
 '•  The four buttons on the right apply a bookmark and open the sheet where the story shows. "Clear selections" brings you back to the full data.'
) -join $NL

$measures = @(
 'Net Sales = gross sales − line discounts (invoices)',
 'Net Revenue = net sales − credit notes',
 'Gross Margin = net sales − cost of sales;  GM % = gross margin / net sales',
 'Net Margin = gross margin − credit amount + cost reversal of returned goods;  NM % = net margin / net revenue',
 'Credit Rate = credit amount / net sales  (lower is better: green ≤ 5 %, amber 5–7 %, red > 7 %)',
 'Discount Rate = discount / gross sales',
 'Budget Achievement = net revenue / budget to date (budget months up to 30/09/2026; green ≥ 100 %, amber 95–100 %, red < 95 %). The full-year budget 2026 is shown separately and labelled "full-year budget".',
 'Invoices = distinct invoice numbers;  Avg Invoice Value = net sales / invoices',
 'Active Customers = customers with at least one invoice line',
 '',
 'PERIODS:  CYTD 01/01–30/09/2026 · PYTD 01/01–30/09/2025 · R12 Oct 2025–Sep 2026 · CM Sep 2026 · PM Aug 2026. Period KPIs ignore calendar selections; every other selection applies.',
 'YoY % = CYTD / PYTD − 1.  For ratios the change is shown in percentage points (pp).',
 'Budget exists per sales rep and month only: a customer, product or channel selection blanks the budget.'
) -join $NL

$groups = @(
 'CYCLIC GROUPS  (circular-arrow icon next to the dimension name)',
 'Click the circular arrow to switch to the next dimension, or use the small drop-down to pick one. The chart keeps its measure.',
 '•  cyc_Time: Year → Quarter → Month → Week → Weekday  (Sales Analysis trend)',
 '•  cyc_Dimension: Region, Category, Channel, Sales team, Segment, Brand  (Top N chart)',
 '•  cyc_Returns: Return reason, Reason group, Category  (Credit Notes)',
 '•  The Sales trend also cycles its measure (Net Sales, Net Revenue, Gross Margin, GM %, Discount Rate, Invoices).',
 '',
 'DRILL-DOWN GROUPS  (↑ drill-up arrow appears in the caption)',
 'Click a bar (or select one value) to go one level deeper. Click the drill-up arrow to go back.',
 '•  drl_Geography: Region → Country → City → Customer  (Customers & Products)',
 '•  drl_Product: Category → Product group → Product  (Customers & Products)',
 '•  drl_Sales: Sales team → Sales rep  (Team & Budget)',
 '•  drl_Time: Year → Quarter → Month → Date'
) -join $NL

Enter-QvLock -Owner engineer
try {
    $doc = Get-QvDoc
    Enter-EngParking $doc
    $sh = Reset-QvSheet $doc $SheetId 'About & Data Model'
    Step 'sheet reset'
    New-QvHeader $doc $sh $T -Active 'HELP' -Title 'About this app' `
        -Subtitle 'CL Distribution · fictional pan-European B2B IT distributor · data Jan 2024 – Sep 2026' `
        -Help 'What am I looking at?  What the app contains, how D-A-R (Dashboard → Analysis → Reports) guides you, how the data model works, the measure definitions, and the four demo stories.'
    Step 'header done'

    # ---------------- row 1: About + D-A-R cards ----------------
    New-QvText $doc $sh "${T}_TX_ABOUT_BG" @(10,96,540,200) -Bg $C.Card | Out-Null
    New-QvText $doc $sh "${T}_TX_ABOUT_H" @(24,104,512,22) -Text 'ABOUT THIS APP' -BgAlpha 0 -Fg $C.Muted -Size 8.5 -Bold -Margin 0 | Out-Null
    New-QvText $doc $sh "${T}_TX_ABOUT" @(24,128,516,162) -Text $about -BgAlpha 0 -Fg $C.Text -Size 8.5 -Margin 0 -VAlign 0 | Out-Null

    $cards = @(
        @{ K='D'; X=560;  Col=$QS.Cat[0]; Head='D  ·  DASHBOARD'; Q='How are we doing?'; Sheet='SH_DASH'; Btn='Open Dashboard';
           Body='Six headline KPIs for Jan – Sep 2026 against last year, a budget gauge, a credit-rate light, the monthly trend, the channel mix and the regions at a glance. Get the answer in 5 seconds.' },
        @{ K='A'; X=940;  Col=$QS.Cat[2]; Head='A  ·  ANALYSIS'; Q='Why?'; Sheet='SH_SALES'; Btn='Open Sales Analysis';
           Body='Four Analysis sheets: Sales, Customers & Products, Credit Notes, Team & Budget. The same filter panel on the left, plus cyclic and drill-down groups to slice the data any way.' },
        @{ K='R'; X=1320; Col=$QS.Cat[4]; Head='R  ·  REPORTS'; Q='Show me the rows.'; Sheet='SH_REPORT'; Btn='Open Reports';
           Body='P&L pivot by region and year, category × quarter, a customer statement, credit-note lines and invoice lines. Every table exports to Excel (XL icon).' }
    )
    foreach ($cd in $cards) {
        $k = $cd.K; $x = $cd.X
        New-QvText $doc $sh "${T}_DAR_${k}_BG" @($x,96,360,200) -Bg $C.Card | Out-Null
        New-QvText $doc $sh "${T}_DAR_${k}_HEAD" @($x,96,360,32) -Text $cd.Head -Bg $cd.Col -Fg $C.White -Size 10 -Bold -Margin 10 | Out-Null
        New-QvText $doc $sh "${T}_DAR_${k}_Q" @(($x+12),134,336,22) -Text $cd.Q -BgAlpha 0 -Fg $C.Text -Size 10 -Bold -Margin 0 | Out-Null
        New-QvText $doc $sh "${T}_DAR_${k}_TX" @(($x+12),158,336,90) -Text $cd.Body -BgAlpha 0 -Fg $C.Text -Size 8.5 -Margin 0 -VAlign 0 | Out-Null
        New-QvButton $doc $sh "${T}_DAR_${k}_BTN" @(($x+12),254,180,30) -Text ($cd.Btn + '  →') -Actions @(@{ Type='sheet'; P=@($cd.Sheet) }) -Bg $cd.Col -Fg $C.White -Size 9 -Bold | Out-Null
    }
    Step 'row 1 done'

    # ---------------- data model diagram (10,306,830,440) ----------------
    New-QvText $doc $sh "${T}_DM_BG" @(10,306,830,440) -Bg $C.Card | Out-Null
    New-QvText $doc $sh "${T}_DM_H" @(24,312,800,24) -Text 'DATA MODEL  ·  one link table joins the three fact tables (no synthetic keys, no loops)' -BgAlpha 0 -Fg $C.Muted -Size 8.5 -Bold -Margin 0 | Out-Null
    $dims = @(
        @{ N='Calendar';  D='%DateKey · Year, Quarter, Month, Week · 1,096 days · flags CYTD, PYTD, R12, CM' },
        @{ N='Customers'; D='CustomerID · name, segment, city, country, region · 5,000' },
        @{ N='Products';  D='ProductID · product, group, category, brand · 600' },
        @{ N='SalesReps'; D='SalesRepID · rep, team, manager · 40 reps in 8 teams' },
        @{ N='Channels';  D='ChannelID · Direct Sales, E-Commerce, Distributor, Retail Partner' }
    )
    $dy = 346
    $i = 0
    foreach ($d in $dims) {
        $y = $dy + $i * 64
        New-QvText $doc $sh "${T}_DM_DIM$i" @(24,$y,200,54) -Text ($d.N + $NL + $d.D) -Bg $C.InfoBg -Fg $C.InfoText -Size 8 -Margin 6 -VAlign 4 | Out-Null
        New-QvText $doc $sh "${T}_DM_DIM${i}_L" @(224,($y+26),46,2) -Bg $C.Muted | Out-Null
        $i++
    }
    New-QvText $doc $sh "${T}_DM_BUSL" @(270,373,2,258) -Bg $C.Muted | Out-Null
    New-QvText $doc $sh "${T}_DM_BUSL2" @(270,500,60,2) -Bg $C.Muted | Out-Null
    New-QvText $doc $sh "${T}_DM_LINK" @(330,446,180,110) -Text ('LinkTable' + $NL + '%LinkKey = date | customer |' + $NL + 'product | rep | channel' + $NL + '991,628 key combinations' + $NL + 'LinkSource: Invoice / CreditNote / Budget') -Bg $C.Navy -Fg $C.White -Size 8 -Margin 8 -HAlign 1 -VAlign 4 | Out-Null
    $facts = @(
        @{ Id='INV'; Y=350; N='Invoices  ·  900,000 lines'; D='%LinkKey · InvoiceNo, Quantity, GrossSales, Discount, NetSales, CostOfSales, GrossMargin' },
        @{ Id='CN';  Y=470; N='CreditNotes  ·  100,000 lines'; D='%LinkKey · CreditNoteNo, CreditAmount, CreditCost, CN_OrigInvoiceNo (not associated)' },
        @{ Id='BUD'; Y=600; N='Budget  ·  1,440 rows'; D='%LinkKey (sales rep × month) · BudgetNetSales, BudgetGrossMargin' }
    )
    foreach ($f in $facts) {
        New-QvText $doc $sh "${T}_DM_$($f.Id)" @(600,$f.Y,226,56) -Text ($f.N + $NL + $f.D) -Bg $C.Primary -Fg $C.White -Size 8 -Margin 6 -VAlign 4 | Out-Null
    }
    New-QvText $doc $sh "${T}_DM_RR" @(640,548,186,40) -Text ('ReturnReasons  ·  8 reasons' + $NL + 'ReturnReasonID · reason, reason group') -Bg $C.InfoBg -Fg $C.InfoText -Size 8 -Margin 6 -VAlign 4 | Out-Null
    New-QvText $doc $sh "${T}_DM_RR_L" @(712,526,2,22) -Bg $C.Muted | Out-Null
    # right side: line/arrow objects from the link table to the facts
    New-EngLine $doc $sh "${T}_DM_BUSR" @(550,378,12,250) -Orient 0 -Weight 2 -FromPt 1 -ToPt 5
    New-EngLine $doc $sh "${T}_DM_LR"   @(510,494,46,12) -Orient 0 -Weight 2
    New-EngLine $doc $sh "${T}_DM_A_INV" @(555,372,46,12) -Orient 1 -Weight 2
    New-EngLine $doc $sh "${T}_DM_A_CN"  @(555,492,46,12) -Orient 1 -Weight 2
    New-EngLine $doc $sh "${T}_DM_A_BUD" @(555,622,46,12) -Orient 1 -Weight 2
    New-QvText $doc $sh "${T}_DM_NOTE" @(24,672,802,68) -BgAlpha 0 -Fg $C.Muted -Size 8 -Margin 0 -VAlign 0 -Text (@(
        'Fact tables carry no dimension key except %LinkKey (and ReturnReasonID on credit notes). A credit note inherits customer, product, rep and channel of its original invoice line and is dated on the credit-note date.',
        'Budget rows have only month + sales rep, so customer, product or channel selections blank the budget. %-fields are hidden technical keys.') -join $NL) | Out-Null
    Step 'data model done'

    # ---------------- guide container (850,306,420,440): How to use | Measures | Groups ----------------
    $tr = @(850,306,420,440)
    New-QvText $doc $sh "${T}_TX_HOWTO" $tr -Text $howto -Bg $C.Card -Fg $C.Text -Size 8.5 -Margin 10 -VAlign 0 -Caption 'How to use this app' | Out-Null
    New-QvText $doc $sh "${T}_TX_MEASURES" $tr -Text $measures -Bg $C.Card -Fg $C.Text -Size 8.5 -Margin 10 -VAlign 0 -Caption 'Measure definitions' | Out-Null
    New-QvText $doc $sh "${T}_TX_GROUPS" $tr -Text $groups -Bg $C.Card -Fg $C.Text -Size 8.5 -Margin 10 -VAlign 0 -Caption 'Cyclic and drill-down groups' | Out-Null
    New-EngContainer $doc $sh "${T}_CT_GUIDE" $tr -Items @(
        @{ Id="${T}_TX_HOWTO"; T='How to use' }, @{ Id="${T}_TX_MEASURES"; T='Measures' }, @{ Id="${T}_TX_GROUPS"; T='Groups' }) -TabMode 0
    Step 'guide done'

    # ---------------- demo stories (1280,306,400,440) ----------------
    New-QvSectionHead $doc $sh "${T}_STORY_H" @(1280,306,400,24) 'Demo stories  ·  apply the bookmark and open the sheet' -Bg $C.PanelHead | Out-Null
    $stories = @(
        @{ N=1; T='Story 1  –  Networking quality issue';   Sheet='SH_CN' },
        @{ N=2; T='Story 2  –  Seasonality and growth';      Sheet='SH_SALES' },
        @{ N=3; T='Story 3  –  UK & Ireland below budget';  Sheet='SH_TEAM' },
        @{ N=4; T='Story 4  –  E-Commerce discounts';       Sheet='SH_SALES' }
    )
    foreach ($s in $stories) {
        $y = 336 + ($s.N - 1) * 54
        New-QvButton $doc $sh "${T}_STORY_$($s.N)" @(1280,$y,400,44) -Text ($s.T + '   →') -Bg $C.Primary -Fg $C.White -Size 9.5 -Bold `
            -Actions @(@{ Type='clear' }, @{ Type='bookmark'; P=@("Document\BM_STORY$($s.N)") }, @{ Type='sheet'; P=@($s.Sheet) }) | Out-Null
    }
    New-EngBookmarkObj $doc $sh "${T}_BM" @(1280,560,400,56) -Caption 'Bookmarks (document)'
    New-QvText $doc $sh "${T}_STORY_TX" @(1280,622,400,124) -Bg $C.Card -Fg $C.Text -Size 8 -Margin 8 -VAlign 0 -Text (@(
        'WHAT TO LOOK FOR',
        '1  Credit Notes: Networking credit rate 2.8 % → 9.0 % (2024 → 2026).',
        '2  Sales: Q4 peak, August dip; CEE +14 %, UK & Ireland −2 % (CYTD).',
        '3  Team & Budget: UK & Ireland at 88 % of budget to date, others 99–105 %.',
        '4  Sales: E-Commerce 14.8 % discount, 17.9 % margin, +15.6 % growth.') -join $NL) | Out-Null
    Step 'stories done'
} finally {
    try { Exit-EngParking $doc $SheetId } catch { Write-Warning "parking cleanup: $_" }
    Exit-QvLock -Owner engineer
}

if (-not $NoShot) {
    $doc = Get-QvDoc
    Invoke-QvRetry { $doc.ActivateSheetById("Document\$SheetId") } | Out-Null
    Save-QvScreenshot -Path "$QvBuildRoot\shots\SH_HELP.png" | Out-Null
    "shot: $QvBuildRoot\shots\SH_HELP.png"
}
