# Load-script patterns (QlikView 12)

Proven in `examples/sales-demo/script/sales-demo.qvs` (1M rows, 29 s reload, no synthetic keys). Copy from there; this file
is the index of what to reuse and why.

## 1. Script layout (tabs)
`Main` (SET formats, HidePrefix) → `Config` (all tunables as variables) → `Dimensions` → `Calendar` → one tab per fact →
`LinkTable` → `Variables` (UI measures) → `Cleanup` (comments, drop helper vars).
Keep the script as a `.qvs` file in `_build/script/` as the source of truth. Load it with `toolkit/reload.ps1`; never hand-edit it in the GUI.

```qlik
///$tab Main
SET ThousandSep=','; SET DecimalSep='.'; SET MoneyFormat='€ #,##0.00;-€ #,##0.00';
SET DateFormat='DD/MM/YYYY'; SET FirstWeekDay=0; SET MonthNames='Jan;Feb;Mar;Apr;May;Jun;Jul;Aug;Sep;Oct;Nov;Dec';
SET HidePrefix='%';          // %-prefixed technical keys are hidden in the UI
```

## 2. Config variables (volume and dates in one place)
```qlik
SET vCfgInvoiceLines    = 900000;      // reload.ps1 -Set @{vCfgInvoiceLines='45000'} for a fast test reload
LET vCfgStartDateNum    = Num(MakeDate(2024, 1, 1));
LET vCfgEndDateNum      = Num(MakeDate(2026, 9, 30));   // data end date: drives every period flag
```

