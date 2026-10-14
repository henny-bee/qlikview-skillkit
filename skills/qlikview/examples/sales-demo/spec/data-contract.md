# QLIK-CL — Data Contract (v1, owned by Lead)

This is the interface between Engineer, Dashboard Designer and QA. **Field, table, variable and group names below are
binding.** If you need a change, message the Lead (`team-lead`) first. The Lead updates this file and tells everyone.

Business story: **"CL Distribution"**, a fictional pan-European B2B distributor of IT hardware and accessories.
Currency is **EUR**. Keep the existing UK number/date SET statements in the script header and change only `MoneyFormat` to EUR.
The data window is **2024-01-01 to 2026-09-30** (transactions). The calendar runs 2024-01-01 to 2026-12-31 because the budget covers all of 2026.

## Volumes (required)
| Table | Grain | Rows |
|---|---|---|
| `Invoices` (fact) | invoice line | **900,000** exactly |
| `CreditNotes` (fact) | credit note line | **100,000** exactly |
| **Transactional total** | | **1,000,000** |
| `Budget` (fact) | sales rep × month (2024-01 … 2026-12) | 40 × 36 = 1,440 |
| `LinkTable` | distinct key combinations of all facts | ~1M |
| `Customers` | customer | 5,000 |
| `Products` | product | 600 |
| `SalesReps` | sales rep | 40 (8 teams × 5) |
| `Channels` | channel | 4 |
| `ReturnReasons` | reason | 8 |
| `Calendar` | day | 1,096 |

Put the counts in script variables (`vCfgInvoiceLines = 900000`, `vCfgCreditNoteLines = 100000`) so the volume is easy to change.
**Determinism:** generation must be reproducible, so two reloads give identical totals. Use hash-based pseudo-random
numbers, e.g. `Frac(Sin(RecNo()*12.9898 + <seed>)*43758.5453)`, and do not use `Rand()`.

## Data model: link table (multi-fact, no synthetic keys, no loops)
```
 Calendar(%DateKey) ─┐
 Customers(CustomerID)┤                 ┌── Invoices    (%LinkKey, …)
 Products(ProductID) ─┼── LinkTable ────┼── CreditNotes (%LinkKey, …) ── ReturnReasons(ReturnReasonID)
 SalesReps(SalesRepID)┤   (%LinkKey)    └── Budget      (%LinkKey, …)
 Channels(ChannelID) ─┘
```
* `LinkTable`: `%LinkKey, %DateKey, CustomerID, ProductID, SalesRepID, ChannelID, LinkSource`
  `LinkSource` is `'Invoice' | 'CreditNote' | 'Budget'`, and you may concatenate values (e.g. `'Invoice|CreditNote'`) if one key combination is shared.
  Budget rows: `%DateKey` = first day of the month, plus `SalesRepID`. `CustomerID`, `ProductID` and `ChannelID` are null.
* `%LinkKey` = `AutoNumber(%DateKey &'|'& CustomerID &'|'& ProductID &'|'& SalesRepID &'|'& ChannelID, 'Link')`.
* Fact tables must **not** contain any dimension key except `%LinkKey` (and `ReturnReasonID` in CreditNotes).
* Credit notes reference the original invoice through **non-associating** fields (`CN_OrigInvoiceNo`, `CN_OrigInvoiceLineID`).
  They inherit the original line's customer/product/rep/channel. Their `%DateKey` is the **credit note date**.
* `%`-prefixed keys are hidden technical fields (`SET HidePrefix='%';`).

## Fields
**Calendar** — `%DateKey` (num date), `Date`, `Year`, `Quarter` ('Q1'..'Q4'), `Month` (dual, Jan..Dec), `YearQuarter` ('2025-Q1'),
`YearMonth` (dual, 'Jan 2025', sortable), `Week` (ISO week no), `Weekday` (dual Mon..Sun), `Day`,
`Flag_CYTD` (1 = 2026-01-01..2026-09-30), `Flag_PYTD` (1 = 2025-01-01..2025-09-30), `Flag_R12` (1 = 2025-10-01..2026-09-30),
`Flag_PR12` (1 = 2024-10-01..2025-09-30), `Flag_CM` (1 = Sep 2026), `Flag_PM` (1 = Aug 2026), `Flag_PYM` (1 = Sep 2025).
Flags use 1/0 and are never null.

**Customers** — `CustomerID`, `CustomerName`, `CustomerSegment` (Enterprise, Mid-Market, SMB, Public Sector), `CustomerCity`,
`CustomerCountry`, `CustomerRegion` (DACH, Benelux, Nordics, UK & Ireland, France, Southern Europe, CEE), `CustomerSince` (date).

**Products** — `ProductID`, `ProductName`, `ProductGroup` (~24), `ProductCategory` (6: Notebooks & PCs, Monitors & Displays,
Networking, Storage, Peripherals, Software & Services), `Brand` (~8), `ProductListPrice`, `ProductStdCost`.

**SalesReps** — `SalesRepID`, `SalesRepName`, `SalesTeam` (8), `SalesManager`, `SalesRepRegion` (home region).

**Channels** — `ChannelID`, `Channel` (Direct Sales, E-Commerce, Distributor, Retail Partner).

**ReturnReasons** — `ReturnReasonID`, `ReturnReason` (8), `ReturnReasonGroup` (Logistics, Quality, Commercial).

**Invoices** — `%LinkKey`, `InvoiceLineID` (1..900000, unique), `InvoiceNo` ('INV-2025-0001234'), `InvoiceLineNo`, `InvoiceDate`,
`PaymentTerms` ('Net 30' …), `Quantity`, `UnitPrice` (net unit price before line discount), `DiscountPct`, `GrossSales` (= Quantity × UnitPrice),
`Discount`, `NetSales` (= GrossSales − Discount), `CostOfSales`, `GrossMargin` (= NetSales − CostOfSales).

