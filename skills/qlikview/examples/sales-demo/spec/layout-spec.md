# QLIK-CL Layout Spec (v1, owned by Designer)

Read with `spec/style-guide.md` (tokens, components) and `spec/data-contract.md` (names). Every rect is `L, T, W, H` in pixels
at 100% zoom on the **1690 x 755** canvas. Nothing may extend beyond x = 1690 or y = 746.
Builder: `designer/build-SH_<X>.ps1` (idempotent: it clears the sheet and rebuilds every object with fixed IDs).

Expression notation: `$(vX)` means a contract variable. `SETCY` / `SETPY` mean `$(vSetCY)` / `$(vSetPY)`, the full-calendar-year
sets requested from the Engineer. Until those exist, the fallback is the inline set
`{<Year={$(=Year(vDataEndDateNum))},Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=>}` (PY: `-1`).
NR means Net Revenue: `$(vNetRevenue)` respects selections, and its raw form is `Sum(NetSales)-Sum(CreditAmount)`.

---------------------------------------------------------------------------------------------------------------------
## 0. Common chrome (identical on every sheet; TAG = DASH | SALES | CUST | CN | TEAM | REP | HELP)

```
y=0   +------------------------------------------------------------------------------------------------------+
      | CL Distribution  [Dashboard] | [Sales][Customers & Products][Credit Notes][Team & Budget] | [Reports] | [About]   Data through 30/09/2026 · EUR  [Clear selections] [Show/Hide help] |
y=48  +------------------------------------------------------------------------------------------------------+
y=52  Page title (13pt)                                                 | i What am I looking at? (help box)         |
y=76  subtitle (8.5pt muted)                                            |                                            |
y=96  ---- content ----
```
| ID | Type | Rect | Content / action |
|---|---|---|---|
| `<T>_HDR_BG` | Text | 0,0,1690,48 | Navy band (layer bottom) |
| `<T>_HDR_APP` | Text | 14,4,200,24 | "CL Distribution", 14 pt bold white, transparent |
| `<T>_HDR_SUB` | Text | 14,27,200,16 | "SALES COCKPIT · D-A-R", 8 pt NavText |
| `<T>_NAV_DASH` | Button | 230,9,110,30 | "Dashboard" → Activate Sheet SH_DASH |
| `<T>_NAV_SALES` | Button | 354,9,84,30 | "Sales" → SH_SALES |
| `<T>_NAV_CUST` | Button | 442,9,170,30 | "Customers & Products" → SH_CUST |
| `<T>_NAV_CN` | Button | 616,9,116,30 | "Credit Notes" → SH_CN |
| `<T>_NAV_TEAM` | Button | 736,9,126,30 | "Team & Budget" → SH_TEAM |
| `<T>_NAV_REP` | Button | 876,9,96,30 | "Reports" → SH_REPORT |
| `<T>_NAV_HELP` | Button | 986,9,84,30 | "About" → SH_HELP |
| `<T>_HDR_STAMP` | Text | 1084,9,340,30 | `='Data through ' & vDataEndDate & '  ·  all amounts in EUR'`, right-aligned, 8 pt NavText |
| `<T>_HDR_CLEAR` | Button | 1432,9,116,30 | "Clear selections" → Clear All |
| `<T>_HDR_HELP` | Button | 1554,9,126,30 | `=If(vShowHelp=1,'Hide help','Show help')` → Set Variable vShowHelp = `=If(vShowHelp=1,0,1)` |
| `<T>_TTL` | Text | 10,52,700,24 | sheet title, 13 pt bold |
| `<T>_SUB` | Text | 10,76,700,18 | subtitle (period logic), 8.5 pt Muted |
| `<T>_HELP_SHEET` | Text | 900,52,780,40 | "What am I looking at?" box, shown when `vShowHelp=1` |

The active sheet's NAV button is Primary with white bold text, and the others are Navy2 with NavText.
The gaps (14 px) separate D | A | R | Help.

