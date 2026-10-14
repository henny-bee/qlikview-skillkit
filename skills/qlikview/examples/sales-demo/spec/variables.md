# QLIK-CL: Variables (generated)

> **Authoritative list for the Designer.** Generated from the document by `engineer/dump-doc.ps1` +
> `engineer/gen-specs.py` on 2026-10-14 11:53 (last reload 13/10/2026 15:48:38). Values were evaluated with **no selections**.
> Do not edit by hand: change the script (`_build/script/QLIK-CL.qvs`, tab *Variables*) and regenerate.

**How to use:** `=$(vNetSales_CYTD)` in a text object, or `$(vNetSales)` as a chart expression. Every variable
holds a **complete, self-contained expression** (no nested `$()` inside), so it works in any context and
nothing is expanded too early. Composite measures are wrapped in brackets, so `1 - $(vCreditRate)` and
`x / $(vNetRevenue)` are safe. Format with `Num(…, '$(vFmtMoney)')` or `Num(…, '$(vFmtPct)')`.

* 137 contract variables, plus 9 script configuration variables (`vCfg*`).
* Period sets ignore **all calendar selections** (Year, Quarter, Month, YearQuarter, YearMonth, Week, Weekday,
  Day, Date) and then apply one calendar flag. **All other selections** (region, product, team, etc.) are respected.
* `v<Measure>_YoY` = CYTD / PYTD − 1 as a ratio (`0.048` = **+4.8 %**, format `'+0.0%;-0.0%'`).
* `v<Measure>_YoYpp` = (CYTD − PYTD) × 100, i.e. already in **percentage points** (`0.35` = **+0.35 pp**,
  format `'+0.0 pp;-0.0 pp'`).
* Money values are in EUR. `vBudget*` exist only for SalesRep × month: when a Customer, Product or Channel is
  selected the budget is null, and `vBudgetAch` shows `-`. This is by design (budget grain).
* **Budget achievement uses budget months up to the data end date** (round-2 fix): the budget covers all of 2026,
  but actuals stop on 30/09/2026, so `vBudgetAch` divides by `Sum({<%DateKey={"<=46295"}>} BudgetNetSales)`.
  Year = 2026 now gives 99.9 % (it was 72 %) and 2026-Q4 gives `-` (it was 0 %).
* **`vBudget` = full budget for the selection** (label it "full-year budget"); **`vBudgetToDate`** = budget months up to
  30/09/2026 (label it "budget to date"). `vBudgetAch` = `vNetRevenue / vBudgetToDate` (QA Q-001, lead decision 14/10).
* `vSetCY` / `vSetPY`: full calendar year 2026 / 2025 with all other calendar selections cleared (layout-spec SETCY / SETPY).
* `vActiveCustomers` = distinct customers with ≥ 1 invoice line in the selection (`LinkSource` contains *Invoice*).

## Period measures: values at a glance (no selections)
Periods: **CYTD** = 01/01/2026–30/09/2026, **PYTD** = 01/01/2025–30/09/2025, **R12** = 01/10/2025–30/09/2026, **PR12** = 01/10/2024–30/09/2025, **CM** = Sep 2026, **PM** = Aug 2026, **PYM** = Sep 2025.

| Measure | CYTD | PYTD | R12 | PR12 | CM | PM | PYM |
|---|---|---|---|---|---|---|---|
| `vNetSales_<P>` | € 949,056,157 | € 905,566,225 | € 1,304,350,452 | € 1,228,263,157 | € 118,862,391 | € 77,636,057 | € 114,328,905 |
| `vNetRevenue_<P>` | € 896,960,070 | € 859,307,914 | € 1,234,070,384 | € 1,166,256,330 | € 113,301,227 | € 72,441,565 | € 108,869,766 |
| `vCreditAmount_<P>` | € 52,096,087 | € 46,258,311 | € 70,280,068 | € 62,006,827 | € 5,561,164 | € 5,194,492 | € 5,459,139 |
| `vGrossMargin_<P>` | € 224,515,007 | € 215,095,575 | € 308,783,312 | € 291,500,007 | € 27,861,129 | € 18,359,139 | € 26,952,961 |
| `vNetMargin_<P>` | € 211,229,453 | € 203,462,983 | € 290,928,192 | € 275,828,084 | € 26,487,604 | € 16,981,666 | € 25,591,607 |
| `vNetMarginPct_<P>` | 23.5% | 23.7% | 23.6% | 23.7% | 23.4% | 23.4% | 23.5% |
| `vCreditRate_<P>` | 5.5% | 5.1% | 5.4% | 5.0% | 4.7% | 6.7% | 4.8% |
| `vDiscountRate_<P>` | 5.2% | 5.1% | 5.1% | 5.1% | 5.2% | 5.2% | 5.1% |
| `vInvoices_<P>` | 50,813 | 47,558 | 69,461 | 64,962 | 6,317 | 4,186 | 6,102 |
| `vAvgInvoiceValue_<P>` | € 18,677 | € 19,041 | € 18,778 | € 18,907 | € 18,816 | € 18,547 | € 18,736 |
| `vActiveCustomers_<P>` | 4,982 | 4,979 | 4,998 | 4,997 | 3,053 | 2,340 | 2,975 |
| `vBudget_<P>` | € 898,065,000 | € 855,098,300 | € 1,229,557,600 | € 1,163,311,900 | € 108,456,600 | € 74,223,800 | € 103,326,900 |
| `vBudgetAch_<P>` | 99.9% | 100.5% | 100.4% | 100.3% | 104.5% | 97.6% | 105.4% |

