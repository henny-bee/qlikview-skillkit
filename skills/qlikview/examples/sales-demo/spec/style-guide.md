# QLIK-CL Style Guide (v1, owned by Designer)

The binding visual rules for every sheet of QLIK-CL.qvw. The builder library `designer/lib-qv.ps1` implements these tokens
(`$QS.C.*`, `$QS.Cat`, `$QS.Font`). If you change a token, change it in both places.

## 1. Principles
* **D-A-R**: the Dashboard answers *"how are we doing?"* in 5 seconds. Analysis sheets answer *"why?"* through slicing.
  Reports answer *"show me the rows"* with exportable detail.
* **Calm and flat**: white cards on a light-grey canvas, no 3D, no gradients, no shadows, no rounded corners, and colour only where it means something.
* **The same place for the same thing**: header band, navigation, page title and help box sit at identical coordinates on every sheet.
  Every Analysis sheet has the same left filter panel.
* **Everything fits** the 1690 x 755 px canvas at 100% zoom with no scrolling and no overlaps (deliberate background panels excepted).
* **Context for every number**: a KPI always shows its comparison (vs PY, vs budget, or a trend). Every title states its unit.

## 2. Canvas, grid and zones
* Canvas **1690 x 755 px**. Base unit **10 px**. Outer margin 10 px, gutter between cards 10 px.
* QlikView runs in **Simplified styling mode** (`OCS_SIMPLIFIED_AIR`), which does not draw object borders. Cards are
  separated by **fill contrast** (white card on `Canvas`), not by borders. Do not rely on `BorderWidth`.

| Zone | Rect (L, T, W, H) | Content |
|---|---|---|
| Header band | 0, 0, 1690, 48 | navy band: app title, navigation, data stamp, Clear, Help |
| Page title row | 10, 54, 1670, 36 | sheet title (13 pt) + subtitle (8.5 pt) on the left, sheet help box on the right |
| Content (Dashboard, Report, Help) | 10, 96, 1670, 650 | cards on the 10 px grid |
| Filter panel (Analysis sheets) | 10, 96, 210, 650 | grey panel with filters |
| Content (Analysis sheets) | 230, 96, 1450, 650 | cards on the 10 px grid |

The bottom edge of the content is **y = 746**, which leaves 9 px of safety margin above the 755 px limit.

## 3. Palette
| Token | Hex | Use |
|---|---|---|
| `Navy` | `#1B2A41` | header band, active sheet tab |
| `Navy2` | `#2A3D5A` | inactive navigation button |
| `NavText` | `#C9D4E3` | text on navy (inactive nav, data stamp) |
| `Primary` | `#2F6DB5` | current year / main series / active navigation / primary buttons |
| `PrimaryLt` | `#8DB6E2` | second series of the same measure |
| `PY` | `#B4BFCB` | prior year / comparison series (always grey, so the current year is the hero) |
| `Budget` | `#E39B2D` | budget / target lines and markers |
| `Good` | `#2E9D6A` | favourable delta, on/above target |
| `Bad` | `#D64545` | unfavourable delta, below target |
| `Warn` | `#E39B2D` | near target (amber zone) |
| `Canvas` | `#F2F4F7` | sheet background |
| `Card` | `#FFFFFF` | object background |
| `Border` | `#DCE2EA` | dividers, thin lines (line objects) |
| `Grid` | `#E9EDF2` | chart grid lines |
| `Text` | `#1F2933` | primary text, values |
| `Muted` | `#6B7785` | labels, secondary text, axis text |
| `Panel` | `#E6EBF1` | filter panel background |
| `PanelHead` | `#D5DDE7` | filter panel section headers |
| `InfoBg` / `InfoText` | `#EAF2FB` / `#34506F` | help ("What am I looking at?") boxes |