## 0b. Filter panel (Analysis sheets SALES, CUST, CN, TEAM, and REPORT): x 10..220, y 96..746
| ID | Type | Rect | Content |
|---|---|---|---|
| `<T>_FLT_BG` | Text | 10,96,210,650 | Panel fill (layer bottom) |
| `<T>_FLT_H1` | Text | 10,96,210,20 | "CURRENT SELECTIONS" section header |
| `<T>_FLT_CS` | Current Selections Box | 14,118,202,84 | field and values, no caption |
| `<T>_FLT_H2` | Text | 10,206,210,20 | "PERIOD" |
| `<T>_FLT_LB_YEAR` | List Box | 14,228,202,24 | Year, 3 columns, no caption |
| `<T>_FLT_LB_QTR` | List Box | 14,254,202,24 | Quarter, 4 columns |
| `<T>_FLT_LB_MONTH` | List Box | 14,280,202,44 | Month, 6 columns x 2 rows |
| `<T>_FLT_H3` | Text | 10,330,210,20 | "FILTERS" |
| `<T>_FLT_MB` | Multi Box | 14,352,202,172 | CustomerRegion, CustomerCountry, ProductCategory, ProductGroup, Channel, CustomerSegment, SalesTeam, Brand (labels: Region, Country, Category, Product group, Channel, Segment, Sales team, Brand) |
| `<T>_FLT_H4` | Text | 10,530,210,20 | "SEARCH" |
| `<T>_FLT_SO` | Search Object | 14,552,202,26 | all fields |
| `<T>_FLT_H5` | Text | 10,584,210,20 | sheet-specific section header |
| sheet-specific | | 14,606,202,136 | see each sheet |

---------------------------------------------------------------------------------------------------------------------
## 1. SH_DASH "Dashboard" (D): how are we doing this year?
Title "Dashboard", subtitle "Year to date Jan–Sep 2026 (CYTD) vs same period 2025 (PYTD) · budget 2026".
Help: "ⓘ What am I looking at? Six headline KPIs for the current year to date, each against last year. The gauges show budget
achievement and the credit rate status. Click any chart to filter, and use the Analysis sheets to find out why."

```
y=96  [KPI1 Net Sales][KPI2 Net Revenue][KPI3 Budget ach.][KPI4 Net margin %][KPI5 Credit rate][KPI6 Invoices]   (6 x 270 x 118)
y=224 [ Net Revenue by Month CY vs PY vs Budget (combo) 830 ] [Budget gauge 270] [ Channel mix (pie) 550 ]
y=490 [ Regions at a glance (straight table, mini-charts) 830 ] [Credit LED 270] [ Credit rate by category (bar) 550 ]
y=746
```
KPI tiles: x = 10, 290, 570, 850, 1130, 1410, y = 96, w = 270, h = 118. IDs `DASH_KPI<n>_{BG,BAR,LBL,VAL,DLT,CTX}`.
| n | Label | Value | Delta (colour rule) | Context line |
|---|---|---|---|---|
| 1 | NET SALES · CYTD | `Num($(vNetSales_CYTD)/1e6,'€ #,##0.0')&' M'` | `$(vNetSales_YoY)` → `▲/▼ +x.x% vs PY` (≥0 good) | `'PY € '&Num($(vNetSales_PYTD)/1e6,'#,##0.0')&' M  ·  R12 € '&Num($(vNetSales_R12)/1e6,'#,##0.0')&' M'` |
| 2 | NET REVENUE · CYTD | `$(vNetRevenue_CYTD)` in M | `$(vNetRevenue_YoY)` | `'after credit notes  ·  PY € …M'` |
| 3 | BUDGET ACHIEVEMENT · CYTD | `Num($(vBudgetAch_CYTD),'0.0%')` | `NR CYTD − Budget CYTD` in € M with ▲/▼ (≥0 good; bar colour uses the 95/100 rule) | `'Budget € '&…$(vBudget_CYTD)…&' M'` |
| 4 | NET MARGIN % · CYTD | `Num($(vNetMarginPct_CYTD),'0.0%')` | `$(vNetMarginPct_YoYpp)` in pp (≥0 good) | `'Net margin € '&…$(vNetMargin_CYTD)…&' M'` |
| 5 | CREDIT RATE · CYTD | `Num($(vCreditRate_CYTD),'0.0%')` | `$(vCreditRate_YoYpp)` in pp (**≤0 good**) | `'Credit notes € '&…$(vCreditAmount_CYTD)…&' M'` |
| 6 | INVOICES · CYTD | `Num($(vInvoices_CYTD),'#,##0')` | `$(vInvoices_YoY)` | `'Avg € '&Num($(vAvgInvoiceValue_CYTD),'#,##0')&'  ·  '&Num($(vActiveCustomers_CYTD),'#,##0')&' active customers'` |

