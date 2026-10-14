# QLIK-CL: Data Model (generated)

Generated on 2026-10-14 11:53 from the open document (last reload 13/10/2026 15:48:38). Script: `_build/script/QLIK-CL.qvs`.
Interface: `spec/data-contract.md`.

## Health
* **Reload time: 29.4 s** (full 1,000,000 transactional rows, QlikView 12.10 Desktop). Target: < 90 s.
* Deterministic: hash-based pseudo-random numbers (no `Rand()`), so every reload gives identical numbers.
* **No synthetic keys** (`$Syn` tables: 0), no circular references, no loosely coupled tables. All temp tables,
  temp fields and helper variables are dropped by the script.
* Integrity (verified with set analysis): every invoice line (900000), credit-note line (100000)
  and budget row (1440) associates with a Date, Customer, Product, Sales Rep and Channel (budget: Date
  and Sales Rep only).
* Credit-note rules checked in the script (`TRACE` in the log): CreditQty ≤ Quantity, 0 < CreditAmount ≤ NetSales,
  0 ≤ CreditCost ≤ CostOfSales, invoice date ≤ credit-note date ≤ 30/09/2026. Result: **0 violations**.

## Diagram
```
                         Calendar (%DateKey)  1,096 days
                                 |
 Customers (CustomerID) ----+    |    +---- Invoices     (%LinkKey)  900,000 lines
 Products  (ProductID)  ----+-- LinkTable --+---- CreditNotes  (%LinkKey) 100,000 lines -- ReturnReasons (ReturnReasonID)
 SalesReps (SalesRepID) ----+  (%LinkKey)   +---- Budget       (%LinkKey)   1,440 rows
 Channels  (ChannelID)  ----+  991,628 rows
```
The facts hold **no dimension key** except `%LinkKey` (and `ReturnReasonID` on CreditNotes). CreditNotes point to their
original invoice line through `CN_OrigInvoiceNo` / `CN_OrigInvoiceLineID`, which **do not associate** (different field names
on purpose).

## Tables
| Table | Grain | Rows | Keys | Fields |
|---|---|---|---|---|
| `Invoices` | fact, invoice line | 900,000 | %LinkKey | %LinkKey, InvoiceLineID, InvoiceNo, InvoiceLineNo, InvoiceDate, PaymentTerms, Quantity, UnitPrice, DiscountPct, GrossSales, Discount, NetSales, CostOfSales, GrossMargin |
| `CreditNotes` | fact, credit-note line | 100,000 | %LinkKey, ReturnReasonID | %LinkKey, CreditNoteLineID, CreditNoteNo, CreditNoteLineNo, CreditNoteDate, CN_OrigInvoiceNo, CN_OrigInvoiceLineID, ReturnReasonID, CreditQty, CreditAmount, CreditCost |
| `Budget` | fact, sales rep × month | 1,440 | %LinkKey | %LinkKey, BudgetID, BudgetNetSales, BudgetGrossMargin |
| `LinkTable` | link, distinct key combination | 991,628 | %LinkKey, %DateKey, CustomerID, ProductID, SalesRepID, ChannelID | %LinkKey, %DateKey, CustomerID, ProductID, SalesRepID, ChannelID, LinkSource |
| `Calendar` | dimension, day | 1,096 | %DateKey | %DateKey, Date, Year, Quarter, Month, YearQuarter, YearMonth, Week, Weekday, Day, Flag_CYTD, Flag_PYTD, Flag_R12, Flag_PR12, Flag_CM, Flag_PM, Flag_PYM |
| `Customers` | dimension, customer | 5,000 | CustomerID | CustomerID, CustomerName, CustomerSegment, CustomerCity, CustomerCountry, CustomerRegion, CustomerSince |
| `Products` | dimension, product | 600 | ProductID | ProductID, ProductName, ProductGroup, ProductCategory, Brand, ProductListPrice, ProductStdCost |
| `SalesReps` | dimension, sales rep | 40 | SalesRepID | SalesRepID, SalesRepName, SalesTeam, SalesManager, SalesRepRegion |
| `Channels` | dimension, channel | 4 | ChannelID | ChannelID, Channel |
| `ReturnReasons` | dimension, return reason | 8 | ReturnReasonID | ReturnReasonID, ReturnReason, ReturnReasonGroup |

`%`-prefixed fields are hidden in the UI (`SET HidePrefix='%'`).

## Link table
* `%LinkKey = AutoNumber(%DateKey &'|'& CustomerID &'|'& ProductID &'|'& SalesRepID &'|'& ChannelID, 'Link')`, built in
  each fact load. Invoices use the invoice date, CreditNotes the **credit-note date**, and Budget the first day of the month.
* `LinkSource`: **Budget** 1,440, **CreditNote** 99,798, **Invoice** 890,233, **Invoice|CreditNote** 157 key combinations. `Invoice|CreditNote` = a credit note
  hit the same day/customer/product/rep/channel as an invoice line.
* Budget rows carry only `%DateKey` and `SalesRepID` (customer, product and channel are null).