**Categorical series** (in this order): `#2F6DB5` `#5AA3D8` `#2E9D6A` `#E39B2D` `#8C6BB1` `#D64545` `#4DB6AC` `#9AA5B1`.
Charts that colour by a dimension use this list as their colour map (set per chart by the lib).
**Sequential** (heat, grid and block intensity): `ColorMix1(x, RGB(234,242,251), RGB(47,109,181))`.

**Semantic colour rules.** Status is always shown with colour **and** a glyph or text (`▲`/`▼`, `●`), never colour alone.

| Measure | Good | Warn | Bad |
|---|---|---|---|
| YoY growth (Net Sales, Net Revenue, Margin, Invoices) | ≥ 0 % | – | < 0 % |
| Budget achievement (`vBudgetAch`) | ≥ 100 % | 95 % to < 100 % | < 95 % |
| Credit rate (`vCreditRate`; lower is better) | ≤ 5.0 % | 5.0 % to 7.0 % | > 7.0 % |
| Gross / net margin % | ≥ 22 % | 18 % to < 22 % | < 18 % |
| Delta in pp for ratios where higher is worse (credit rate, discount rate) | ≤ 0 pp | – | > 0 pp |

## 4. Typography
Font family: **Segoe UI** everywhere (`Segoe UI Semibold` is allowed for captions). No Tahoma or Arial left from the defaults.

| Element | Size | Weight | Colour |
|---|---|---|---|
| App title in the header | 14 pt | bold | White |
| App subtitle in the header | 8 pt | regular | NavText |
| Navigation button | 9 pt | bold when active | White / NavText |
| Page title | 13 pt | bold | Text |
| Page subtitle | 8.5 pt | regular | Muted |
| Object caption | 9.5 pt | bold | Text on white |
| KPI label | 8.5 pt | bold, UPPERCASE | Muted |
| KPI value | 20 pt | bold | Text |
| KPI delta line | 8.5 pt | regular | Good/Bad (calculated) |
| Chart axis, legend, data labels | 8 pt | regular | Muted (axis), Text (labels) |
| Table body | 8.5 pt | regular | Text; totals bold |
| Help box | 8 pt | regular | InfoText on InfoBg |
| Filter panel section header | 8 pt | bold, UPPERCASE | Muted on PanelHead |

## 5. Components (patterns)
**Header band** (every sheet, IDs `<TAG>_HDR_*`): navy text object `0,0,1690,48`. "CL Distribution" (14 pt bold white)
plus "SALES COCKPIT · D-A-R" (8 pt NavText) at the left. On the right: the data stamp `='Data through ' & vDataEndDate & ' · EUR'`,
a **Clear** button (action *Clear All*) and a **Help** toggle (action *Set Variable* `vShowHelp` = `=If(vShowHelp=1,0,1)`,
label `=If(vShowHelp=1,'Hide help','Show help')`).

**Navigation bar** (in the header band, IDs `<TAG>_NAV_<n>`): flat buttons, h = 30, y = 9, 4 px gaps and a 14 px gap
between the D, A and R groups: `Dashboard` | `Sales` `Customers & Products` `Credit Notes` `Team & Budget` | `Reports` | `About`.
The active sheet's button is `Primary` with white bold text, and the others are `Navy2` with NavText.
Action: *Activate Sheet* `<SheetID>`. Sheet tabs stay visible as a fallback, coloured navy.

**Page title row**: title (13 pt bold) at `10,52,620,22`, subtitle (8.5 pt Muted) at `10,74,620,18`. The subtitle names the
period logic, for example "Current year to date (Jan–Sep 2026) vs same period last year".

**Help box** ("What am I looking at?", IDs `<TAG>_HELP_*`): text object, `InfoBg` fill, `InfoText` 8 pt, 1–3 lines starting
with `ⓘ`, show condition `vShowHelp=1`. The sheet-level box sits at the right of the title row (`900,52,780,40`).
Object-level boxes sit in reserved slots, so hiding them leaves calm whitespace and never reflows other objects.
Every chart also carries a short `HelpText`, which shows as the caption's info icon.

