# Layout standard: D-A-R dashboards (default) and shared rules

Other layouts (insight page, executive one-pager, exception dashboard, per-entity scorecard) are in `layouts.md`.
The canvas, style and zero-defect rules below apply to **every** layout.

The house style that `toolkit/lib-qv.ps1` implements. The full worked example is in `examples/sales-demo/spec/style-guide.md`
and `layout-spec.md`, with screenshots in `examples/sales-demo/screenshots/`.

## D-A-R structure
| Level | Question | Sheets | Content |
|---|---|---|---|
| **D**ashboard | "How are we doing?" (answer in 5 s) | 1 | 4–6 KPI tiles (value + vs PY/budget + context), 1 trend, 1–2 gauges, 1 mix chart, 1 compact table with lights |
| **A**nalysis | "Why?" | 2–5, one per topic/story | Filter panel on the left, 4–6 charts, cyclic/drill groups, Top N, a story tile |
| **R**eports | "Show me the rows" | 1 | Container with pivot/straight/table-box tabs, XL export, calc conditions on line lists |
| Help/About | "How do I use this?" | 1 | What the app is, D-A-R cards, data-model diagram, measure definitions, how-to, story buttons + bookmarks |

## Canvas and grid
* Design for **1690 × 755 px** at 100% zoom (fits a 1720 px wide window with no scrolling). Nothing may extend past x 1690 / y 746.
* Base unit 10 px: outer margin 10, gutter between cards 10.
* **Header band** y 0–48: app name and subtitle (left), nav buttons from x 230, data stamp, *Clear selections*, *Show/Hide help* (right).
* **Title** y 52 (13 pt bold) + **subtitle** y 77 (8.5 pt muted) on the left; the **help box** sits at x 900–1680, y 52–92 (shown when `vShowHelp=1`).
* **Content** from y 96. Analysis/Report sheets: **filter panel** x 10–220 (current selections, period list boxes, a multi box of filters, search, plus a slider/input box section); content from x 230.

## Style
* Flat cards: white objects on a light-grey canvas (`#F2F4F7`), 1 px border `#DCE2EA`, no shadows, gradients or 3D, no rounded corners.
* Palette: navy header `#1B2A41`; primary/current year `#2F6DB5`; prior year `#B4BFCB`; budget `#E39B2D`;
  good `#2E9D6A`, warn `#E39B2D`, bad `#D64545`; help box `#EAF2FB` with text `#34506F`.
* Font: Segoe UI. Captions 9.5 pt bold, body 9 pt, axis 8 pt, KPI value 20+ pt.
* **One fixed colour per category value across all charts** (e.g. channel colours via a colour expression).

## Rules every sheet must pass (the zero-defect gate)
1. Same header/nav at identical coordinates. The active nav button is highlighted. Every nav button opens the right sheet.
2. Every object has a **title that names the measure and unit** (e.g. "Net Revenue by Month (€ M) – 2026 vs 2025 vs Budget").
3. Every KPI shows a comparison (▲/▼ vs PY or vs budget, coloured) and a context line.
4. A "What am I looking at?" help box on every sheet, and labels on the filter-panel sections.
5. No "Error in expression", no "€ 0", no NaN, no `-` in totals, no raw unformatted numbers, no truncated titles or headers,
   no overlapping labels, no empty charts, no horizontal scrollbars, no leftover sandbox or parking sheets.
6. Partial periods are labelled ("2026 = Jan–Sep (YTD)"). Budget denominators are labelled ("budget to date" vs "full-year budget").
7. Status lights must actually vary across rows; otherwise they read as a bug.
8. Every cyclic group cycles through all its members and every drill group drills to its lowest level without errors.
9. Look at a screenshot of every sheet (the scan alone cannot see overlaps or truncation).

## Object coverage checklist (when the brief says "use many QlikView objects")
List box, multi box, current selections, search object, slider, input box, calendar, statistics box, table box, bookmark object,
buttons, text objects, line/arrow, container; bar, line, combo, pie, scatter, grid, gauge (speedometer + traffic light),
radar, Mekko, funnel, pivot, straight table with mini-charts, traffic lights and gauges; cyclic groups, drill groups, cyclic expression group.

## Naming
Sheet IDs `SH_<TAG>`; object IDs `<TAG>_<ROLE>[_n]` (e.g. `SALES_CH_TREND`, `DASH_KPI1_VAL`, `CN_FLT_LB_YEAR`);
groups `cyc_*` / `drl_*`; UI variables `vUI_*`; contract measures `v<Measure>[_<Period>]`.