The accent bar (`_BAR`, 4 x 118) takes the delta's status colour (KPI3 and KPI5 use the threshold rules in style guide §3).

| ID | Type | Rect | Title (caption) | Dimensions | Expressions | Purpose |
|---|---|---|---|---|---|---|
| `DASH_CH_TREND` | Combo | 10,224,830,256 | Net Revenue by Month (€) – 2026 vs 2025 vs Budget | Month | bars "2026 actual" `$(vNetRevenue_CYTD)` Primary; line "2025 actual" `Sum(SETPY NetSales)-Sum(SETPY CreditAmount)` PY grey; line "2026 budget" `Sum(SETCY BudgetNetSales)` Budget amber dashed | trend and seasonality, gap to budget |
| `DASH_GA_BUDGET` | Gauge (speedometer) | 850,224,270,256 | Budget Achievement CYTD (%) | – | `$(vBudgetAch_CYTD)`, range 0.80–1.20, segments Bad <0.95, Warn 0.95–1.00, Good ≥1.00; chart text shows the value | status at a glance |
| `DASH_CH_CHANNEL` | Pie | 1130,224,550,256 | Net Revenue Share by Channel – CYTD (%) | Channel | `$(vNetRevenue_CYTD)`, legend shows %, cat palette | mix |
| `DASH_TB_REGION` | Straight table | 10,490,830,256 | Regions at a Glance – CYTD | CustomerRegion | Net Revenue CYTD (€) `$(vNetRevenue_CYTD)`; YoY % `$(vNetRevenue_YoY)` text colour + ▲▼; Trend R12 = **mini-chart** sparkline of `$(vNetRevenue)` over YearMonth with set `$(vSetR12)`; Net Margin % `$(vNetMarginPct_CYTD)`; Credit Rate `$(vCreditRate_CYTD)` with **traffic light** (style-guide thresholds); totals on top | where we are good or bad |
| `DASH_GA_CREDIT` | Gauge (LED / traffic light) | 850,490,270,256 | Credit Rate CYTD (%) – Status | – | `$(vCreditRate_CYTD)`: traffic light Good ≤5%, Warn ≤7%, Bad >7%; text: value + "vs PY x pp" | quality signal |
| `DASH_CH_CATCR` | Bar (horizontal) | 1130,490,550,256 | Credit Rate by Product Category (%) – CYTD vs PYTD | ProductCategory | "CYTD" `$(vCreditRate_CYTD)` with bar colour by thresholds; "PYTD" `$(vCreditRate_PYTD)` PY grey; sorted by CYTD desc | points to story 1 (Networking) |

---------------------------------------------------------------------------------------------------------------------
## 2. SH_SALES "Sales Analysis" (A): stories 2 (seasonality and growth) and 4 (E-Commerce discounts)
Title "Sales Analysis", subtitle "All values respect your selections · use ⟳ in a caption to switch dimension or measure".
Help: "ⓘ Trend over time (switch Year / Quarter / Month / Week / Weekday), seasonality per year, the Top N of any dimension, and the
channel economics: discount vs margin. Set Top N with the slider in the left panel."
Panel section 5 "TOP N": `SALES_FLT_SL_TOPN` Slider on variable `vTopN` (3–25, step 1) at 14,606,202,44, plus help text
`SALES_HELP_PANEL` at 14,656,202,86: "ⓘ Cyclic groups (⟳) switch the dimension. Click a bar to select it."