**Card**: every chart or table is a white card with a caption (9.5 pt bold) that names the measure, the unit and
the period, for example "Net Sales by Month (€) – CY vs PY". Caption icons: only XL (export) on tables, and maximize on dense charts.

**KPI tile** (Dashboard, IDs `DASH_KPI<n>_*`), made of layered text objects:
1. background card `w x 118`, white;
2. accent bar `4 x 118` at the left edge, coloured by status (calculated colour);
3. label `+14,+8` 8.5 pt bold Muted UPPERCASE with the period, for example "NET REVENUE · CYTD";
4. value `+14,+28` 20 pt bold, money as `€ 123.4 M`;
5. delta line `+14,+72` 8.5 pt, `▲ +5.2 % vs PY` in Good/Bad;
6. context line `+14,+92` 8 pt Muted, for example "PY € 117.3 M · Budget 101 %".
Optional: a sparkline (minimal line chart, no axes, transparent) at the right of the tile.

**Filter panel** (Analysis sheets, IDs `<TAG>_FLT_*`): `Panel` background `10,96,210,650`. Sections are separated by
`PanelHead` header strips (8 pt bold UPPERCASE): *Current selections* (Current Selections Box), *Period* (Year and Quarter
list boxes, horizontal), *Filters* (Multi Box: Region, Category, Channel, Team, Segment, Brand), *Search* (Search Object),
and on some sheets *Top N* (slider on `vTopN`).

**Buttons**: flat (`BS_PLAIN`). Primary is `Primary` with white text, secondary is `Panel` with Text.
Every button has a verb label ("Clear", "Show help").

**Tables**: header row bold on `#EEF2F6`, light striping (`#F7F9FB`), totals on top and bold, numbers right-aligned,
and money columns `€ #,##0`. Traffic lights and mini-charts in cells follow the semantic colour rules.

**Gauges**: flat speedometer with 3 segments (Bad, Warn, Good, using the thresholds above), a thin needle, and a value
text below. LED gauges are only for "status at a glance" (for example budget achievement per team).

## 6. Number formats and units
| Kind | Format | Example |
|---|---|---|
| Money, detail | `€ #,##0` (`vFmtMoney`) | € 1,234,567 |
| Money, KPI / compact | `Num(x/1e6,'€ #,##0.0') & ' M'` | € 123.4 M |
| Money, average | `€ #,##0` | € 2,345 |
| Percent | `0.0%` (`vFmtPct`) | 24.3% |
| Growth | `+0.0%;-0.0%` | +5.2% |
| Percentage points | `+0.0 pp;-0.0 pp`, computed as `x*100` | +1.3 pp |
| Counts | `#,##0` | 182,345 |
| Dates | `DD/MM/YYYY` (UK SET statements) | 30/09/2026 |

Chart axes use QlikView's automatic K/M abbreviation. Titles always carry the unit: "(€)", "(%)", "(count)".

## 7. Naming conventions
* Sheet IDs: `SH_DASH`, `SH_SALES`, `SH_CUST`, `SH_CN`, `SH_TEAM`, `SH_REPORT`, `SH_HELP` (the data contract).
* Object IDs: `<TAG>_<ROLE>[_<n>]` with TAG ∈ `DASH, SALES, CUST, CN, TEAM, REP, HELP`, for example `SALES_CH_TREND`,
  `CN_LB_YEAR`, `DASH_KPI1_VAL`. Chrome uses `<TAG>_HDR_*`, `<TAG>_NAV_*`, `<TAG>_TTL_*`, `<TAG>_HELP_*` and `<TAG>_FLT_*`.
* UI variables owned by the Designer start with `vUI_` (none are needed in v1 except the contract's `vTopN` and `vShowHelp`).
* Build scripts are ASCII-only. Non-ASCII glyphs come from `$QS.Glyph` (PowerShell `[char]`) or `Chr()` in expressions.
