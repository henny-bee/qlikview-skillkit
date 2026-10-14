# QLIK-CL: Demo Data Stories (generated)

Generated on 2026-10-14 11:53 from the document (last reload 13/10/2026 15:48:38). Every number below was evaluated in the doc
with the stated selections (reproduced with set analysis, see `engineer/stories.tsv`), so QA can re-check each one.
Data window: transactions 01/01/2024–30/09/2026; "CYTD" = 01/01–30/09/2026, "PYTD" = 01/01–30/09/2025.
Money in EUR, NetSales unless stated otherwise.

## Overall KPIs (no selections)
| KPI | Value | Contract target |
|---|---|---|
| Net sales total (01/2024–09/2026) | € 3,372,399,150 | |
| Net sales 2024 / 2025 | € 1,162,482,474 / € 1,260,860,519 | |
| Net sales CYTD / PYTD | € 949,056,157 / € 905,566,225 | |
| Net revenue CYTD (net sales − credits) | € 896,960,070 | |
| Gross margin % | 23.7% | 18–28 % ✔ |
| Credit rate (CreditAmount / NetSales) | 5.1% (by year: 2024=4.6%, 2025=5.1%, 2026=5.5%) | 4–6 % ✔ |
| Discount rate | 5.1% | |
| Lines per invoice | 5.03 (178,931 invoices) | ~5 ✔ |
| Credit notes | 94,750 documents, 100,000 lines | |
| Top 20 % customers' share of net sales | 74.6% | Pareto ✔ |

---
## Story 1: Networking quality issue
**Message:** *Networking used to have the fewest returns. Since late 2024 a quality problem, mostly in wireless access
points and switches, has tripled its credit rate. Almost all of the increase is "Quality defect" credits.*

**Where:** SH_CN (Credit Notes). Credit rate (`$(vCreditRate)`) by `Year` (or `YearQuarter` via `drl_Time`); `cyc_Returns`.

**Selections and expected numbers**
| Step | Selection | Expected |
|---|---|---|
| 1 | `ProductCategory` = Networking, chart by Year | Credit rate **2024 2.8% → 2025 5.5% → 2026 9.0%** |
| 2 | Same, KPI | `vCreditRate_CYTD` 9.0% vs `vCreditRate_PYTD` 5.2% |
| 3 | All other categories (exclude Networking) | 2024 4.9% → 2026 5.1% (flat) |
| 4 | Networking, `ReturnReason` = Quality defect | share of Networking credits: 2024 16% → 2025 57% → 2026 75%; credit rate from quality defects 0.5% → 6.7% |
| 5 | Networking, Year = 2026, drill `ProductGroup` | Wireless Access Points **13.7%**, Switches **9.6%**, Routers & Firewalls **7.2%**, Cables & Transceivers **3.7%** |
| 6 | Year = 2026, all categories | Networking 9.0%, Monitors & Displays 6.3%, Storage 6.0%, Notebooks & PCs 5.9%, Peripherals 4.5%, Software & Services 2.6% (Networking is now the worst) |

Credits on Networking in 2026: € 8,928,467, of which € 6,670,256 are quality defects.
*Mechanism (script):* an extra quality-defect propensity for Networking starts on 01/10/2024 and rises linearly
until 30/09/2026 (access points ×1.8, switches ×1.2, routers ×0.8, cables ×0.2); defective lines are mostly returned in full.

---
## Story 2: Seasonality and growth
**Message:** *A typical IT-distribution year: a strong Q4 (year-end budgets) and an August dip. Growth slows from +8 % to
+5 %. CEE is the growth engine, and UK & Ireland is flat.*

**Where:** SH_SALES (Sales Analysis). Net sales by `YearMonth` (`drl_Time`/`cyc_Time`), YoY KPIs, region chart.

**Seasonal index** (average month 2024–2025 = 1.00): Jan 0.89, Feb 0.89, Mar 1.05, Apr 1.02, May 1.02, Jun 1.01, Jul 0.99, Aug 0.72, Sept 1.04, Oct 1.15, Nov 1.10, Dec 1.11.
* **August dip:** index 0.72 (Aug 2025: € 75,298,919 vs Dec 2025: € 121,181,375).
* **Q4 peak:** Oct–Dec index 1.15/1.10/1.11; Q4 = 28.2% of 2025 net sales.

**Growth**
| Period | Net sales | YoY |
|---|---|---|
| 2025 vs 2024 | € 1,260,860,519 vs € 1,162,482,474 | **+8.5%** |
| CYTD vs PYTD (`vNetSales_YoY`) | € 949,056,157 vs € 905,566,225 | **+4.8%** |

