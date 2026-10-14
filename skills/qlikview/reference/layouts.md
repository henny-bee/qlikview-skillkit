# Layout catalogue: pick the form that fits the question

D-A-R is the **default**. When the user describes another form ("show me what matters", "one page for the boss",
"only the problems", "one sheet per sales rep"), use the matching layout below and say which one you chose.
The common rules in `layout-standard.md` (canvas 1690 × 755, header, titles with units, help box, zero-defect gate) apply to all of them.

| Layout | Use when the user says… | Sheets | Template / helpers |
|---|---|---|---|
| **D-A-R** (default) | "dashboard", "analysis app", "use many QlikView objects" | Dashboard → Analysis (2–5) → Reports → About | `templates/build-SH_TEMPLATE.ps1`, `examples/sales-demo/` |
| **Insight page** | "show the important things", "what should I know", "highlights", "storytelling" | 1 (+ optional detail sheet) | `templates/build-SH_INSIGHTS.ps1`, `New-QvInsightCard` |
| **Executive one-pager** | "one page", "for management", "summary for the board" | 1 | `New-QvKpiTile` ×4–6 + 2 charts + 1 compact table |
| **Exception dashboard** | "only the problems", "what is off target", "alerts" | 1–2 | straight table / bar with a set-analysis filter on the exception |
| **Per-entity sheet** | "one page per rep / customer / store", "scorecard" | 1 (template sheet driven by one selection) | list box + dynamic title + KPI tiles + trend |

## Insight page (insight-first workflow)
1. **Analyse before you design.** Use `eval.ps1` (or a temporary straight table) to run the checklist below, and write down 8–12 candidate findings, each with its number.
2. **Rank them** by impact (money, % of total, trend vs target). Keep the top **5–7**.
3. **Show the list to the user** as one sentence per finding, and wait for approval. This is the cheapest point to change direction.
4. **Build** one `New-QvInsightCard` per finding: a headline sentence (dynamic expression, so it updates with selections), a detail line that says
   what the chart shows, a status (good/watch/bad) and a small chart that **proves** the headline (same measure, same period).
5. **Look at the screenshot.** Each headline must fit on one line, the number in the headline must equal what the chart shows, and the order must be by importance.

Grid used by the template: a KPI strip at y 96 (4 × 410 px), then cards 550 × 283 in two rows (y 170 and 463) of three (x 10 / 570 / 1130).
For 4 insights use 2 × 2 cards of 830 × 283. Card heights below 126 px have no room for a chart.

### Checklist: where the important things hide
* **Change:** biggest growth / decline vs last year or last period, per dimension (`FirstSortedValue(Dim, Aggr(CY/PY-1, Dim))`).
* **Concentration:** share of the top 10 / top 20% (Pareto: `Sum(Aggr(If(Rank(Sum(X))<=10, Sum(X)), Dim)) / Sum(X)`). Dependency risk.
* **Outliers:** values far from the average (e.g. margin % or discount % per customer/product). Use a scatter to show them.
* **Targets:** below budget or target, and since when (achievement per month).
* **Trend breaks:** a month or quarter where the direction changed; seasonality (peak/dip months).
* **Mix shift:** the share of a category or channel rising or falling (it can explain a margin change).
* **Data quality:** nulls, unknown keys or duplicates. Say so if they affect a number.

Expression tips: `FirstSortedValue()` returns null when two values tie, so add a tie-breaker (`Aggr(... + Rank(...)/1e9, Dim)`) if needed.
Wrap the headline numbers in `Num(…, '+0.0%;-0.0%')` or `Num(…, '#,##0')`. Keep each headline under ~70 characters.

## Executive one-pager
Header (one nav button or none) → 4–6 KPI tiles (`New-QvKpiTile`, y 96) → a trend chart (left, ~60% width) and a mix chart (right) →
one compact table with traffic lights at the bottom. No filter panel; at most one Year/Month list box in the header area. Everything must be readable in 10 seconds.

## Exception dashboard
Show **only** what is off target, so an empty table is good news:
* Straight table with an exception filter in set analysis, e.g. `Sum({<Customer={"=Sum(Sales)/Sum(Budget)<0.9"}>} Sales)`,
  or the dimension limited with a calculated condition (`If(Aggr(...)<0.9, Dim)` as a calculated dimension with `NoNull`).
* A count tile: "7 customers below 90% of budget". A calculation condition plus a friendly message (`ErrorMessageOverrides`) when there are no exceptions.
* Sort by gap size; colour by severity (red < 80%, amber 80–90%).

## Per-entity sheet (scorecard)
* A list box (or buttons) for the entity, with **"Always one selected value"** set in the list box properties (or tell the user to pick one).
* Title: `='Scorecard – ' & Only(SalesRep)`; with no single selection, show the hint `=If(Count(DISTINCT SalesRep)<>1, 'Select one sales rep', ...)` and hide the charts with a show condition `Count(DISTINCT SalesRep)=1`.
* KPI tiles vs team average (`Avg(Aggr(Sum(Sales), SalesRep))` with `{<SalesRep=>}`), a trend, a top-customers table and a rank (`Rank(TOTAL ...)`).
* Bookmarks per entity or the Reports sheet for printing.
