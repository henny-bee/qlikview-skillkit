# QLIK-CL — QA Test Plan (owner: QA)

Basis: `spec/data-contract.md` (binding), `TEAM-BRIEF.md` quality bar, and `spec/style-guide.md` / `spec/layout-spec.md` (designer) for UI.
I test against the **contract and the requirements**, not against the implementation. Expected values are computed
**independently** from raw fact fields with my own expressions. QA never changes the app. Selection and sheet-activation tests
run under `Enter-QvLock -Owner qa` and always end with `$doc.ClearAll($true)`, restore the active sheet, and release the lock.

## How to run
| Script | Needs lock | Output |
|---|---|---|
| `qa/check-data.ps1` | no (uses `{1}` sets, so selections don't matter) | `qa/results/data-<ts>.md` + `data-latest.md` |
| `qa/check-data.ps1 -Deep` | no | adds the row-level join tests (CN ↔ original invoice, link integrity) using chunked `Concat()` dumps |
| `qa/check-data.ps1 -Snapshot <name>` | no | `qa/results/snapshot-<name>.json` (determinism fingerprint) |
| `qa/check-reload.ps1` | **yes, coordinate first** | timed reload + before/after snapshot compare -> `qa/results/reload-<ts>.md` |
| `qa/check-expressions.ps1` | yes (selection scenarios) | `qa/results/expr-<ts>.md` + `expr-latest.md` |
| `qa/check-ui.ps1 [-Sheet SH_x]` | yes (activates sheets, screenshots) | `qa/results/ui-<ts>.md`, `qa/screens/<SH>_<ts>.png`, object XML in `qa/results/xml/` |

Run from WSL: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w qa/check-data.ps1)"`.
Each result row has: ID, test, expected, actual, PASS/FAIL/WARN. A FAIL becomes an issue in `qa/issues.md`.

Severity guide: **Blocker** = wrong totals, synthetic keys/loops, reload error, wrong row counts. **Major** = a contract rule
is violated (field missing or misplaced, wrong variable value, broken nav, error in expression, demo story not visible).
**Minor** = plausibility off target, cosmetic inconsistency with impact, performance slightly over target. **Cosmetic** = polish.

---
## A. Data model and volumes (`check-data.ps1`)
| ID | Test | Expected |
|---|---|---|
| D-01 | Table list (`$Table`) | exactly Calendar, Customers, Products, SalesReps, Channels, ReturnReasons, Invoices, CreditNotes, Budget, LinkTable. Extra (island) tables = WARN, must be justified |
| D-02 | No synthetic keys | no table or field named `$Syn*` |
| D-03 | No loosely coupled tables (circular refs) | `GetLooselyCoupledVector()` all false |
| D-04 | Row counts (`$Rows`) | Invoices 900,000; CreditNotes 100,000; transactional total 1,000,000; Budget 1,440; Customers 5,000; Products 600; SalesReps 40; Channels 4; ReturnReasons 8; Calendar 1,096; LinkTable = distinct key combinations (≈1M; checked in D-31) |
| D-05 | Unique line IDs | InvoiceLineID: count = distinct = 900,000, min 1, max 900,000. CreditNoteLineID: 100,000, 1..100,000. BudgetID distinct 1,440 |
| D-06 | Every contract field exists, in the contract table | full field list from contract §Fields, using `$Field`/`$Table` |
| D-07 | Key placement | %LinkKey only in LinkTable + 3 facts; %DateKey/CustomerID/ProductID/SalesRepID/ChannelID only in LinkTable + their dimension; ReturnReasonID only in CreditNotes + ReturnReasons; facts contain **no** other dimension key |
| D-08 | No unintended associations | every field that is not a declared key lives in exactly one table |
| D-09 | `%` fields hidden | `GetFieldDescription('%LinkKey').IsHidden`; `SET HidePrefix='%'` in script |
| D-10 | Script header | the original UK SETs are unchanged; MoneyFormat is EUR; `vCfgInvoiceLines=900000`, `vCfgCreditNoteLines=100000`; no `Rand()` in script |
| D-11 | No nulls in fact measures | Count(field) = rows for Quantity, UnitPrice, DiscountPct, GrossSales, Discount, NetSales, CostOfSales, GrossMargin, InvoiceDate, InvoiceNo; same for the CN and Budget fields |