## Calendar
`%DateKey` (integer date), `Date`, `Year`, `Quarter` (dual Q1..Q4), `Month` (dual; month names from the doc header, so
**September shows as `Sept`**), `YearQuarter` (dual '2025-Q1'), `YearMonth` (dual 'Jan 2025', numeric = month start), `Week`
(ISO), `Weekday` (dual Mon..Sun), `Day`, and the flags `Flag_CYTD/PYTD/R12/PR12/CM/PM/PYM` (1/0, never null; relative to the
data end date **30/09/2026**). Transactions: invoices 01/01/2024 .. 30/09/2026, credit notes 03/01/2024 .. 30/09/2026. Budget months:
01/01/2024 .. 01/12/2026.

## Document groups
| Group | Type | Fields | Labels |
|---|---|---|---|
| `drl_Geography` | drill-down | CustomerRegion → CustomerCountry → CustomerCity → CustomerName | Region, Country, City, Customer |
| `drl_Product` | drill-down | ProductCategory → ProductGroup → ProductName | Category, Product Group, Product |
| `drl_Time` | drill-down | Year → YearQuarter → YearMonth → Date | Year, Quarter, Month, Date |
| `drl_Sales` | drill-down | SalesTeam → SalesRepName | Sales Team, Sales Rep |
| `cyc_Dimension` | cyclic | CustomerRegion → ProductCategory → Channel → SalesTeam → CustomerSegment → Brand | Region, Category, Channel, Sales Team, Segment, Brand |
| `cyc_Time` | cyclic | Year → YearQuarter → YearMonth → Week → Weekday | Year, Quarter, Month, Week, Weekday |
| `cyc_Returns` | cyclic | ReturnReason → ReturnReasonGroup → ProductCategory | Return Reason, Reason Group, Category |
| `cyc_Customer` | cyclic | CustomerName → CustomerCountry → CustomerSegment | Customer, Country, Segment |

## How the data is generated (summary)
| Aspect | Logic |
|---|---|
| Volume per day | 900,000 lines spread over 01/01/2024–30/09/2026 by weight = year level × seasonality × weekday × holiday × noise; cumulative rounding gives the exact total. |
| Invoices | Lines are split into invoices (new invoice with p = 0.18, max 12 lines, never across days): **5.03 lines/invoice**, 178,931 invoices. Numbers restart yearly: INV-2024-0000001 .. INV-2026-0050813. |
| Customers | 5,000 in 7 regions. The invoice region is drawn with time-drifting shares (CEE up, UK & Ireland down); the customer inside a region follows a Pareto by size rank. Top 20 % of customers = **74.6%** of net sales. Segments: Enterprise=45.1% (177 cust.) | Mid-Market=24.4% (827 cust.) | Public Sector=12.1% (480 cust.) | SMB=18.4% (3516 cust.). |
| Sales reps | Each customer has one account manager (rep) of the team that covers its city (DACH is split North/South). |
| Channel | Mix by segment, an E-Commerce trend and weekend orders (mostly web). |
| Products | 600 products (6 categories × 4 groups × 25), Pareto popularity, log-uniform list price per group, cost = list × category cost ratio. Categories: Monitors & Displays=16.4% GM 15.7% | Networking=10.3% GM 28.0% | Notebooks & PCs=21.6% GM 9.8% | Peripherals=19.6% GM 32.0% | Software & Services=16.2% GM 40.5% | Storage=15.9% GM 21.1%. |
| Price, discount | UnitPrice = list × channel price list × segment contract factor; line DiscountPct by channel (E-Commerce highest). Largest line: € 214,302. |
| Credit notes | Propensity per invoice line (Logistics + Quality + Networking issue + Commercial) → ~105k candidates → exact random trim to 100,000. Lag by reason, weekend → Monday, only credit dates ≤ 30/09/2026. One credit note per invoice and reason (1.06 lines/CN): CN-2024-0000001 .. CN-2026-0029257. Credit value by reason: Damaged in transit=10.9% | Dead on arrival=3.0% | Goodwill credit=2.6% | Late delivery=12.0% | Order cancelled=26.6% | Pricing error=2.6% | Quality defect=21.6% | Wrong item delivered=20.7%. |
| Budget | Annual target per rep from the actual net-revenue run rate × rep noise ÷ team target achievement (normalised per team), phased by the seasonal profile, rounded to € 100. |

## Notes for Designer and QA
* **Null bucket:** budget link rows have no customer, product or channel. A chart with dimension Customer/Product/Channel and
  any expression that can see budget rows may show a `-` bucket. Use *Suppress When Value Is Null* on those dimensions.
* **Budget grain:** only SalesTeam/SalesRep and calendar fields filter the budget. With a Customer, Product or Channel
  selection, `vBudget` is null and `vBudgetAch` shows `-`.
* **Credit rate by period:** CreditAmount is dated by the credit-note date, NetSales by the invoice date.
* `CustomerName` and `ProductName` are unique, so they can be used as chart dimensions without IDs.
* `DiscountPct` carries the number format `0.0%`; amounts are plain numbers (format in the UI with `$(vFmtMoney)`).