## 3. Deterministic test data (no Rand())
Two reloads must give identical totals, so QA can reconcile and demos never change.
```qlik
// $(fRnd(<integer>, <stream>)) -> [0,1). Arguments: plain field names or arithmetic, NO commas or brackets.
SET fRnd = Frac(Sin(($1) * 12.9898 + ($2) * 78.233) * 43758.5453);
Lines:
LOAD LineID, Floor($(fRnd(LineID, 3)) * 600) + 1 AS ProductID;     // preceding load: pass the field, not RecNo()
LOAD RecNo() AS LineID AUTOGENERATE $(vCfgInvoiceLines);
```
Build in steps: **day plan** (lines per day = growth × seasonality × weekday × noise) → **line skeleton** → **header**
(customer, rep, channel) → **lines** (product, qty, price, discount, cost). Bake the demo stories into the generators
(a category's credit rate that climbs, a team that misses budget, a channel with high discounts), then verify that each story is visible.
Use `MAPPING LOAD` + `ApplyMap` for every lookup. It is far faster than joins on 1M rows.

## 4. Multiple fact tables: link table (no synthetic keys, no loops)
```
 Calendar(%DateKey) ─┐
 Customers(CustomerID)┤                ┌── Invoices    (%LinkKey, measures…)
 Products(ProductID) ─┼── LinkTable ───┼── CreditNotes (%LinkKey, ReturnReasonID, measures…)
 SalesReps(SalesRepID)┤  (%LinkKey)    └── Budget      (%LinkKey, measures…)
 Channels(ChannelID) ─┘
```
```qlik
AutoNumber(DateNum & '|' & CustomerID & '|' & ProductID & '|' & SalesRepID & '|' & ChannelID, 'Link') AS %LinkKey
// Budget at a coarser grain: leave the missing keys empty in the key string
AutoNumber(MonthStartNum & '|||' & SalesRepID & '|', 'Link') AS %LinkKey
```
* `LinkTable` = DISTINCT key combinations from every fact, CONCATENATEd, with a `LinkSource` field ('Invoice', 'CreditNote', 'Invoice|CreditNote', 'Budget').
  Use `Exists()` to avoid duplicates (see the LinkTable tab).
* After building the link table, **drop every dimension key from the facts**. Facts keep only `%LinkKey` (plus fact-only keys such as `ReturnReasonID`).
* References between facts (credit note → original invoice) use **non-associating** field names (`CN_OrigInvoiceNo`).
* Check after the reload: no `$Syn` tables (`reload.ps1` prints the tables), with row counts as expected.

## 5. Master calendar with period flags
```qlik
Calendar:
LOAD %DateKey, Date(%DateKey) AS Date, Year(%DateKey) AS Year,
     Dual('Q' & Ceil(Month(%DateKey)/3), Ceil(Month(%DateKey)/3))                 AS Quarter,
     Month(%DateKey) AS Month,
     Dual(Year(%DateKey) & '-Q' & Ceil(Month(%DateKey)/3), Year(%DateKey)*10 + Ceil(Month(%DateKey)/3)) AS YearQuarter,
     Date(MonthStart(%DateKey), 'MMM YYYY') AS YearMonth, Week(%DateKey) AS Week, WeekDay(%DateKey) AS Weekday,
     -InYearToDate(%DateKey, $(vCfgEndDateNum), 0)  AS Flag_CYTD,
     -InYearToDate(%DateKey, $(vCfgEndDateNum), -1) AS Flag_PYTD,
     -(%DateKey > AddMonths($(vCfgEndDateNum),-12) and %DateKey <= $(vCfgEndDateNum)) AS Flag_R12,
     -InMonth(%DateKey, $(vCfgEndDateNum), 0) AS Flag_CM, -InMonth(%DateKey, $(vCfgEndDateNum), -1) AS Flag_PM;
LOAD $(vCfgStartDateNum) + RecNo() - 1 AS %DateKey AUTOGENERATE $(vCfgCalEndDateNum) - $(vCfgStartDateNum) + 1;
```
Flags are 1/0 and never null. Use duals for sortable labels. The calendar may run past the data end (e.g. to the budget year end).

## 6. UI measure variables (one template, many periods)
Write each measure once with placeholders, then generate the period variants. Every variable is a complete expression
with **no nested `$()`**, so it can be evaluated on its own and nothing is expanded too early.
```qlik
SET vTmpCalClear = Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=;
FOR EACH vTmpP IN 'CYTD','PYTD','R12','PR12','CM','PM','PYM'
    LET vSet$(vTmpP) = '{<$(vTmpCalClear),Flag_$(vTmpP)={1}>}';
NEXT
SET vTpl_NetSales   = Sum(#S#NetSales);
SET vTpl_CreditRate = (Sum(#S#CreditAmount) / Sum(#S#NetSales));
FOR EACH vTmpM IN 'NetSales','CreditRate'
    LET v$(vTmpM) = Replace('$(vTpl_$(vTmpM))', '#S#', '');                         // respects selections
    FOR EACH vTmpP IN 'CYTD','PYTD','R12'
        LET v$(vTmpM)_$(vTmpP) = Replace('$(vTpl_$(vTmpM))', '#S#', '$(vSet$(vTmpP)) ');
    NEXT
NEXT
FOR EACH vTmpM IN 'NetSales'          // growth for amounts: ratio (0.05 = +5 %)
    LET v$(vTmpM)_YoY = '((' & '$(v$(vTmpM)_CYTD)' & ') / (' & '$(v$(vTmpM)_PYTD)' & ') - 1)';
NEXT
FOR EACH vTmpM IN 'CreditRate'        // growth for ratios: percentage points (1.5 = +1.5 pp)
    LET v$(vTmpM)_YoYpp = '((' & '$(v$(vTmpM)_CYTD)' & ') - (' & '$(v$(vTmpM)_PYTD)' & ')) * 100';
NEXT
```
Budget vs partial-year actuals: `vBudgetToDate = Sum({<%DateKey={"<=$(vCfgEndDateNum)"}>} BudgetNetSales)` and
`vBudgetAch = NetRevenue / vBudgetToDate`. Keep `vBudget` as the full-year figure and label both.
Full-year sets: `LET vSetCY = '{<Year={' & Year($(vCfgEndDateNum)) & '},Quarter=,Month=,…>}';`.
UI variables: `vTopN`, `vShowHelp` (help boxes' show condition), `vUI_*` for button-driven states, `vDataEndDate` for the header stamp.

## 7. Groups (after the reload)
Define them in `spec/groups.json` and create them with `toolkit/create-groups.ps1`. Naming: `drl_*` for drill-down, `cyc_*` for cyclic.
Typical set: `drl_Geography` (Region > Country > City > Customer), `drl_Product` (Category > Group > Product), `drl_Time`,
`cyc_Dimension` (Region/Category/Channel/Team/Segment), `cyc_Time` (Year/Quarter/Month/Week/Weekday).

## 8. Cleanup tab
`COMMENT TABLE/FIELD … WITH '…'` (shown in the table viewer), then `SET fRnd = ;` etc. to remove script-only helper variables.

## 9. Verify every reload
`toolkit/verify.ps1 -Tsv spec/metrics.tsv` with row counts, totals, identities (`NetSales = GrossSales - Discount`),
story checks (e.g. Networking credit rate 2024 vs 2026) and determinism (run the reload twice; the totals must be identical).