## Growth (CYTD vs PYTD)
| Variable | Definition | Value |
|---|---|---|
| `vNetSales_YoY` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales)) - 1)` | +4.8% |
| `vNetRevenue_YoY` | `(((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount))) / ((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount))) - 1)` | +4.4% |
| `vGrossMargin_YoY` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossMargin)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossMargin)) - 1)` | +4.4% |
| `vNetMargin_YoY` | `(((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditCost))) / ((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditCost))) - 1)` | +3.8% |
| `vInvoices_YoY` | `((Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} DISTINCT InvoiceNo)) / (Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} DISTINCT InvoiceNo)) - 1)` | +6.8% |
| `vNetMarginPct_YoYpp` | `((((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount)))) - (((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount))))) * 100` | -0.13 pp |
| `vCreditRate_YoYpp` | `(((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales))) - ((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales)))) * 100` | +0.38 pp |
| `vDiscountRate_YoYpp` | `(((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossSales))) - ((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossSales)))) * 100` | +0.06 pp |

## Base measures (respect all selections)
| Variable | Definition | Value |
|---|---|---|
| `vNetSales` | `Sum(NetSales)` | € 3,372,399,150 |
| `vGrossSales` | `Sum(GrossSales)` | € 3,553,647,661 |
| `vDiscount` | `Sum(Discount)` | € 181,248,511 |
| `vCOGS` | `Sum(CostOfSales)` | € 2,571,672,250 |
| `vGrossMargin` | `Sum(GrossMargin)` | € 800,726,900 |
| `vGrossMarginPct` | `(Sum(GrossMargin) / Sum(NetSales))` | 23.7% |
| `vCreditAmount` | `Sum(CreditAmount)` | € 170,503,582 |
| `vCreditCost` | `Sum(CreditCost)` | € 127,300,662 |
| `vCreditQty` | `Sum(CreditQty)` | 427,633 |
| `vQuantity` | `Sum(Quantity)` | 11,098,239 |
| `vNetRevenue` | `(Sum(NetSales) - Sum(CreditAmount))` | € 3,201,895,568 |
| `vNetMargin` | `(Sum(GrossMargin) - Sum(CreditAmount) + Sum(CreditCost))` | € 757,523,981 |
| `vNetMarginPct` | `((Sum(GrossMargin) - Sum(CreditAmount) + Sum(CreditCost)) / (Sum(NetSales) - Sum(CreditAmount)))` | 23.7% |
| `vCreditRate` | `(Sum(CreditAmount) / Sum(NetSales))` | 5.1% |
| `vDiscountRate` | `(Sum(Discount) / Sum(GrossSales))` | 5.1% |
| `vInvoices` | `Count(DISTINCT InvoiceNo)` | 178,931 |
| `vCreditNotes` | `Count(DISTINCT CreditNoteNo)` | 94,750 |
| `vActiveCustomers` | `Count({<LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 5,000 |
| `vAvgInvoiceValue` | `(Sum(NetSales) / Count(DISTINCT InvoiceNo))` | € 18,847 |
| `vBudget` | `Sum(BudgetNetSales)` | € 3,535,124,800 |
| `vBudgetAch` | `((Sum(NetSales) - Sum(CreditAmount)) / Sum({<%DateKey={"<=46295"}>} BudgetNetSales))` | 100.5% |
| `vBudgetToDate` | `Sum({<%DateKey={"<=46295"}>} BudgetNetSales)` | € 3,187,078,700 |

## Period set expressions
| Variable | Definition |
|---|---|
| `vSetCYTD` | `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>}` |
| `vSetPYTD` | `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>}` |
| `vSetR12` | `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>}` |
| `vSetPR12` | `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>}` |
| `vSetCM` | `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>}` |
| `vSetPM` | `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>}` |
| `vSetPYM` | `{<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>}` |
| `vSetCY` | `{<Year={2026},Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=>}` |
| `vSetPY` | `{<Year={2025},Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=>}` |

## UI defaults and formats (reset by every reload)
| Variable | Value |
|---|---|
| `vTopN` | `10` |
| `vShowHelp` | `1` |
| `vDataEndDate` | `30/09/2026` |
| `vDataEndDateNum` | `46295` |
| `vFmtMoney` | `€ #,##0` |
| `vFmtPct` | `0.0%` |
| `vUI_TrendMeasure` | `1` |