```
y=96  [ Trend by <cyc_Time> – cyclic measure (bar) 950 x 310 ] [ Seasonality: Net Sales by Month per Year (line) 490 ]
y=416 [ Top N by <cyc_Dimension> (bar) 560 x 330 ] [ Region x Channel (Mekko) 440 ] [ Container: Discount vs Margin | Growth by Channel 430 ]
```
| ID | Type | Rect | Title | Dimensions | Expressions | Purpose |
|---|---|---|---|---|---|---|
| `SALES_CH_TREND` | Bar (combo for the PY line) | 230,96,950,310 | `='Trend by '&GetCurrentField(cyc_Time)` | `cyc_Time` (cyclic) | **cyclic expression group**: Net Sales (€) `$(vNetSales)` · Net Revenue (€) `$(vNetRevenue)` · Gross Margin (€) `$(vGrossMargin)` · Gross Margin % `$(vGrossMarginPct)` · Discount Rate % `$(vDiscountRate)` · Invoices `$(vInvoices)` | trend, growth |
| `SALES_CH_SEASON` | Line | 1190,96,490,310 | Seasonality – Net Sales by Month per Year (€) | Month, Year | `$(vNetSales)`; one line per year, cat palette (2026 Primary) | story 2: Q4 peak, Aug dip |
| `SALES_CH_TOPN` | Bar (horizontal) | 230,416,560,330 | `='Top '&vTopN&' by '&GetCurrentField(cyc_Dimension)&' – Net Sales (€)'` | `cyc_Dimension`, limited to the largest `vTopN` | `$(vNetSales)` Primary; sorted desc | ranking |
| `SALES_CH_MEKKO` | Mekko | 800,416,440,330 | Net Sales by Region and Channel (€, share) | CustomerRegion, Channel | `$(vNetSales)`, cat palette per channel | mix, E-Commerce share per region |
| `SALES_CT_CHAN` | Container (2 tabs) | 1250,416,430,330 | Channel Economics | – | tab 1 `SALES_CH_SCATTER`, tab 2 `SALES_CH_CHGROW` | story 4 |
| `SALES_CH_SCATTER` | Scatter (bubble) | (in container) | Discount Rate vs Gross Margin % (bubble = Net Sales) | CustomerRegion, Channel | X `$(vDiscountRate)`, Y `$(vGrossMarginPct)`, size `$(vNetSales)` | E-Commerce high discount and low margin |
| `SALES_CH_CHGROW` | Bar | (in container) | Net Sales Growth by Channel – CYTD vs PYTD (%) | Channel | `$(vNetSales_YoY)` (colour Good/Bad) | E-Commerce grows fastest |

---------------------------------------------------------------------------------------------------------------------
## 3. SH_CN "Credit Notes" (A): story 1 (Networking quality issue)
Title "Credit Notes & Returns", subtitle "Credit rate = Credit amount / Net sales · lower is better".
Help: "ⓘ Which products and reasons drive credit notes? Watch the Networking line in the credit-rate trend and the
'Quality' reasons. Switch reason, reason group or category with ⟳."
Panel section 5 "RETURN REASON": `CN_FLT_LB_REASON` List Box ReturnReason at 14,606,202,136 (8 values, frequency off).

```
y=96  [mini KPI Credit amount][mini KPI Credit rate][mini KPI Credit notes][mini KPI Quality share]   (4 x 355 x 64)
y=170 [ Credit Rate by Quarter per Category (line) 720 x 280 ] [ Credit Amount by <cyc_Returns> per Year (bar) 720 ]
y=460 [ Credit-rate heatmap Category x Year (grid) 520 x 286 ] [ Reason tree (block) 460 ] [ Products by credit rate (table) 450 ]
```
Mini KPI tiles at x = 230, 595, 960, 1325 (w 355, h 64), IDs `CN_KPI<n>_{BG,LBL,VAL,DLT}`:
1 CREDIT AMOUNT · CYTD `$(vCreditAmount_CYTD)` (M €), delta vs PYTD %; 2 CREDIT RATE · CYTD `$(vCreditRate_CYTD)`, `$(vCreditRate_YoYpp)` pp (≤0 good);
3 CREDIT NOTES · CYTD `Count($(vSetCYTD) DISTINCT CreditNoteNo)`, vs PY %; 4 QUALITY SHARE · CYTD
`Sum({$<ReturnReasonGroup={'Quality'}>*$(=Mid('$(vSetCYTD)',2,Len('$(vSetCYTD)')-2))} CreditAmount)/$(vCreditAmount_CYTD)`.
The exact form is built in the script; the simple fallback is `Sum($(vSetCYTD) {<ReturnReasonGroup={'Quality'}>}…)`, which needs the Engineer's help.