## B. Key integrity (`check-data.ps1`)
| ID | Test | Expected |
|---|---|---|
| D-20 | Each invoice line reaches each dimension | `Count({1<X={"*"}>} InvoiceLineID)` = 900,000 for X ∈ LinkSource, %DateKey, Date, CustomerID, CustomerName, ProductID, ProductName, SalesRepID, SalesRepName, ChannelID, Channel |
| D-21 | Each CN line reaches each dimension | same for CreditNoteLineID = 100,000, plus ReturnReasonID/ReturnReason |
| D-22 | Budget reaches only Rep + Calendar | `{1<SalesRepID={"*"}>}` and `{1<Date={"*"}>}` = 1,440; with CustomerID/ProductID/ChannelID = **0** |
| D-23 | LinkSource coherent | invoice lines reach a link row with `*Invoice*` (900,000), CN lines `*CreditNote*` (100,000), budget `*Budget*` (1,440); LinkSource values ⊆ {Invoice, CreditNote, Budget} and their `|` combinations |
| D-24 | No orphan link rows | every LinkTable key is used by at least one fact row (`-Deep`) |
| D-25 | %LinkKey unique in LinkTable | distinct %LinkKey = LinkTable rows; each key has 1 date/customer/product/rep/channel (`-Deep`) |
| D-26 | Dimension cardinalities and domains | SalesTeam 8 × 5 reps; Channel = {Direct Sales, E-Commerce, Distributor, Retail Partner}; ProductCategory = the 6 names; ProductGroup ≈24 (20–28); Brand ≈8 (6–10); CustomerSegment = the 4 names; CustomerRegion = the 7 names; ReturnReasonGroup = {Logistics, Quality, Commercial}; 8 ReturnReasons incl. a *Quality defect* reason |

## C. Arithmetic invariants (tolerance 0.01 EUR per row) (`check-data.ps1`)
| ID | Test | Expected |
|---|---|---|
| D-30 | GrossSales = Quantity × UnitPrice | 0 violations, max abs diff ≤ 0.01 |
| D-31 | Discount = GrossSales × DiscountPct | 0 violations (DiscountPct as a fraction 0..1; if it is stored as a percentage, WARN) |
| D-32 | NetSales = GrossSales − Discount | 0 violations |
| D-33 | GrossMargin = NetSales − CostOfSales | 0 violations |
| D-34 | Ranges | Quantity integer ≥ 1; UnitPrice > 0; 0 ≤ DiscountPct < 0.6; NetSales > 0; CostOfSales > 0; CreditQty integer ≥ 1; CreditAmount > 0; CreditCost ≥ 0; BudgetNetSales > 0; 0 < BudgetGrossMargin < BudgetNetSales; ProductStdCost < ProductListPrice |
| D-35 | Totals consistency | Sum(GrossSales) − Sum(Discount) = Sum(NetSales); Sum(NetSales) − Sum(CostOfSales) = Sum(GrossMargin) (aggregate level, tolerance 1 EUR) |

## D. Credit-note rules (row-level join through CN_OrigInvoiceLineID, `-Deep`)
| ID | Test | Expected |
|---|---|---|
| D-40 | Reference resolves | every CN_OrigInvoiceLineID is an existing InvoiceLineID; CN_OrigInvoiceNo = InvoiceNo of that line |
| D-41 | Same customer/product/rep/channel | the CN link key's CustomerID/ProductID/SalesRepID/ChannelID = the original invoice line's |
| D-42 | CN date | CreditNoteDate ≥ original InvoiceDate and ≤ 2026-09-30; CN %DateKey = CreditNoteDate |
| D-43 | CreditQty ≤ original Quantity | 0 violations (also the sum over several CN lines for the same invoice line, WARN if it is exceeded) |
| D-44 | CreditAmount ≤ original NetSales | 0 violations (also the cumulative sum per invoice line, WARN) |
| D-45 | 0 ≤ CreditCost ≤ original CostOfSales | 0 violations |
| D-46 | Non-association | CN_OrigInvoiceNo / CN_OrigInvoiceLineID are only in CreditNotes (D-08) |