`vUI_TrendMeasure` (owner: Designer) = 1..6, default 1: the measure of `SALES_CH_TREND` (1 Net Sales, 2 Net Revenue,
3 Gross Margin, 4 GM %, 5 Discount Rate, 6 Invoices), set by the buttons `SALES_TRD_M1..M6`. `vTopN` (3–25) is set by the
Top N slider / input box, `vShowHelp` (0/1) by the header help toggle.

## Period measures: full definitions
| Variable | Definition | Value |
|---|---|---|
| `vNetSales_CYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales)` | € 949,056,157 |
| `vNetSales_PYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales)` | € 905,566,225 |
| `vNetSales_R12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} NetSales)` | € 1,304,350,452 |
| `vNetSales_PR12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} NetSales)` | € 1,228,263,157 |
| `vNetSales_CM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} NetSales)` | € 118,862,391 |
| `vNetSales_PM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} NetSales)` | € 77,636,057 |
| `vNetSales_PYM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} NetSales)` | € 114,328,905 |
| `vNetRevenue_CYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount))` | € 896,960,070 |
| `vNetRevenue_PYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount))` | € 859,307,914 |
| `vNetRevenue_R12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditAmount))` | € 1,234,070,384 |
| `vNetRevenue_PR12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditAmount))` | € 1,166,256,330 |
| `vNetRevenue_CM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditAmount))` | € 113,301,227 |
| `vNetRevenue_PM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditAmount))` | € 72,441,565 |
| `vNetRevenue_PYM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditAmount))` | € 108,869,766 |
| `vCreditAmount_CYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount)` | € 52,096,087 |
| `vCreditAmount_PYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount)` | € 46,258,311 |
| `vCreditAmount_R12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditAmount)` | € 70,280,068 |
| `vCreditAmount_PR12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditAmount)` | € 62,006,827 |
| `vCreditAmount_CM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditAmount)` | € 5,561,164 |
| `vCreditAmount_PM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditAmount)` | € 5,194,492 |
| `vCreditAmount_PYM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditAmount)` | € 5,459,139 |
| `vGrossMargin_CYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossMargin)` | € 224,515,007 |
| `vGrossMargin_PYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossMargin)` | € 215,095,575 |
| `vGrossMargin_R12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} GrossMargin)` | € 308,783,312 |
| `vGrossMargin_PR12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} GrossMargin)` | € 291,500,007 |
| `vGrossMargin_CM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} GrossMargin)` | € 27,861,129 |
| `vGrossMargin_PM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} GrossMargin)` | € 18,359,139 |
| `vGrossMargin_PYM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} GrossMargin)` | € 26,952,961 |
| `vNetMargin_CYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditCost))` | € 211,229,453 |
| `vNetMargin_PYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditCost))` | € 203,462,983 |
| `vNetMargin_R12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditCost))` | € 290,928,192 |
| `vNetMargin_PR12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditCost))` | € 275,828,084 |
| `vNetMargin_CM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditCost))` | € 26,487,604 |
| `vNetMargin_PM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditCost))` | € 16,981,666 |
| `vNetMargin_PYM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditCost))` | € 25,591,607 |
| `vNetMarginPct_CYTD` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount)))` | 23.5% |
| `vNetMarginPct_PYTD` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount)))` | 23.7% |
| `vNetMarginPct_R12` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditAmount)))` | 23.6% |
| `vNetMarginPct_PR12` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditAmount)))` | 23.7% |
| `vNetMarginPct_CM` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditAmount)))` | 23.4% |
| `vNetMarginPct_PM` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditAmount)))` | 23.4% |
| `vNetMarginPct_PYM` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} GrossMargin) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditAmount) + Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditCost)) / (Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditAmount)))` | 23.5% |
| `vCreditRate_CYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales))` | 5.5% |
| `vCreditRate_PYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales))` | 5.1% |
| `vCreditRate_R12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} NetSales))` | 5.4% |
| `vCreditRate_PR12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} NetSales))` | 5.0% |
| `vCreditRate_CM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} NetSales))` | 4.7% |
| `vCreditRate_PM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} NetSales))` | 6.7% |
| `vCreditRate_PYM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditAmount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} NetSales))` | 4.8% |
| `vDiscountRate_CYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} GrossSales))` | 5.2% |
| `vDiscountRate_PYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} GrossSales))` | 5.1% |
| `vDiscountRate_R12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} GrossSales))` | 5.1% |
| `vDiscountRate_PR12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} GrossSales))` | 5.1% |
| `vDiscountRate_CM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} GrossSales))` | 5.2% |
| `vDiscountRate_PM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} GrossSales))` | 5.2% |
| `vDiscountRate_PYM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} Discount) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} GrossSales))` | 5.1% |
| `vInvoices_CYTD` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} DISTINCT InvoiceNo)` | 50,813 |
| `vInvoices_PYTD` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} DISTINCT InvoiceNo)` | 47,558 |
| `vInvoices_R12` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} DISTINCT InvoiceNo)` | 69,461 |
| `vInvoices_PR12` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} DISTINCT InvoiceNo)` | 64,962 |
| `vInvoices_CM` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} DISTINCT InvoiceNo)` | 6,317 |
| `vInvoices_PM` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} DISTINCT InvoiceNo)` | 4,186 |
| `vInvoices_PYM` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} DISTINCT InvoiceNo)` | 6,102 |
| `vAvgInvoiceValue_CYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales) / Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} DISTINCT InvoiceNo))` | € 18,677 |
| `vAvgInvoiceValue_PYTD` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales) / Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} DISTINCT InvoiceNo))` | € 19,041 |
| `vAvgInvoiceValue_R12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} NetSales) / Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} DISTINCT InvoiceNo))` | € 18,778 |
| `vAvgInvoiceValue_PR12` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} NetSales) / Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} DISTINCT InvoiceNo))` | € 18,907 |
| `vAvgInvoiceValue_CM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} NetSales) / Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} DISTINCT InvoiceNo))` | € 18,816 |
| `vAvgInvoiceValue_PM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} NetSales) / Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} DISTINCT InvoiceNo))` | € 18,547 |
| `vAvgInvoiceValue_PYM` | `(Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} NetSales) / Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} DISTINCT InvoiceNo))` | € 18,736 |
| `vActiveCustomers_CYTD` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1},LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 4,982 |
| `vActiveCustomers_PYTD` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1},LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 4,979 |
| `vActiveCustomers_R12` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1},LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 4,998 |
| `vActiveCustomers_PR12` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1},LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 4,997 |
| `vActiveCustomers_CM` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1},LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 3,053 |
| `vActiveCustomers_PM` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1},LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 2,340 |
| `vActiveCustomers_PYM` | `Count({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1},LinkSource={"*Invoice*"}>} DISTINCT CustomerID)` | 2,975 |
| `vBudget_CYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} BudgetNetSales)` | € 898,065,000 |
| `vBudget_PYTD` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} BudgetNetSales)` | € 855,098,300 |
| `vBudget_R12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} BudgetNetSales)` | € 1,229,557,600 |
| `vBudget_PR12` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} BudgetNetSales)` | € 1,163,311,900 |
| `vBudget_CM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} BudgetNetSales)` | € 108,456,600 |
| `vBudget_PM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} BudgetNetSales)` | € 74,223,800 |
| `vBudget_PYM` | `Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} BudgetNetSales)` | € 103,326,900 |
| `vBudgetAch_CYTD` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} CreditAmount)) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD={1}>} BudgetNetSales))` | 99.9% |
| `vBudgetAch_PYTD` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} CreditAmount)) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYTD={1}>} BudgetNetSales))` | 100.5% |
| `vBudgetAch_R12` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} CreditAmount)) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_R12={1}>} BudgetNetSales))` | 100.4% |
| `vBudgetAch_PR12` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} CreditAmount)) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PR12={1}>} BudgetNetSales))` | 100.3% |
| `vBudgetAch_CM` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} CreditAmount)) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CM={1}>} BudgetNetSales))` | 104.5% |
| `vBudgetAch_PM` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} CreditAmount)) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PM={1}>} BudgetNetSales))` | 97.6% |
| `vBudgetAch_PYM` | `((Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} NetSales) - Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} CreditAmount)) / Sum({<Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_PYM={1}>} BudgetNetSales))` | 105.4% |

## Script configuration (`vCfg*`, used by the load script)
| Variable | Value |
|---|---|
| `vCfgInvoiceLines` | `900000` |
| `vCfgCreditNoteLines` | `100000` |
| `vCfgSalesReps` | `40` |
| `vCfgStartDateNum` | `45292` |
| `vCfgEndDateNum` | `46295` |
| `vCfgCalEndDateNum` | `46387` |
| `vCfgNewInvoiceProb` | `0.18` |
| `vCfgMaxLinesPerInvoice` | `12` |
| `vCfgIssueStartNum` | `45566` |