| ID | Type | Rect | Title | Dimensions | Expressions | Purpose |
|---|---|---|---|---|---|---|
| `CN_CH_RATE` | Line | 230,170,720,280 | Credit Rate by Quarter per Product Category (%) | YearQuarter, ProductCategory | `$(vCreditRate)`; Networking in Bad red with a thick line, the other categories in grey-blue | story 1 trend |
| `CN_CH_REASON` | Bar (grouped) | 960,170,720,280 | `='Credit Amount by '&GetCurrentField(cyc_Returns)&' per Year (€)'` | `cyc_Returns`, Year | `$(vCreditAmount)`; years 2024/25/26 = PY grey shades, 2026 Primary | which reasons grow |
| `CN_CH_GRID` | Grid | 230,460,520,286 | Credit-Rate Heatmap – Category x Year (%) | ProductCategory, Year | `$(vCreditRate)` as bubble size and sequential colour, value labels | quick pattern |
| `CN_CH_BLOCK` | Block | 760,460,460,286 | Credit Amount by Reason Group and Reason (€) | ReturnReasonGroup, ReturnReason | `$(vCreditAmount)` | composition |
| `CN_TB_PROD` | Straight table | 1230,460,450,286 | Products with the Highest Credit Rate (Net Sales ≥ € 100k) | ProductName (calc. dim: `=Aggr(If(Sum(NetSales)>=100000,ProductName),ProductName)`) | Credit Rate (traffic light), Credit Amount (€), Net Sales (€), # Credit notes; sorted by rate desc | action list |

---------------------------------------------------------------------------------------------------------------------
## 4. SH_CUST "Customers & Products" (A): drill-down
Title "Customers & Products", subtitle "Drill down: Region → Country → City → Customer and Category → Group → Product".
Help: "ⓘ Click a bar to drill down one level (the drill-up arrow appears in the caption). Top N customers follows the Top N
input in the left panel. The funnel shows how many customers are active."
Panel section 5 "TOP N CUSTOMERS": `CUST_FLT_IB_TOPN` Input Box on `vTopN` at 14,606,202,40 and `CUST_FLT_LB_SEG` List Box CustomerSegment at 14,652,202,90.

```
y=96  [ Net Revenue by <drl_Geography> CY vs PY (bar) 720 x 320 ] [ Net Sales & GM% by <drl_Product> (combo) 720 ]
y=426 [ Category mix by Segment (radar) 400 x 320 ] [ Top N customers (straight table) 640 ] [ Customer activity (funnel) 390 ]
```
| ID | Type | Rect | Title | Dimensions | Expressions | Purpose |
|---|---|---|---|---|---|---|
| `CUST_CH_GEO` | Bar | 230,96,720,320 | `='Net Revenue by '&GetCurrentField(drl_Geography)&' (€) – CYTD vs PYTD'` | `drl_Geography` (drill) | "CYTD" `$(vNetRevenue_CYTD)` Primary, "PYTD" `$(vNetRevenue_PYTD)` PY grey; sorted by CYTD desc, max 15 bars + others | CEE grows, UK flat |
| `CUST_CH_PROD` | Combo | 960,96,720,320 | `='Net Sales and Gross Margin % by '&GetCurrentField(drl_Product)` | `drl_Product` (drill) | bars Net Sales (€) `$(vNetSales)`; symbol+line on right axis Gross Margin % `$(vGrossMarginPct)` | product profitability |
| `CUST_CH_RADAR` | Radar | 230,426,400,320 | Category Mix by Customer Segment (% of segment sales) | ProductCategory, CustomerSegment | `$(vNetSales)/Sum(TOTAL <CustomerSegment> NetSales)` | segment profile |
| `CUST_TB_TOPN` | Straight table | 640,426,640,320 | `='Top '&vTopN&' Customers by Net Revenue – CYTD'` | CustomerName (calc. dim `=Aggr(If(Rank(Sum($(vSetCYTD) NetSales)-Sum($(vSetCYTD) CreditAmount))<=vTopN,CustomerName),CustomerName)`), CustomerCountry, CustomerSegment | Net Revenue CYTD (€) with **linear gauge** in cell; YoY % (▲▼ colour); Net Margin %; Credit Rate (traffic light); Invoices | key accounts |
| `CUST_CH_FUNNEL` | Funnel | 1290,426,390,320 | Customer Activity Funnel (count) | calc. dim `=ValueList('All customers','Active R12','Active CYTD','Active Sep 2026')` | `Pick(Match(ValueList(...),...), Count(DISTINCT {1} CustomerID), $(vActiveCustomers_R12), $(vActiveCustomers_CYTD), $(vActiveCustomers_CM))` | reach and retention |