**CreditNotes** — `%LinkKey`, `CreditNoteLineID` (1..100000, unique), `CreditNoteNo` ('CN-2025-0004567'), `CreditNoteLineNo`,
`CreditNoteDate` (≥ original invoice date, ≤ 2026-09-30), `CN_OrigInvoiceNo`, `CN_OrigInvoiceLineID`, `ReturnReasonID`,
`CreditQty` (≤ original Quantity), `CreditAmount` (positive, ≤ original NetSales), `CreditCost` (cost reversal, ≥ 0, ≤ original CostOfSales).

**Budget** — `%LinkKey`, `BudgetID`, `BudgetNetSales`, `BudgetGrossMargin`.

## Built-in demo stories (to be found on the Analysis sheets; the Engineer documents them in spec/data-stories.md)
1. **Networking quality issue:** the credit rate for *Networking* climbs from about 3% (2024) to about 9% (2026), driven by *Quality defect* returns.
2. **Seasonality and growth:** there is a Q4 peak and an August dip. YoY growth is about +8% (2025) and +5% (CYTD 2026). *CEE* grows fastest and *UK & Ireland* is flat.
3. **Sales team below budget:** one sales team misses budget by about 12% in 2026, while the other teams land around 98–106%.
4. **E-Commerce discounts:** *E-Commerce* has the highest discount rate and the lowest margin %, but it grows fastest.
Overall targets: credit rate (CreditAmount / NetSales) about 4–6%, gross margin % about 18–28%, average about 5 lines per invoice.

## Expression variables (defined in the script with SET; Engineer owns them; Designer uses `$(vName)`)
Base measures, which respect selections:
`vNetSales`, `vGrossSales`, `vDiscount`, `vCOGS`, `vGrossMargin`, `vGrossMarginPct`, `vCreditAmount`, `vCreditCost`, `vCreditQty`, `vQuantity`,
`vNetRevenue` (= NetSales − CreditAmount), `vNetMargin` (= GrossMargin − CreditAmount + CreditCost), `vNetMarginPct` (= vNetMargin / vNetRevenue),
`vCreditRate` (= CreditAmount / NetSales), `vDiscountRate` (= Discount / GrossSales), `vInvoices` (distinct InvoiceNo), `vCreditNotes`
(distinct CreditNoteNo), `vActiveCustomers` (customers with ≥ 1 invoice line), `vAvgInvoiceValue`, `vBudget`, `vBudgetAch` (= vNetRevenue / vBudget).

Period sets, which ignore every calendar-field selection and apply the flag:
`vSetCYTD`, `vSetPYTD`, `vSetR12`, `vSetPR12`, `vSetCM`, `vSetPM`, `vSetPYM`, e.g. `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>}`.

Period measures: `v<Measure>_<Period>` for Measure ∈ {NetSales, NetRevenue, CreditAmount, GrossMargin, NetMargin, NetMarginPct,
CreditRate, DiscountRate, Invoices, AvgInvoiceValue, ActiveCustomers, Budget, BudgetAch} and Period ∈ {CYTD, PYTD, R12, PR12, CM, PM, PYM}.
Growth: `v<Measure>_YoY` = CYTD vs PYTD in % for NetSales, NetRevenue, GrossMargin, NetMargin and Invoices. For ratios, `v<Measure>_YoYpp`
gives the difference in percentage points, for NetMarginPct, CreditRate and DiscountRate.

UI variables, which the script defaults: `vTopN = 10`, `vShowHelp = 1`, `vDataEndDate` = '30/09/2026' (also `vDataEndDateNum`).
Formats: `vFmtMoney` = `'€ #,##0'`, `vFmtPct` = `'0.0%'`.

After the first successful reload, the Engineer generates **spec/variables.md** from the document. It lists every variable with its
definition and its value with no selections, and it is the authoritative list for the Designer.

## Groups (document level; the Engineer creates them via COM right after the first reload)
Drill-down groups:
* `drl_Geography`: CustomerRegion → CustomerCountry → CustomerCity → CustomerName
* `drl_Product`: ProductCategory → ProductGroup → ProductName
* `drl_Time`: Year → YearQuarter → YearMonth → Date
* `drl_Sales`: SalesTeam → SalesRepName

Cyclic groups:
* `cyc_Dimension`: CustomerRegion, ProductCategory, Channel, SalesTeam, CustomerSegment, Brand
* `cyc_Time`: Year, YearQuarter, YearMonth, Week, Weekday
* `cyc_Returns`: ReturnReason, ReturnReasonGroup, ProductCategory
* `cyc_Customer`: CustomerName, CustomerCountry, CustomerSegment

The Designer may ask the Lead for more groups. Expression cycling inside charts (cyclic expression groups) is the Designer's choice.

## Sheets (D-A-R), detailed in spec/layout-spec.md (owned by the Designer)
| ID | Name | D-A-R |
|---|---|---|
| `SH_DASH` | Dashboard | **D**ashboard |
| `SH_SALES` | Sales Analysis (nav button "Sales") | **A**nalysis |
| `SH_CUST` | Customers & Products | **A**nalysis |
| `SH_CN` | Credit Notes | **A**nalysis |
| `SH_TEAM` | Team & Budget (page title "Sales Teams & Budget") | **A**nalysis |
| `SH_REPORT` | Reports | **R**eporting |
| `SH_HELP` | About & Data Model | help |
The existing empty sheet `SH01 "Main"` must be reused as SH_DASH (renamed) or removed.