## E. Dates and calendar
| ID | Test | Expected |
|---|---|---|
| D-50 | Transaction window | InvoiceDate and CreditNoteDate within 2024-01-01..2026-09-30; min/max reported |
| D-51 | Fact date = link date | invoice InvoiceDate = its %DateKey; CN CreditNoteDate = its %DateKey (`-Deep`) |
| D-52 | Calendar range | 1,096 distinct %DateKey, 2024-01-01..2026-12-31, contiguous (max − min + 1 = count) |
| D-53 | Flags exact | count of flag=1 days and min/max: CYTD 273 (2026-01-01..09-30), PYTD 273 (2025-01-01..09-30), R12 365 (2025-10-01..2026-09-30), PR12 365 (2024-10-01..2025-09-30), CM 30 (Sep 2026), PM 31 (Aug 2026), PYM 30 (Sep 2025); values only {0,1}; never null (count = 1,096) |
| D-54 | Calendar attributes | Year {2024,2025,2026}; Quarter {Q1..Q4}; Month dual 1..12; YearQuarter like '2025-Q1'; YearMonth dual, numeric order = date order, 36 values; Week = ISO (2024-12-30 → 1, 2026-12-28 → 53, 2026-01-01 → 1); Weekday dual, 2024-01-01 = Mon (0); Day = day of month |
| D-55 | Budget grain | 1,440 rows = 40 reps × 36 months; every budget %DateKey is the 1st of a month in 2024-01..2026-12; one row per (rep, month) |

## F. Plausibility and demo stories (computed independently)
| ID | Test | Target (FAIL outside the hard band, WARN outside the soft band) |
|---|---|---|
| D-60 | Credit rate = ΣCreditAmount / ΣNetSales | 4–6% |
| D-61 | Gross margin % = ΣGrossMargin / ΣNetSales | 18–28% |
| D-62 | Lines per invoice | ≈ 5 (4–6); InvoiceLineNo is 1..n within each invoice; one date and customer per invoice |
| D-63 | Number formats | InvoiceNo like `INV-YYYY-NNNNNNN` with YYYY = invoice year; CreditNoteNo like `CN-YYYY-NNNNNNN`; PaymentTerms like `Net *` |
| D-64 | YoY growth (NetSales) | 2025 vs 2024 ≈ +8% (6–10%); CYTD vs PYTD ≈ +5% (3–7%) |
| S1 | Networking quality issue | Networking credit rate 2024 ≈ 3% (2–4.5%), 2026 ≈ 9% (7–11%), rising every year; *Quality defect* is the largest Networking return reason in 2026 and its share grows vs 2024; no other category shows the same climb |
| S2 | Seasonality and growth | Q4 is the largest quarter in 2024 and 2025; Aug < Jul and Aug < Sep in every year; CEE has the highest YoY growth of all regions; UK & Ireland YoY within ±2% |
| S3 | Sales team below budget | 2026 CYTD NetRevenue / Budget (Jan–Sep 2026): exactly one team at ≈88% (84–92%), all other teams 98–106% (WARN 96–108%) |
| S4 | E-Commerce discounts | E-Commerce has the highest discount rate, the lowest GM% and the highest YoY growth (2025 vs 2024 and CYTD) of the 4 channels |