**By region** (`CustomerRegion`, `drl_Geography`)
| Region | YoY 2025 | YoY CYTD |
|---|---|---|
| DACH | +9.0% | +6.4% |
| Benelux | +4.2% | +1.0% |
| Nordics | +6.5% | +11.0% |
| **UK & Ireland** | +0.5% | -1.9% |
| France | +6.8% | +0.4% |
| Southern Europe | +7.8% | +3.6% |
| **CEE** | +28.4% | +14.3% |

CEE is the fastest-growing region in both periods, and UK & Ireland is flat (≈ 0 %).
*Mechanism:* year volume levels, monthly seasonality and weekday profile in the day plan; region shares drift
(CEE +12 %/yr, UK & Ireland −6.5 %/yr relative weight).

---
## Story 3: Sales team below budget
**Message:** *All teams are on plan except **UK & Ireland**, which reaches only 88.0% of its 2026
budget (−€ 16,131,874 YTD). The miss is team-wide (every rep is below 92 %), because UK revenue stayed flat while the
plan assumed growth. The gap widens: 2024 99.2% → 2025 95.2% → 2026 88.0%.*

**Where:** SH_TEAM (Sales Team & Budget). `$(vBudgetAch_CYTD)` by `SalesTeam` (`drl_Sales`), actual vs budget.
Budget achievement = NetRevenue / BudgetNetSales.

| Sales team | 2024 | 2025 | CYTD 2026 |
|---|---|---|---|
| DACH North | 102.9% | 100.8% | 101.8% |
| DACH South | 98.0% | 102.1% | 99.0% |
| Benelux | 101.0% | 99.0% | 103.8% |
| Nordics | 97.0% | 102.8% | 100.9% |
| **UK & Ireland** | 99.2% | 95.2% | **88.0%** |
| France | 102.1% | 98.1% | 100.1% |
| Southern Europe | 99.9% | 104.0% | 103.0% |
| CEE | 104.2% | 106.0% | 105.0% |
| **Total** | | | 99.9% |

* Other teams CYTD: 99.0% (DACH South) … 105.0% (CEE).
* `SalesTeam` = UK & Ireland, CYTD: net revenue € 118,304,826 vs budget € 134,436,700 → gap € 16,131,874.
  PYTD net revenue was € 120,796,286 (flat to down). Full-year 2026 budget: € 186,557,200.
* Drill to `SalesRepName` (UK & Ireland, CYTD): Amelia Clarke 85.2%, Oliver Bennett 85.8%, Harry Patel 88.7%, Liam Connolly 90.2%, Charlotte Hughes 91.0%.
* Company total CYTD budget: € 898,065,000.

*Mechanism:* the budget is derived from the actual run rate and divided by a target achievement per team and year
(UK & Ireland 2026 = 0.88; other teams 0.99–1.05), normalised per team.

---
## Story 4: E-Commerce discounts
**Message:** *E-Commerce is the fastest-growing channel, but it buys its growth with discounts: it has the highest
discount rate and the lowest gross margin %.*

**Where:** SH_SALES / SH_CUST, by `Channel` (`cyc_Dimension`).

| Channel | Discount rate | Gross margin % | YoY 2025 | YoY CYTD | Share of net sales 2024 → CYTD 2026 | Credit rate |
|---|---|---|---|---|---|---|
| Direct Sales | 3.3% | 25.5% | +7.4% | +6.7% | 43.3% → 43.6% | 4.7% |
| Distributor | 5.2% | 22.4% | +10.2% | +1.1% | 38.2% → 37.5% | 4.7% |
| Retail Partner | 4.2% | 25.7% | +2.5% | +3.2% | 11.3% → 10.5% | 5.1% |
| **E-Commerce** | 14.8% | 17.9% | +14.9% | +15.6% | 7.2% → 8.4% | 8.8% |

*Mechanism:* E-Commerce gets a growing channel weight (+11 %/yr) plus weekend orders, list price (no contract price
list), discounts of 8–25 % on 90 % of its lines, small quantities, and more cancellations and transport damage.

---
## Bookmarks
One document bookmark per story (`engineer/create-bookmarks.ps1`). Each one holds the selections and was created on
the story's sheet with layout state, so recalling it also opens that sheet. The story buttons on SH_HELP run
*Clear all → apply bookmark → open sheet*.

| ID | Name | Selections | Sheet |
|---|---|---|---|
| `BM_STORY1` | Story 1 – Networking quality issue | ProductCategory = Networking | SH_CN |
| `BM_STORY2` | Story 2 – Seasonality and growth | CustomerRegion = CEE, UK & Ireland | SH_SALES |
| `BM_STORY3` | Story 3 – UK & Ireland below budget | SalesTeam = UK & Ireland, Year = 2026 | SH_TEAM |
| `BM_STORY4` | Story 4 – E-Commerce discounts | Channel = E-Commerce | SH_SALES |