---------------------------------------------------------------------------------------------------------------------
## 5. SH_TEAM "Sales Team & Budget" (A): story 3 (one team below budget)
Title "Sales Teams & Budget", subtitle "Budget is per sales rep and month · achievement = Net revenue / Budget".
Help: "ⓘ Which team misses its budget, and since when? The table shows achievement per team with a status gauge. Drill from
team to rep in the ranking chart. The heatmap shows achievement by quarter."
Panel section 5 "SALES TEAM": `TEAM_FLT_LB_TEAM` List Box SalesTeam at 14,606,202,136.
Note: budget rows link only through SalesRep and Date, so selections on customer, product or channel blank the budget. The help box says this.

```
y=96  [ Budget achievement by team (straight table + gauges) 720 x 320 ] [ Actual vs Budget by Month (combo) 720 ]
y=426 [ Achievement by <drl_Sales> (bar) 560 x 320 ] [ Achievement heatmap Team x Quarter (grid) 520 ] [ Speedometer 350 ]
```
| ID | Type | Rect | Title | Dimensions | Expressions | Purpose |
|---|---|---|---|---|---|---|
| `TEAM_TB_TEAMS` | Straight table | 230,96,720,320 | Budget Achievement by Sales Team – CYTD | SalesTeam, SalesManager | Net Revenue CYTD (€); Budget CYTD (€) `$(vBudget_CYTD)`; Ach. % `$(vBudgetAch_CYTD)` with **traffic-light gauge** cell; Δ vs Budget (€) coloured; Trend = **mini-chart** of monthly achievement 2026 (`$(vBudgetAch)` over YearMonth, `SETCY`) | story 3 |
| `TEAM_CH_ACTBUD` | Combo | 960,96,720,320 | Actual vs Budget by Month 2026 (€) | Month | bars Actual `Sum(SETCY NetSales)-Sum(SETCY CreditAmount)`; line Budget `Sum(SETCY BudgetNetSales)` amber; symbol Ach. % right axis | gap over time |
| `TEAM_CH_REPS` | Bar (horizontal) | 230,426,560,320 | `='Budget Achievement by '&GetCurrentField(drl_Sales)&' – CYTD (%)'` | `drl_Sales` (drill) | `$(vBudgetAch_CYTD)`, colour by thresholds; reference line 100 % | who |
| `TEAM_CH_GRID` | Grid | 800,426,520,320 | Achievement Heatmap – Team x Quarter (%) | SalesTeam, YearQuarter | `$(vBudgetAch)` colour Bad/Warn/Good, value label | since when |
| `TEAM_GA_ACH` | Gauge (speedometer) | 1330,426,350,320 | Budget Achievement – Current Selection, CYTD (%) | – | `$(vBudgetAch_CYTD)`, segments as on DASH | follows team selection |

---------------------------------------------------------------------------------------------------------------------
## 6. SH_REPORT "Reports" (R): detail and export
Title "Reports", subtitle "Detail tables for export (XL icon in the caption) and printing · all respect selections".
Help: "ⓘ Choose a report tab. Use the XL icon to export to Excel. The invoice line list appears once fewer than 50,000 lines are selected."
Panel section 5 "DATE RANGE / STATS": `REP_FLT_CAL` Calendar (slider object, calendar style) on Date at 14,606,202,26, and
`REP_FLT_SB` Statistics Box on NetSales (count, sum, average, min, max) at 14,636,202,106.