## G. Determinism and performance
| ID | Test | Expected |
|---|---|---|
| P-01 | Determinism | snapshot (row counts, Σ of every measure, Σ by year × category, Σ(InvoiceLineID × NetSales) fingerprint) is identical before/after a reload. **Reload only after messaging engineer + team-lead.** |
| P-02 | Reload time | < 90 s (timed in `check-reload.ps1`; the engineer's log is used if available) |
| P-03 | Document size | .qvw on disk (after the lead's save), reported; QlikView process memory reported |
| P-04 | Object calc time | per object `GetObjectCalcTime()` after the sheet is activated; WARN > 1,000 ms, **FAIL > 2,000 ms** (lead); top 10 listed |
| P-05 | Sheet switch | time from `ActivateSheetById` to `WaitForIdle` per sheet; WARN > 3 s |

## H. Expressions and variables (`check-expressions.ps1`)
| ID | Test | Expected |
|---|---|---|
| E-01 | Every contract variable exists | 21 base measures, 7 period sets, 13 × 7 = 91 period measures, 5 `_YoY`, 3 `_YoYpp`, vTopN, vShowHelp, vDataEndDate, vDataEndDateNum, vFmtMoney, vFmtPct, vCfgInvoiceLines, vCfgCreditNoteLines |
| E-02 | Measures are SET-style | the raw definition of a measure variable does **not** start with `=` (otherwise `$(v)` would be a constant per chart row) |
| E-03 | Evaluates without error | `EvaluateEx('$(v)')` has no "Error", is numeric (sets: `Sum($(vSetX) NetSales)` is numeric) |
| E-04 | Value = independent computation | my own formula from raw fields (see the formula table in the script), relative tolerance 1e-6. YoY is a ratio (CYTD/PYTD − 1); YoYpp is a ratio difference (CYTD − PYTD) |
| E-05 | Period sets ignore calendar selections | with Year=2025, Month=Mar, YearMonth, Date-range and Week selections every `_CYTD/_PYTD/…` value is unchanged vs no selections, and still equals the independent formula |
| E-06 | Period sets respect other selections | with CustomerRegion=CEE, ProductCategory=Networking + Channel=E-Commerce, SalesTeam=<team 1> the values equal the independent formula |
| E-07 | Budget exclusion | with a CustomerName or ProductName selected, vBudget/vBudget_* are 0 or null and vBudgetAch* is null or non-numeric (no misleading %); with a SalesTeam selected, budget = that team's budget |
| E-08 | UI and format variables | vTopN = 10, vShowHelp = 1, vDataEndDate = '30/09/2026', vDataEndDateNum = 46295, vFmtMoney = `€ #,##0`, vFmtPct = `0.0%` |
| E-09 | Groups | the 4 drill + 4 cyclic groups exist with the exact fields, order and type |
| E-12 | Per chart dimension | each base/period variable = independent formula for every value of CustomerRegion, Channel, ProductCategory, SalesTeam, Year (Aggr emulation of a chart) |
| E-10 | Bookmarks (when built) | the document bookmarks recall without error; each demo story has a bookmark |

## I. UI (`check-ui.ps1` plus visual review)
| ID | Test | Expected |
|---|---|---|
| U-01 | Sheets | IDs/names exactly per contract, in D-A-R order SH_DASH, SH_SALES, SH_CUST, SH_CN, SH_TEAM, SH_REPORT, SH_HELP; SH01 'Main' reused or removed; no `ZZ_*` sandbox sheets at the end |
| U-02 | Canvas bounds | every visible object inside 0..1690 × 0..755 px (`GetRect`) |
| U-03 | Overlaps | no partial overlap; full containment only if the outer object is a declared background panel (per the style guide) on a lower layer; container children are excluded |
| U-04 | Titles | every chart/table/list/multi/stat/input/slider/container/search/bookmark object has a non-empty caption shown, or a chart title; text objects and buttons have non-empty text |
| U-05 | Fonts | only the style-guide fonts and sizes (caption, body, KPI) |
| U-06 | Colors | caption/background/KPI colors are from the style-guide palette |
| U-07 | Navigation | every sheet has a nav band with buttons/actions that activate every other contract sheet; every target sheet ID exists |
| U-08 | Help boxes | ≥ 1 "What am I looking at?" explanation text object per sheet (style-guide wording); `vShowHelp` toggles them if designed so |
| U-09 | Groups on Analysis sheets | each of SH_SALES, SH_CUST, SH_CN, SH_TEAM uses ≥ 1 group in a chart dimension; across them both drill and cyclic groups are used (each sheet should have both, WARN otherwise) |
| U-10 | Object variety | the document uses ≥ 15 distinct object types from: bar, line, combo, pie, scatter, gauge, radar, grid, pivot, straight, table box, text, button, list box, multi box, statistics box, input box, slider, current selections, search, bookmark, container, line/arrow |
| U-11 | No errors / empty charts | no object text or cell contains "Error"; charts and tables have ≥ 1 data row with no selections; text objects have no unexpanded `$(`; no "-" KPI with no selections |
| U-12 | Number formats | money expressions show `€`, ratios `%`, via the number format or Num(); KPI texts contain a unit |
| U-13 | Calc time | see P-04 |
| U-14 | Visual review | screenshot per sheet (`qa/screens`), read and checked for alignment, truncated labels, readability, legend/axis clutter, consistency between sheets |
| U-16 | Layout-spec conformance | every object listed in `spec/layout-spec.md` exists on its sheet with the specified type and rect (±2 px); extra objects listed |
| U-17 | Field-less charts (lead) | no chart expression and no chart dimension that references no data field after `$(v…)` expansion (hang risk over 1M rows). Checked statically from the XML **before** activating the sheet; a sheet with a field-less expression is not activated unless `-Force` |
| U-15 | Header band | the same header band position, size and color on every sheet; the sheet title matches the sheet name |

## J. Process
* On "DATA READY": run `check-data.ps1 -Deep` and `check-expressions.ps1`, then log issues and message the engineer.
* On "SHEET READY SH_x": `check-ui.ps1 -Sheet SH_x`, look at the screenshot, log issues and message the designer.
* "FIXED <id>": re-run the relevant check, then set the status to Verified (or reopen with new evidence).
* Q3: run the full suite (data, deep, expressions, UI all sheets, reload/determinism after coordination), then write `qa/final-report.md`.