| ID | Type | Rect | Title | Content |
|---|---|---|---|---|
| `REP_CT_MAIN` | Container | 230,96,1450,650 | Reports | tabs below |
| `REP_PT_PL` | Pivot table | tab 1 | P&L by Region and Year (€) | rows CustomerRegion, CustomerCountry; columns Year; measures Gross Sales `$(vGrossSales)`, Discount `$(vDiscount)`, Net Sales `$(vNetSales)`, Credit Notes `$(vCreditAmount)`, Net Revenue `$(vNetRevenue)`, Gross Margin `$(vGrossMargin)`, Net Margin `$(vNetMargin)`, Net Margin % `$(vNetMarginPct)`; subtotals |
| `REP_PT_PROD` | Pivot table | tab 2 | Net Revenue by Category and Quarter (€) | rows ProductCategory, ProductGroup; columns Year, Quarter; `$(vNetRevenue)`, plus a Budget-free Net Margin % |
| `REP_ST_CUST` | Straight table | tab 3 | Customer Statement | CustomerName, CustomerCountry, CustomerSegment, Channel-free; Invoices, Net Sales, Credit Notes, Net Revenue, Gross Margin %, Credit Rate; totals on top |
| `REP_TB_CN` | Table Box | tab 4 | Credit Note Lines | CreditNoteNo, CreditNoteDate, CN_OrigInvoiceNo, CustomerName, ProductName, ReturnReason, CreditQty, CreditAmount |
| `REP_ST_INV` | Straight table | tab 5 | Invoice Lines (detail) | dims InvoiceNo, InvoiceLineNo, InvoiceDate, CustomerName, ProductName, Channel; Quantity, UnitPrice, Discount, NetSales, GrossMargin; calc condition `Count(InvoiceLineID)<=50000` |

---------------------------------------------------------------------------------------------------------------------
## 7. SH_HELP "About & Data Model"
Title "About this app", subtitle "CL Distribution · fictional pan-European B2B IT distributor · data Jan 2024 – Sep 2026".
```
y=96  [ About (text) 540 x 200 ] [ D card 370 ] [ A card 370 ] [ R card 370 ]   (each card: coloured header, 3 lines, nav button)
y=306 [ Data model diagram (text boxes + line/arrow objects) 830 x 440 ] [ How to use 420 ] [ Demo stories: 4 buttons + Bookmark object 400 ]
```
| ID | Type | Rect | Content |
|---|---|---|---|
| `HELP_TX_ABOUT` | Text | 10,96,540,200 | purpose, data window, volumes (1,000,000 transactions), currency, refresh |
| `HELP_DAR_{D,A,R}_*` | Text + Button | 560 / 940 / 1320, 96, 360, 200 | D-A-R explanation, each with "Open …" button |
| `HELP_DM_*` | Text + Line/Arrow | 10,306,830,440 | Link-table star: Calendar, Customers, Products, SalesReps, Channels → LinkTable → Invoices, CreditNotes (→ ReturnReasons), Budget |
| `HELP_TX_HOWTO` | Text | 850,306,420,440 | selections, ⟳ cyclic groups, drill-down, Top N, help toggle, clear, export |
| `HELP_STORY_{1..4}` | Button | 1280,…,400,44 | "Story n – …" → Recall bookmark `BM_STORYn` + activate the target sheet |
| `HELP_BM` | Bookmark Object | 1280,560,400,186 | document bookmarks |

## 8. Object-type coverage (requirement check)
List Box, Multi Box, Current Selections, Search Object: every Analysis panel. Slider: SALES (Top N). Calendar: REPORT.
Input Box: CUST (Top N). Table Box: REPORT. Statistics Box: REPORT. Bookmark Object: HELP. Buttons: navigation, Clear, Help,
stories. Text objects: everywhere. Line/Arrow: HELP data model. Container: SALES and REPORT.
Bar: DASH, SALES, CUST, CN, TEAM. Line: SALES, CN. Combo: DASH, CUST, TEAM. Pie: DASH. Scatter: SALES. Grid: CN, TEAM.
Gauge speedometer: DASH, TEAM. Gauge LED / traffic light: DASH. Radar: CUST. Mekko: SALES. Funnel: CUST. Block: CN.
Pivot: REPORT. Straight table with mini-charts / traffic lights / gauges: DASH, CN, CUST, TEAM.
Cyclic groups: cyc_Time (SALES), cyc_Dimension (SALES), cyc_Returns (CN). Drill groups: drl_Geography and drl_Product (CUST), drl_Sales (TEAM).
Cyclic expression group: SALES_CH_TREND.
