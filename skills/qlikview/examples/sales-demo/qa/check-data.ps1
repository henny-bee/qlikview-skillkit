# QA data checks for QLIK-CL (owner: QA). READ-ONLY: every expression uses {1}, so current selections do not matter. No lock needed.
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File <win path>\check-data.ps1 [-Deep] [-Snapshot name] [-Chunk 50000]
# -Deep     : adds the row-level tests (CN <-> original invoice join, link-table integrity) via chunked Concat()/Aggr() dumps.
# -Snapshot : additionally stores the determinism fingerprint to qa/results/snapshot-<name>.json
param([switch]$Deep, [string]$Snapshot, [int]$Chunk = 50000, [switch]$SkipStories)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-common.ps1"
. "$PSScriptRoot\lib\qa-snapshot.ps1"
$doc = Connect-QaDoc
$swAll = [Diagnostics.Stopwatch]::StartNew()
$appendix = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------- contract (binding)
$Contract = [ordered]@{
    Calendar      = @('%DateKey','Date','Year','Quarter','Month','YearQuarter','YearMonth','Week','Weekday','Day','Flag_CYTD','Flag_PYTD','Flag_R12','Flag_PR12','Flag_CM','Flag_PM','Flag_PYM')
    Customers     = @('CustomerID','CustomerName','CustomerSegment','CustomerCity','CustomerCountry','CustomerRegion','CustomerSince')
    Products      = @('ProductID','ProductName','ProductGroup','ProductCategory','Brand','ProductListPrice','ProductStdCost')
    SalesReps     = @('SalesRepID','SalesRepName','SalesTeam','SalesManager','SalesRepRegion')
    Channels      = @('ChannelID','Channel')
    ReturnReasons = @('ReturnReasonID','ReturnReason','ReturnReasonGroup')
    Invoices      = @('%LinkKey','InvoiceLineID','InvoiceNo','InvoiceLineNo','InvoiceDate','PaymentTerms','Quantity','UnitPrice','DiscountPct','GrossSales','Discount','NetSales','CostOfSales','GrossMargin')
    CreditNotes   = @('%LinkKey','CreditNoteLineID','CreditNoteNo','CreditNoteLineNo','CreditNoteDate','CN_OrigInvoiceNo','CN_OrigInvoiceLineID','ReturnReasonID','CreditQty','CreditAmount','CreditCost')
    Budget        = @('%LinkKey','BudgetID','BudgetNetSales','BudgetGrossMargin')
    LinkTable     = @('%LinkKey','%DateKey','CustomerID','ProductID','SalesRepID','ChannelID','LinkSource')
}
$ExpRows = [ordered]@{ Invoices = 900000; CreditNotes = 100000; Budget = 1440; Customers = 5000; Products = 600; SalesReps = 40; Channels = 4; ReturnReasons = 8; Calendar = 1096 }
$KeyFields = @('%LinkKey','%DateKey','CustomerID','ProductID','SalesRepID','ChannelID','ReturnReasonID')
$D_START = DNum '2024-01-01'; $D_END = DNum '2026-09-30'; $CAL_END = DNum '2026-12-31'

# ---------------------------------------------------------------- helpers
function Get-Domain([string]$f) { @((QT "Concat({1} DISTINCT [$f], '~')").Split('~') | Where-Object { $_ } | Sort-Object) }
function Test-Domain([string]$id, [string]$f, [string[]]$exp) {
    $act = Get-Domain $f; $e = ($exp | Sort-Object) -join ' ~ '; $a = $act -join ' ~ '
    Test-Qa $id "$f domain" $e $a ($e -ceq $a)
}
function Test-Inv([string]$id, [string]$name, [string]$diffExpr, [double]$tol = 0.011, [switch]$Soft) {
    $v = QN "Sum({1} If(Fabs($diffExpr) > $tol, 1, 0))"; $mx = QN "Max({1} Fabs($diffExpr))"
    Test-Qa $id $name "0 rows > $tol" "$v rows, max diff $(Format-QaVal $mx)" ($v -eq 0) -Soft:$Soft
    return $v
}
function SumP([string]$m, [string]$from, [string]$to, [string]$extra = '') {
    $set = (DRange $from $to); if ($extra) { $set = "$set,$extra" }
    QN "Sum({1<$set>} $m)"
}

# ================================================================= A. model and volumes
$tables = @(); $nt = $doc.GetTableCount(); for ($i = 0; $i -lt $nt; $i++) { $tables += [string]$doc.GetTableName($i) }
$sysTabs = @($tables | Where-Object { $_ -like '$$SysTable*' })   # QlikView system tables, positions kept for the LC vector
if ($tables.Count -eq 0) {
    Add-QaResult 'D-00' 'Document has data' '>0 tables' 0 'FAIL' 'no tables loaded - aborting'
    Write-QaReport -Name 'data' -Title 'QA data checks' | Out-Null; return
}
$expTables = @($Contract.Keys)
$missingT = @($expTables | Where-Object { $tables -notcontains $_ })
$extraT   = @($tables | Where-Object { $expTables -notcontains $_ -and $_ -notlike '$$SysTable*' })
Test-Qa 'D-01' 'Contract tables present' ($expTables -join ', ') ($tables -join ', ') ($missingT.Count -eq 0) -Note $(if ($missingT) { 'missing: ' + ($missingT -join ', ') } else { '' })
$extraNonSyn = @($extraT | Where-Object { $_ -notlike '$Syn*' })
if ($extraNonSyn.Count) { Add-QaResult 'D-01b' 'Extra (non-contract) tables' 'none' ($extraNonSyn -join ', ') 'WARN' 'islands must be justified (e.g. UI helper)' }
else { Add-QaResult 'D-01b' 'Extra (non-contract) tables' 'none' 'none' 'PASS' }

$synT = @($tables | Where-Object { $_ -like '$Syn*' })
$allFieldsTxt = QT "Concat({1} DISTINCT `$Field, '~')"
$allFields = @($allFieldsTxt.Split('~') | Where-Object { $_ })
$synF = @($allFields | Where-Object { $_ -like '$Syn*' })
Test-Qa 'D-02' 'No synthetic keys ($Syn tables/fields)' 0 ($synT.Count + $synF.Count) (($synT.Count + $synF.Count) -eq 0) -Note (($synT + $synF) -join ', ')

$lc = @(); try { $lc = @($doc.GetLooselyCoupledVector()) } catch {}
$lcTabs = @(); for ($i = 0; $i -lt $lc.Count; $i++) { if ($lc[$i]) { $lcTabs += $tables[$i] } }
Test-Qa 'D-03' 'No loosely coupled tables (circular refs)' 'none' $(if ($lcTabs) { $lcTabs -join ', ' } else { 'none' }) ($lcTabs.Count -eq 0) -Note "vector length $($lc.Count)"

$rows = @{}
foreach ($t in $tables) { $rows[$t] = QN "Sum({1<`$Table={'$t'}>} `$Rows)" }
foreach ($t in $ExpRows.Keys) { Test-QaEq 'D-04' "Rows $t" ([double]$ExpRows[$t]) $rows[$t] }
$tx = [double]$rows['Invoices'] + [double]$rows['CreditNotes']
Test-QaEq 'D-04' 'Transactional total (Invoices + CreditNotes)' 1000000.0 $tx
Add-QaResult 'D-04' 'Rows LinkTable (info, see D-25)' '~1M distinct key combos' $rows['LinkTable'] 'INFO'

try { # section ids
# D-05 unique IDs
foreach ($c in @(@('InvoiceLineID', 900000), @('CreditNoteLineID', 100000), @('BudgetID', 1440))) {
    $f = $c[0]; $n = [double]$c[1]
    $cnt = QN "Count({1} $f)"; $dc = QN "Count({1} DISTINCT $f)"; $mn = QN "Min({1} $f)"; $mx = QN "Max({1} $f)"
    $ok = ($cnt -eq $n -and $dc -eq $n)
    if ($f -ne 'BudgetID') { $ok = $ok -and $mn -eq 1 -and $mx -eq $n }
    Test-Qa 'D-05' "$f unique" "count=distinct=$n$(if ($f -ne 'BudgetID') { ", 1..$n" })" "count=$cnt distinct=$dc min=$mn max=$mx" $ok
}

} catch { Add-QaErr 'ids' $_ }
try { # section fields
# D-06..D-08 field placement via system fields
$pairsTxt = QT "Concat({1} DISTINCT `$Field & '@' & `$Table, '~')"
$fieldTables = @{}
foreach ($p in $pairsTxt.Split('~')) {
    if (-not $p) { continue }
    $kv = $p.Split('@', 2); if ($kv.Count -lt 2) { continue }
    if (-not $fieldTables.ContainsKey($kv[0])) { $fieldTables[$kv[0]] = New-Object System.Collections.Generic.List[string] }
    $fieldTables[$kv[0]].Add($kv[1])
}
$expFieldTables = @{}
foreach ($t in $Contract.Keys) { foreach ($f in $Contract[$t]) { if (-not $expFieldTables.ContainsKey($f)) { $expFieldTables[$f] = New-Object System.Collections.Generic.List[string] }; $expFieldTables[$f].Add($t) } }
$missingF = @(); $misplaced = @()
foreach ($f in ($expFieldTables.Keys | Sort-Object)) {
    if (-not $fieldTables.ContainsKey($f)) { $missingF += $f; continue }
    $e = ($expFieldTables[$f] | Sort-Object) -join ','
    $a = ($fieldTables[$f] | Sort-Object) -join ','
    if ($e -cne $a) { $misplaced += "$f in [$a] (exp [$e])" }
}
Test-Qa 'D-06' 'All contract fields exist (exact case)' "$($expFieldTables.Count) fields" "$($expFieldTables.Count - $missingF.Count) found" ($missingF.Count -eq 0) -Note $(if ($missingF) { 'missing: ' + ($missingF -join ', ') } else { '' })
Test-Qa 'D-07' 'Contract fields in the contract tables (keys incl.)' 'exact table sets' "$($misplaced.Count) mismatches" ($misplaced.Count -eq 0) -Note ($misplaced -join '; ')
$multi = @()
foreach ($f in $fieldTables.Keys) {
    if ($f -like '$*') { continue }
    if ($fieldTables[$f].Count -gt 1 -and $KeyFields -cnotcontains $f) { $multi += "$f in [" + (($fieldTables[$f] | Sort-Object) -join ',') + ']' }
}
Test-Qa 'D-08' 'Non-key fields live in exactly one table (no unintended associations)' 'none' "$($multi.Count)" ($multi.Count -eq 0) -Note ($multi -join '; ')
$extraF = @()
foreach ($f in ($fieldTables.Keys | Sort-Object)) { if ($f -notlike '$*' -and -not $expFieldTables.ContainsKey($f)) { $extraF += "$f [" + ($fieldTables[$f] -join ',') + ']' } }
Add-QaResult 'D-06b' 'Extra (non-contract) fields' '-' $(if ($extraF) { "$($extraF.Count)" } else { 'none' }) 'INFO' ($extraF -join '; ')
# facts must not contain dimension keys other than %LinkKey (+ ReturnReasonID in CreditNotes)
$factKeyViol = @()
foreach ($t in 'Invoices','CreditNotes','Budget') {
    foreach ($k in $KeyFields) {
        if ($k -eq '%LinkKey' -or ($t -eq 'CreditNotes' -and $k -eq 'ReturnReasonID')) { continue }
        if ($fieldTables.ContainsKey($k) -and $fieldTables[$k] -contains $t) { $factKeyViol += "$k in $t" }
    }
}
Test-Qa 'D-07b' 'Facts contain no dimension key except %LinkKey (+ReturnReasonID in CN)' 'none' $(if ($factKeyViol) { $factKeyViol -join ', ' } else { 'none' }) ($factKeyViol.Count -eq 0)

} catch { Add-QaErr 'fields' $_ }
try { # section hidden+script
# D-09 hidden % fields
$hidOk = $null
try { $fd = $doc.GetFieldDescription('%LinkKey'); $hidOk = [bool]$fd.IsHidden } catch {}
$script = [string]$doc.GetProperties().Script
$hp = $script -match "(?im)^\s*SET\s+HidePrefix\s*=\s*'%'\s*;"
Test-Qa 'D-09' "%-fields hidden (SET HidePrefix='%')" 'hidden + SET present' "IsHidden=$hidOk, SET=$hp" ($hp -and $hidOk -ne $false)

# D-10 script header and config
$hdr = @("SET ThousandSep=',';", "SET DecimalSep='.';", "SET MoneyThousandSep=',';", "SET MoneyDecimalSep='.';", "SET TimeFormat='hh:mm:ss';",
         "SET DateFormat='DD/MM/YYYY';", "SET TimestampFormat='DD/MM/YYYY hh:mm:ss[.fff]';", 'SET FirstWeekDay=0;', 'SET BrokenWeeks=0;', 'SET ReferenceDay=4;',
         'SET FirstMonthOfYear=1;', "SET CollationLocale='en-GB';", "SET MonthNames='Jan;Feb;Mar;Apr;May;Jun;Jul;Aug;Sept;Oct;Nov;Dec';",
         "SET LongMonthNames='January;February;March;April;May;June;July;August;September;October;November;December';",
         "SET DayNames='Mon;Tue;Wed;Thu;Fri;Sat;Sun';", "SET LongDayNames='Monday;Tuesday;Wednesday;Thursday;Friday;Saturday;Sunday';")
$hdrMissing = @($hdr | Where-Object { $script.IndexOf($_) -lt 0 })
Test-Qa 'D-10' 'Original UK SET header unchanged' "$($hdr.Count) lines" "$($hdr.Count - $hdrMissing.Count) found" ($hdrMissing.Count -eq 0) -Note ($hdrMissing -join ' ')
$mf = [regex]::Match($script, "(?im)^\s*SET\s+MoneyFormat\s*=\s*'([^']*)'")
$mfv = if ($mf.Success) { $mf.Groups[1].Value } else { $null }
Test-Qa 'D-10' 'MoneyFormat is EUR' "contains $QaEuro" $mfv ($null -ne $mfv -and ($mfv.Contains($QaEuro) -or $mfv -match 'EUR') -and $mfv -notmatch [char]0x00A3)
$scriptNoComments = [regex]::Replace([regex]::Replace($script, '(?s)/\*.*?\*/', ''), '(?m)//.*$', '')
$scriptNoComments = [regex]::Replace($scriptNoComments, '(?im)^\s*REM\b.*?;', '')
$rand = [regex]::Matches($scriptNoComments, '(?i)\brand\s*\(')
Test-Qa 'D-10' 'No Rand() in script (determinism)' 0 $rand.Count ($rand.Count -eq 0)
foreach ($v in @(@('vCfgInvoiceLines', '900000'), @('vCfgCreditNoteLines', '100000'))) {
    $val = $null; try { $val = [string]$doc.Variables($v[0]).GetContent().String } catch {}
    Test-QaEq 'D-10' "Variable $($v[0])" $v[1] $val
}

} catch { Add-QaErr 'hidden+script' $_ }
try { # section nulls
# D-11 no nulls in fact measures
$nullChecks = [ordered]@{
    Invoices    = @('InvoiceNo','InvoiceLineNo','InvoiceDate','PaymentTerms','Quantity','UnitPrice','DiscountPct','GrossSales','Discount','NetSales','CostOfSales','GrossMargin')
    CreditNotes = @('CreditNoteNo','CreditNoteLineNo','CreditNoteDate','CN_OrigInvoiceNo','CN_OrigInvoiceLineID','CreditQty','CreditAmount','CreditCost')
    Budget      = @('BudgetNetSales','BudgetGrossMargin')
}
foreach ($t in $nullChecks.Keys) {
    $bad = @()
    foreach ($f in $nullChecks[$t]) { $c = QN "Count({1} $f)"; if ($c -ne $ExpRows[$t]) { $bad += "$f=$c" } }
    Test-Qa 'D-11' "No nulls in $t fields" "count = $($ExpRows[$t]) each" $(if ($bad) { $bad -join ', ' } else { 'all complete' }) ($bad.Count -eq 0)
}

} catch { Add-QaErr 'nulls' $_ }
try { # section keys
# ================================================================= B. key integrity
foreach ($f in 'LinkSource','%DateKey','Date','CustomerID','CustomerName','ProductID','ProductName','SalesRepID','SalesRepName','ChannelID','Channel') {
    Test-QaEq 'D-20' "Invoice lines reach $f" 900000.0 (QN "Count({1<[$f]={""*""}>} InvoiceLineID)")
}
foreach ($f in 'LinkSource','%DateKey','Date','CustomerID','CustomerName','ProductID','ProductName','SalesRepID','SalesRepName','ChannelID','Channel','ReturnReasonID','ReturnReason') {
    Test-QaEq 'D-21' "CN lines reach $f" 100000.0 (QN "Count({1<[$f]={""*""}>} CreditNoteLineID)")
}
foreach ($f in 'SalesRepID','SalesRepName','SalesTeam','%DateKey','Date','LinkSource') { Test-QaEq 'D-22' "Budget rows reach $f" 1440.0 (QN "Count({1<[$f]={""*""}>} BudgetID)") }
foreach ($f in 'CustomerID','CustomerName','ProductID','ProductName','ChannelID','Channel') { Test-QaEq 'D-22' "Budget rows NOT linked to $f" 0.0 (QN "Count({1<[$f]={""*""}>} BudgetID)") }
Test-QaEq 'D-23' 'Invoice lines on link rows tagged *Invoice*' 900000.0 (QN "Count({1<LinkSource={""*Invoice*""}>} InvoiceLineID)")
Test-QaEq 'D-23' 'CN lines on link rows tagged *CreditNote*' 100000.0 (QN "Count({1<LinkSource={""*CreditNote*""}>} CreditNoteLineID)")
Test-QaEq 'D-23' 'Budget rows on link rows tagged *Budget*' 1440.0 (QN "Count({1<LinkSource={""*Budget*""}>} BudgetID)")
$lsVals = @((QT "Concat({1} DISTINCT LinkSource, '~')").Split('~') | Where-Object { $_ })
$lsBad = @($lsVals | Where-Object { @($_.Split('|') | Where-Object { $_ -cnotin 'Invoice','CreditNote','Budget' }).Count -gt 0 })
Test-Qa 'D-23' 'LinkSource domain' 'Invoice|CreditNote|Budget (+ combos)' ($lsVals -join ', ') ($lsBad.Count -eq 0 -and $lsVals.Count -gt 0)
$fvc = QN "FieldValueCount('%LinkKey')"
Test-Qa 'D-25' 'Distinct %LinkKey = LinkTable rows' $rows['LinkTable'] $fvc ($null -ne $fvc -and $fvc -eq $rows['LinkTable']) -Note 'a fact key missing in LinkTable or a duplicated link row breaks this'
$fvcD = QN "FieldValueCount('%DateKey')"
Test-QaEq 'D-25' 'Distinct %DateKey = calendar days (no link dates outside calendar)' 1096.0 $fvcD

} catch { Add-QaErr 'keys' $_ }
try { # section domains
# D-26 domains
Test-Domain 'D-26' 'Channel' @('Direct Sales','E-Commerce','Distributor','Retail Partner')
Test-Domain 'D-26' 'ProductCategory' @('Notebooks & PCs','Monitors & Displays','Networking','Storage','Peripherals','Software & Services')
Test-Domain 'D-26' 'CustomerSegment' @('Enterprise','Mid-Market','SMB','Public Sector')
Test-Domain 'D-26' 'CustomerRegion' @('DACH','Benelux','Nordics','UK & Ireland','France','Southern Europe','CEE')
Test-Domain 'D-26' 'ReturnReasonGroup' @('Logistics','Quality','Commercial')
$pg = QN 'Count({1} DISTINCT ProductGroup)'; Test-Qa 'D-26' 'ProductGroup count ~24' '20..28' $pg ($pg -ge 20 -and $pg -le 28) -Soft
$br = QN 'Count({1} DISTINCT Brand)'; Test-Qa 'D-26' 'Brand count ~8' '6..10' $br ($br -ge 6 -and $br -le 10) -Soft
$st = QN 'Count({1} DISTINCT SalesTeam)'; Test-QaEq 'D-26' 'SalesTeam count' 8.0 $st
$tmMin = QN 'Min({1} Aggr({1} Count(DISTINCT SalesRepName), SalesTeam))'; $tmMax = QN 'Max({1} Aggr({1} Count(DISTINCT SalesRepName), SalesTeam))'
Test-Qa 'D-26' 'Reps per team' '5 each' "min=$tmMin max=$tmMax" ($tmMin -eq 5 -and $tmMax -eq 5)
$reasons = Get-Domain 'ReturnReason'
$qd = @($reasons | Where-Object { $_ -match '(?i)quality\s*defect' })
Test-Qa 'D-26' 'ReturnReason: 8 reasons incl. Quality defect' '8, incl. Quality defect' ($reasons -join ' ~ ') ($reasons.Count -eq 8 -and $qd.Count -ge 1)
$rrg = QN 'Max({1} Aggr({1} Count(DISTINCT ReturnReasonGroup), ReturnReason))'
Test-QaEq 'D-26' 'Each ReturnReason has one group' 1.0 $rrg
foreach ($h in @(@('CustomerCountry','CustomerRegion'), @('CustomerCity','CustomerCountry'), @('ProductGroup','ProductCategory'), @('SalesRepName','SalesTeam'), @('SalesTeam','SalesManager'))) {
    $m = QN "Max({1} Aggr({1} Count(DISTINCT [$($h[1])]), [$($h[0])]))"
    Test-Qa 'D-26' "Hierarchy: each $($h[0]) has one $($h[1])" 1 $m ($m -eq 1) -Soft -Note 'needed for clean drill-down'
}
$cs = QN "Max({1} CustomerSince)"; Test-Qa 'D-26' 'CustomerSince <= data end' (Get-Date '2026-09-30').ToString('yyyy-MM-dd') $(if ($cs) { [datetime]::FromOADate($cs).ToString('yyyy-MM-dd') }) ($cs -le $D_END) -Soft

} catch { Add-QaErr 'domains' $_ }
try { # section arithmetic
# ================================================================= C. arithmetic invariants
Test-Inv 'D-30' 'GrossSales = Quantity x UnitPrice' 'GrossSales - Quantity*UnitPrice' | Out-Null
$dv = Test-Inv 'D-31' 'Discount = GrossSales x DiscountPct' 'Discount - GrossSales*DiscountPct' -Soft
if ($dv -gt 0) {
    $dv100 = QN 'Sum({1} If(Fabs(Discount - GrossSales*DiscountPct/100) > 0.011, 1, 0))'
    Add-QaResult 'D-31b' 'Discount = GrossSales x DiscountPct/100 (pct stored x100?)' '-' "$dv100 rows" 'INFO'
}
Test-Inv 'D-32' 'NetSales = GrossSales - Discount' 'NetSales - (GrossSales - Discount)' | Out-Null
Test-Inv 'D-33' 'GrossMargin = NetSales - CostOfSales' 'GrossMargin - (NetSales - CostOfSales)' | Out-Null
$rng = [ordered]@{
    'Quantity integer >= 1'              = 'Sum({1} If(Quantity < 1 or Quantity <> Floor(Quantity), 1, 0))'
    'UnitPrice > 0'                      = 'Sum({1} If(UnitPrice <= 0, 1, 0))'
    'DiscountPct in [0, 0.6)'            = 'Sum({1} If(DiscountPct < 0 or DiscountPct >= 0.6, 1, 0))'
    'NetSales > 0'                       = 'Sum({1} If(NetSales <= 0, 1, 0))'
    'CostOfSales > 0'                    = 'Sum({1} If(CostOfSales <= 0, 1, 0))'
    'InvoiceLineNo integer >= 1'         = 'Sum({1} If(InvoiceLineNo < 1 or InvoiceLineNo <> Floor(InvoiceLineNo), 1, 0))'
    'CreditQty integer >= 0'             = 'Sum({1} If(CreditQty < 0 or CreditQty <> Floor(CreditQty), 1, 0))'
    'CreditAmount > 0'                   = 'Sum({1} If(CreditAmount <= 0, 1, 0))'
    'CreditCost >= 0'                    = 'Sum({1} If(CreditCost < 0, 1, 0))'
    'BudgetNetSales > 0'                 = 'Sum({1} If(BudgetNetSales <= 0, 1, 0))'
    '0 < BudgetGrossMargin < BudgetNetSales' = 'Sum({1} If(BudgetGrossMargin <= 0 or BudgetGrossMargin >= BudgetNetSales, 1, 0))'
    'ProductListPrice > 0'               = 'Sum({1} If(ProductListPrice <= 0, 1, 0))'
    'ProductStdCost < ProductListPrice'  = 'Sum({1} If(ProductStdCost >= ProductListPrice or ProductStdCost <= 0, 1, 0))'
}
foreach ($k in $rng.Keys) { Test-QaEq 'D-34' "Range: $k" 0.0 (QN $rng[$k]) }
$cq0 = QN 'Count({1<CreditQty={0}>} CreditNoteLineID)'; $cq0r = QT "Concat({1<CreditQty={0}>} DISTINCT ReturnReason, ', ')"
$cq0g = QT "Concat({1<CreditQty={0}>} DISTINCT ReturnReasonGroup, ', ')"
Test-Qa 'D-34' 'CreditQty = 0 lines are value-only credits (Commercial reasons)' 'group Commercial only' "$cq0 lines; reasons: $cq0r" ($cq0 -eq 0 -or $cq0g -ceq 'Commercial') -Soft
$negGm = QN 'Sum({1} If(GrossMargin < 0, 1, 0))'
Add-QaResult 'D-34' 'Info: invoice lines with negative GrossMargin' '-' $negGm 'INFO'
$sGS = QN 'Sum({1} GrossSales)'; $sD = QN 'Sum({1} Discount)'; $sNS = QN 'Sum({1} NetSales)'; $sC = QN 'Sum({1} CostOfSales)'; $sGM = QN 'Sum({1} GrossMargin)'
Test-Qa 'D-35' 'Sum(GrossSales) - Sum(Discount) = Sum(NetSales)' $sNS ($sGS - $sD) ([math]::Abs($sGS - $sD - $sNS) -le 1)
Test-Qa 'D-35' 'Sum(NetSales) - Sum(CostOfSales) = Sum(GrossMargin)' $sGM ($sNS - $sC) ([math]::Abs($sNS - $sC - $sGM) -le 1)

} catch { Add-QaErr 'arithmetic' $_ }
try { # section calendar
# ================================================================= E. dates and calendar
foreach ($f in 'InvoiceDate','CreditNoteDate') {
    $mn = QN "Min({1} $f)"; $mx = QN "Max({1} $f)"; $frac = QN "Sum({1} If($f <> Floor($f), 1, 0))"
    $fmt = { param($x) if ($null -eq $x) { '(null)' } else { [datetime]::FromOADate($x).ToString('yyyy-MM-dd') } }
    Test-Qa 'D-50' "$f within 2024-01-01..2026-09-30" '2024-01-01..2026-09-30' ("{0}..{1}" -f (& $fmt $mn), (& $fmt $mx)) ($mn -ge $D_START -and $mx -le $D_END)
    Test-QaEq 'D-50' "$f has no time part" 0.0 $frac
}
$calRows = QN "Count({1} DISTINCT Date)"; $calMin = QN 'Min({1} Date)'; $calMax = QN 'Max({1} Date)'
Test-Qa 'D-52' 'Calendar 2024-01-01..2026-12-31 contiguous' "1096 days $D_START..$CAL_END" "$calRows days $calMin..$calMax" ($calRows -eq 1096 -and $calMin -eq $D_START -and $calMax -eq $CAL_END -and ($calMax - $calMin + 1) -eq $calRows)
$dkMismatch = QN 'Sum({1} If(Num(Floor(Date)) <> Num(%DateKey), 1, 0))'
Test-QaEq 'D-52' 'Calendar Date = %DateKey' 0.0 $dkMismatch

# Exhaustive calendar attribute check against my own computation
$calTxt = QT ("Concat({1} Num(Date, '0', '.', '') & '|' & Year & '|' & Quarter & '|' & Num(Month, '0', '.', '') & '|' & Text(Month) & '|' & YearQuarter & '|' & Num(YearMonth, '0.######', '.', '') & '|' & Text(YearMonth)" +
              " & '|' & Num(Week, '0', '.', '') & '|' & Num(Weekday, '0', '.', '') & '|' & Text(Weekday) & '|' & Num(Day, '0', '.', '') & '|' & Text(Date) & '|' & Flag_CYTD & '|' & Flag_PYTD & '|' & Flag_R12 & '|' & Flag_PR12" +
              " & '|' & Flag_CM & '|' & Flag_PM & '|' & Flag_PYM, '~', Date)")
$monTxt = @('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sept','Oct','Nov','Dec')   # from the mandated MonthNames SET
$dayTxt = @('Mon','Tue','Wed','Thu','Fri','Sat','Sun')
$flagWin = [ordered]@{ Flag_CYTD = @('2026-01-01','2026-09-30'); Flag_PYTD = @('2025-01-01','2025-09-30'); Flag_R12 = @('2025-10-01','2026-09-30'); Flag_PR12 = @('2024-10-01','2025-09-30');
                       Flag_CM = @('2026-09-01','2026-09-30'); Flag_PM = @('2026-08-01','2026-08-31'); Flag_PYM = @('2025-09-01','2025-09-30') }
$flagIdx = @{ Flag_CYTD = 13; Flag_PYTD = 14; Flag_R12 = 15; Flag_PR12 = 16; Flag_CM = 17; Flag_PM = 18; Flag_PYM = 19 }
$bad = [ordered]@{}; foreach ($k in 'Year','Quarter','Month','YearQuarter','YearMonthText','YearMonthOrder','Week','Weekday','Day','DateText') { $bad[$k] = 0 }
$flagCnt = @{}; $flagBad = @{}; $flagNull = @{}; foreach ($k in $flagWin.Keys) { $flagCnt[$k] = 0; $flagBad[$k] = 0; $flagNull[$k] = 0 }
$samples = @{}
$calRecs = @($calTxt.Split('~') | Where-Object { $_ })
$prevYm = $null; $prevKey = $null; $ymNumByMonth = @{}
foreach ($r in $calRecs) {
    $c = $r.Split('|'); $dn = [double]$c[0]; $d = [datetime]::FromOADate($dn)
    $q = 'Q' + [math]::Ceiling($d.Month / 3)
    $dow = ([int]$d.DayOfWeek + 6) % 7                          # Mon=0
    $thu = $d.AddDays(3 - $dow); $isoWeek = [math]::Floor(($thu.DayOfYear - 1) / 7) + 1
    $chk = [ordered]@{
        Year = ($c[1] -eq [string]$d.Year); Quarter = ($c[2] -ceq $q); Month = ($c[3] -eq [string]$d.Month)
        YearQuarter = ($c[5] -ceq "$($d.Year)-$q"); YearMonthText = ($c[7] -ceq "$($monTxt[$d.Month-1]) $($d.Year)" -or $c[7] -ceq "$($d.ToString('MMM', $QaInv)) $($d.Year)")
        Week = ($c[8] -eq [string]$isoWeek); Weekday = ($c[10] -ceq $dayTxt[$dow]); Day = ($c[11] -eq [string]$d.Day); DateText = ($c[12] -ceq $d.ToString('dd/MM/yyyy', $QaInv))
    }
    foreach ($k in $chk.Keys) { if (-not $chk[$k]) { $bad[$k]++; if (-not $samples[$k]) { $samples[$k] = "$($d.ToString('yyyy-MM-dd')): $r" } } }
    $mkey = $d.Year * 100 + $d.Month
    if ($ymNumByMonth.ContainsKey($mkey)) { if ($ymNumByMonth[$mkey] -ne $c[6]) { $bad['YearMonthOrder']++ } } else { $ymNumByMonth[$mkey] = $c[6] }
    foreach ($k in $flagWin.Keys) {
        $v = $c[$flagIdx[$k]]; $in = ($dn -ge (DNum $flagWin[$k][0]) -and $dn -le (DNum $flagWin[$k][1]))
        if ($v -ne '0' -and $v -ne '1') { $flagNull[$k]++ }
        if ($v -eq '1') { $flagCnt[$k]++ }
        if (($v -eq '1') -ne $in) { $flagBad[$k]++ }
    }
}
# YearMonth numeric order must follow calendar order
$ymKeys = @($ymNumByMonth.Keys | Sort-Object); $ymOrderBad = 0
for ($i = 1; $i -lt $ymKeys.Count; $i++) { if ([double]$ymNumByMonth[$ymKeys[$i]] -le [double]$ymNumByMonth[$ymKeys[$i-1]]) { $ymOrderBad++ } }
$bad['YearMonthOrder'] += $ymOrderBad
Test-QaEq 'D-54' 'Calendar rows dumped' 1096 $calRecs.Count
foreach ($k in $bad.Keys) { Test-QaEq 'D-54' "Calendar attribute $k correct for all days" 0 $bad[$k] -Note $(if ($samples[$k]) { 'e.g. ' + $samples[$k] } else { '' }) }
Test-QaEq 'D-54' 'YearMonth distinct values' 36 $ymKeys.Count
$expFlagCnt = @{ Flag_CYTD = 273; Flag_PYTD = 273; Flag_R12 = 365; Flag_PR12 = 365; Flag_CM = 30; Flag_PM = 31; Flag_PYM = 30 }
foreach ($k in $flagWin.Keys) {
    Test-Qa 'D-53' "$k exact ($($flagWin[$k][0])..$($flagWin[$k][1]))" "$($expFlagCnt[$k]) days, 0 wrong, 0 non-0/1" "$($flagCnt[$k]) days, $($flagBad[$k]) wrong, $($flagNull[$k]) non-0/1" ($flagCnt[$k] -eq $expFlagCnt[$k] -and $flagBad[$k] -eq 0 -and $flagNull[$k] -eq 0)
    $nn = QN "Count({1} $k)"; Test-QaEq 'D-53' "$k never null" 1096.0 $nn
}
$monthTexts = @((QT "Concat({1} DISTINCT Month, ',', Month)").Split(','))
Add-QaResult 'D-54' 'Info: Month texts (from mandated MonthNames SET)' '-' ($monthTexts -join ',') 'INFO'

} catch { Add-QaErr 'calendar' $_ }
try { # section budget
# D-55 budget grain
$bReps = QN "Count({1<BudgetID={""*""}>} DISTINCT SalesRepName)"; $bMon = QN "Count({1<BudgetID={""*""}>} DISTINCT Date)"
$bNotFirst = QN "Count({1<BudgetID={""*""}>} DISTINCT If(Day <> 1, Date))"
$bMin = QN "Min({1<BudgetID={""*""}>} Date)"; $bMax = QN "Max({1<BudgetID={""*""}>} Date)"
$bDup = QN "Max({1} Aggr({1} Count(BudgetID), SalesRepID, %DateKey))"
Test-Qa 'D-55' 'Budget grain rep x month' '40 reps x 36 months, 1st of month, 2024-01..2026-12, 1 row each' "reps=$bReps months=$bMon notFirst=$bNotFirst min=$bMin max=$bMax maxRowsPerCell=$bDup" ($bReps -eq 40 -and $bMon -eq 36 -and $bNotFirst -eq 0 -and $bMin -eq $D_START -and $bMax -eq (DNum '2026-12-01') -and $bDup -eq 1)

} catch { Add-QaErr 'budget' $_ }
try { # section plausibility
# ================================================================= F. plausibility
$sCA = QN 'Sum({1} CreditAmount)'
Test-QaRange 'D-60' 'Overall credit rate CreditAmount/NetSales' ($sCA / $sNS) 0.04 0.06 0.035 0.065
Test-QaRange 'D-61' 'Overall gross margin %' ($sGM / $sNS) 0.18 0.28 0.16 0.30
$nInv = QN 'Count({1} DISTINCT InvoiceNo)'
Test-QaRange 'D-62' 'Average lines per invoice' (900000 / $nInv) 4 6 3.5 6.5 -Fmt '0.00' -Note "$nInv invoices"
Test-QaEq 'D-62' 'InvoiceLineNo is 1..n within each invoice' 0.0 (QN 'Sum({1} Aggr({1} If(Min(InvoiceLineNo) <> 1 or Max(InvoiceLineNo) <> Count(InvoiceLineID) or Count(DISTINCT InvoiceLineNo) <> Count(InvoiceLineID), 1, 0), InvoiceNo))')
Test-QaEq 'D-62' 'One InvoiceDate per invoice' 1.0 (QN 'Max({1} Aggr({1} Count(DISTINCT InvoiceDate), InvoiceNo))')
# note: Count(DISTINCT <key field>) is ambiguous in QlikView, so non-key attributes are counted
Test-QaEq 'D-62' 'One customer per invoice' 1.0 (QN 'Max({1} Aggr({1} Count(DISTINCT CustomerName), InvoiceNo))')
$rc = QN 'Max({1} Aggr({1} RangeMax(Count(DISTINCT SalesRepName), Count(DISTINCT Channel)), InvoiceNo))'
Test-Qa 'D-62' 'One rep and channel per invoice' 1 $rc ($rc -eq 1) -Soft
Test-QaEq 'D-62' 'CreditNoteLineNo is 1..n within each credit note' 0.0 (QN 'Sum({1} Aggr({1} If(Min(CreditNoteLineNo) <> 1 or Max(CreditNoteLineNo) <> Count(CreditNoteLineID) or Count(DISTINCT CreditNoteLineNo) <> Count(CreditNoteLineID), 1, 0), CreditNoteNo))')
Test-QaEq 'D-62' 'One date and customer per credit note' 1.0 (QN 'Max({1} Aggr({1} RangeMax(Count(DISTINCT CreditNoteDate), Count(DISTINCT CustomerName)), CreditNoteNo))')
Test-QaEq 'D-63' "InvoiceNo format INV-YYYY-NNNNNNN, YYYY = invoice year" 0.0 (QN "Sum({1} If(Len(InvoiceNo) <> 16 or Left(InvoiceNo, 4) <> 'INV-' or Mid(InvoiceNo, 9, 1) <> '-' or Num#(Mid(InvoiceNo, 5, 4)) <> Year(InvoiceDate) or Not IsNum(Num#(Right(InvoiceNo, 7), '0000000')), 1, 0))")
Test-QaEq 'D-63' "CreditNoteNo format CN-YYYY-NNNNNNN, YYYY = CN year" 0.0 (QN "Sum({1} If(Len(CreditNoteNo) <> 15 or Left(CreditNoteNo, 3) <> 'CN-' or Mid(CreditNoteNo, 8, 1) <> '-' or Num#(Mid(CreditNoteNo, 4, 4)) <> Year(CreditNoteDate) or Not IsNum(Num#(Right(CreditNoteNo, 7), '0000000')), 1, 0))")
$pt = Get-Domain 'PaymentTerms'
Add-QaResult 'D-63' 'PaymentTerms values (contract: "Net 30" ...)' 'Net nn ...' ($pt -join ', ') 'INFO'

$ns24 = SumP 'NetSales' '2024-01-01' '2024-12-31'; $ns25 = SumP 'NetSales' '2025-01-01' '2025-12-31'
$nsCY = SumP 'NetSales' '2026-01-01' '2026-09-30'; $nsPY = SumP 'NetSales' '2025-01-01' '2025-09-30'
Test-QaRange 'D-64' 'NetSales YoY 2025 vs 2024 (~ +8%)' ($ns25 / $ns24 - 1) 0.06 0.10 0.05 0.11
Test-QaRange 'D-64' 'NetSales YoY CYTD vs PYTD (~ +5%)' ($nsCY / $nsPY - 1) 0.03 0.07 0.02 0.08

} catch { Add-QaErr 'plausibility' $_ }
try { # section stories
# ================================================================= stories
if (-not $SkipStories) {
    $yr = [ordered]@{ '2024' = @('2024-01-01','2024-12-31'); '2025' = @('2025-01-01','2025-12-31'); '2026' = @('2026-01-01','2026-09-30') }
    # S1 Networking credit rate
    $cr = [ordered]@{}
    foreach ($y in $yr.Keys) { $cr[$y] = (SumP 'CreditAmount' $yr[$y][0] $yr[$y][1] "ProductCategory={'Networking'}") / (SumP 'NetSales' $yr[$y][0] $yr[$y][1] "ProductCategory={'Networking'}") }
    Test-QaRange 'S1' 'Networking credit rate 2024 (~3%)' $cr['2024'] 0.02 0.045 0.015 0.05
    Test-QaRange 'S1' 'Networking credit rate 2026 (~9%)' $cr['2026'] 0.07 0.11 0.06 0.12
    Test-Qa 'S1' 'Networking credit rate rises every year' 'r2024 < r2025 < r2026' (($cr.Values | ForEach-Object { $_.ToString('0.0%', $QaInv) }) -join ' < ') ($cr['2024'] -lt $cr['2025'] -and $cr['2025'] -lt $cr['2026'])
    if ($qd.Count -ge 1) {
        $qdName = $qd[0]
        $rs26 = @{}; foreach ($r in $reasons) { $rs26[$r] = SumP 'CreditAmount' '2026-01-01' '2026-09-30' "ProductCategory={'Networking'},ReturnReason={'$r'}" }
        $top = ($rs26.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
        Test-QaEq 'S1' 'Largest Networking return reason 2026' $qdName $top
        $sh24 = (SumP 'CreditAmount' '2024-01-01' '2024-12-31' "ProductCategory={'Networking'},ReturnReason={'$qdName'}") / (SumP 'CreditAmount' '2024-01-01' '2024-12-31' "ProductCategory={'Networking'}")
        $sh26 = $rs26[$qdName] / (SumP 'CreditAmount' '2026-01-01' '2026-09-30' "ProductCategory={'Networking'}")
        Test-Qa 'S1' "Share of '$qdName' in Networking credits grows" 'share2026 > share2024' ("{0} -> {1}" -f $sh24.ToString('0.0%', $QaInv), $sh26.ToString('0.0%', $QaInv)) ($sh26 -gt $sh24 + 0.05)
    }
    $others = @()
    foreach ($cat in @('Notebooks & PCs','Monitors & Displays','Storage','Peripherals','Software & Services')) {
        $r24 = (SumP 'CreditAmount' '2024-01-01' '2024-12-31' "ProductCategory={'$cat'}") / (SumP 'NetSales' '2024-01-01' '2024-12-31' "ProductCategory={'$cat'}")
        $r26 = (SumP 'CreditAmount' '2026-01-01' '2026-09-30' "ProductCategory={'$cat'}") / (SumP 'NetSales' '2026-01-01' '2026-09-30' "ProductCategory={'$cat'}")
        $others += [pscustomobject]@{ Cat = $cat; R24 = $r24; R26 = $r26 }
    }
    $climb = @($others | Where-Object { $_.R26 - $_.R24 -gt 0.02 })
    Test-Qa 'S1' 'No other category climbs > 2pp 2024->2026' 'none' (($others | ForEach-Object { "$($_.Cat) $($_.R24.ToString('0.0%', $QaInv))->$($_.R26.ToString('0.0%', $QaInv))" }) -join '; ') ($climb.Count -eq 0) -Soft

    # S2 seasonality and growth
    foreach ($y in '2024','2025') {
        $qs = @(); foreach ($qq in @(@('01-01','03-31'), @('04-01','06-30'), @('07-01','09-30'), @('10-01','12-31'))) { $qs += SumP 'NetSales' "$y-$($qq[0])" "$y-$($qq[1])" }
        $mxq = [array]::IndexOf($qs, ($qs | Measure-Object -Maximum).Maximum) + 1
        Test-QaEq 'S2' "Q4 is the peak quarter $y" 4 $mxq -Note (($qs | ForEach-Object { $_.ToString('#,##0', $QaInv) }) -join ' / ')
    }
    foreach ($y in '2024','2025','2026') {
        $jul = SumP 'NetSales' "$y-07-01" "$y-07-31"; $aug = SumP 'NetSales' "$y-08-01" "$y-08-31"; $sep = SumP 'NetSales' "$y-09-01" "$y-09-30"
        Test-Qa 'S2' "August dip $y" 'Aug < Jul and Aug < Sep' ("Jul {0} / Aug {1} / Sep {2}" -f $jul.ToString('#,##0', $QaInv), $aug.ToString('#,##0', $QaInv), $sep.ToString('#,##0', $QaInv)) ($aug -lt $jul -and $aug -lt $sep)
    }
    $reg = @()
    foreach ($r in @('DACH','Benelux','Nordics','UK & Ireland','France','Southern Europe','CEE')) {
        $e = "CustomerRegion={'$r'}"
        $reg += [pscustomobject]@{ R = $r; Y25 = (SumP 'NetSales' '2025-01-01' '2025-12-31' $e) / (SumP 'NetSales' '2024-01-01' '2024-12-31' $e) - 1
                                   YTD = (SumP 'NetSales' '2026-01-01' '2026-09-30' $e) / (SumP 'NetSales' '2025-01-01' '2025-09-30' $e) - 1 }
    }
    $regTxt = ($reg | ForEach-Object { "$($_.R) $($_.Y25.ToString('+0.0%;-0.0%', $QaInv))/$($_.YTD.ToString('+0.0%;-0.0%', $QaInv))" }) -join '; '
    $topY25 = ($reg | Sort-Object Y25 -Descending | Select-Object -First 1).R; $topYTD = ($reg | Sort-Object YTD -Descending | Select-Object -First 1).R
    Test-Qa 'S2' 'CEE grows fastest (2025 and CYTD)' 'CEE/CEE' "$topY25/$topYTD" ($topY25 -eq 'CEE' -and $topYTD -eq 'CEE') -Note $regTxt
    $uk = $reg | Where-Object R -eq 'UK & Ireland'
    Test-Qa 'S2' 'UK & Ireland flat (|YoY| <= 2%)' '+-2% / +-2%' ("{0} / {1}" -f $uk.Y25.ToString('0.0%', $QaInv), $uk.YTD.ToString('0.0%', $QaInv)) ([math]::Abs($uk.Y25) -le 0.02 -and [math]::Abs($uk.YTD) -le 0.02) -Soft

    # S3 sales team vs budget (2026 CYTD actual NetRevenue vs budget Jan-Sep 2026)
    $teams = Get-Domain 'SalesTeam'; $ach = @()
    foreach ($t in $teams) {
        $e = "SalesTeam={'$t'}"
        $nr = (SumP 'NetSales' '2026-01-01' '2026-09-30' $e) - (SumP 'CreditAmount' '2026-01-01' '2026-09-30' $e)
        $bu = SumP 'BudgetNetSales' '2026-01-01' '2026-09-30' $e
        $ach += [pscustomobject]@{ T = $t; A = $nr / $bu }
    }
    $achTxt = ($ach | Sort-Object A | ForEach-Object { "$($_.T) $($_.A.ToString('0.0%', $QaInv))" }) -join '; '
    $low = @($ach | Where-Object { $_.A -ge 0.84 -and $_.A -le 0.92 }); $rest = @($ach | Where-Object { $_.A -gt 0.92 })
    $restOk = @($rest | Where-Object { $_.A -ge 0.98 -and $_.A -le 1.06 }).Count; $restSoft = @($rest | Where-Object { $_.A -ge 0.96 -and $_.A -le 1.08 }).Count
    $st3 = if ($low.Count -eq 1 -and $rest.Count -eq ($teams.Count - 1) -and $restOk -eq $rest.Count) { 'PASS' } elseif ($low.Count -eq 1 -and $restSoft -eq $rest.Count) { 'WARN' } else { 'FAIL' }
    Add-QaResult 'S3' 'One team ~12% below budget 2026 CYTD, others 98-106%' '1 team 84-92%, 7 teams 98-106%' $achTxt $st3 'NetRevenue / Budget, Jan-Sep 2026'

    # S4 E-Commerce
    $ch = @()
    foreach ($c in @('Direct Sales','E-Commerce','Distributor','Retail Partner')) {
        $e = "Channel={'$c'}"
        $ch += [pscustomobject]@{ C = $c; Disc = (QN "Sum({1<$e>} Discount)") / (QN "Sum({1<$e>} GrossSales)"); GM = (QN "Sum({1<$e>} GrossMargin)") / (QN "Sum({1<$e>} NetSales)")
                                  Y25 = (SumP 'NetSales' '2025-01-01' '2025-12-31' $e) / (SumP 'NetSales' '2024-01-01' '2024-12-31' $e) - 1
                                  YTD = (SumP 'NetSales' '2026-01-01' '2026-09-30' $e) / (SumP 'NetSales' '2025-01-01' '2025-09-30' $e) - 1 }
    }
    $chTxt = ($ch | ForEach-Object { "$($_.C): disc $($_.Disc.ToString('0.0%', $QaInv)), GM $($_.GM.ToString('0.0%', $QaInv)), YoY $($_.Y25.ToString('0.0%', $QaInv))/$($_.YTD.ToString('0.0%', $QaInv))" }) -join '; '
    Test-QaEq 'S4' 'E-Commerce has the highest discount rate' 'E-Commerce' ($ch | Sort-Object Disc -Descending | Select-Object -First 1).C -Note $chTxt
    Test-QaEq 'S4' 'E-Commerce has the lowest GM%' 'E-Commerce' ($ch | Sort-Object GM | Select-Object -First 1).C
    Test-QaEq 'S4' 'E-Commerce grows fastest 2025 vs 2024' 'E-Commerce' ($ch | Sort-Object Y25 -Descending | Select-Object -First 1).C
    Test-QaEq 'S4' 'E-Commerce grows fastest CYTD vs PYTD' 'E-Commerce' ($ch | Sort-Object YTD -Descending | Select-Object -First 1).C
}

} catch { Add-QaErr 'stories' $_ }
try { # section deep
# ================================================================= Deep: row-level joins
if ($Deep) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    # link table integrity: Aggr per %LinkKey, chunked by key range (%LinkKey is an AutoNumber 1..n) to keep memory low
    $maxKey = [int](QN "Max({1} %LinkKey)"); $kc = 200000
    $lchk = [ordered]@{
        'D-25|Every %LinkKey has exactly 1 LinkTable row (0 = fact key missing, >1 = duplicated link row)' = 'If(Count(LinkSource) <> 1, 1, 0)'
        'D-24|No orphan link rows (key used by >= 1 fact row)' = 'If(Count(InvoiceLineID) + Count(CreditNoteLineID) + Count(BudgetID) = 0, 1, 0)'
        'D-23|LinkSource tag matches the facts that use the key' = "If((Count(InvoiceLineID) > 0) <> (Index(Only(LinkSource), 'Invoice') > 0) or (Count(CreditNoteLineID) > 0) <> (Index(Only(LinkSource), 'CreditNote') > 0) or (Count(BudgetID) > 0) <> (Index(Only(LinkSource), 'Budget') > 0), 1, 0)"
        'D-25|Each %LinkKey maps to one date/customer/product/rep/channel' = 'If(Count(DISTINCT Date) > 1 or Count(DISTINCT CustomerName) > 1 or Count(DISTINCT ProductName) > 1 or Count(DISTINCT SalesRepName) > 1 or Count(DISTINCT Channel) > 1, 1, 0)'
    }
    foreach ($k in $lchk.Keys) {
        $tot = 0.0; $firstBad = ''
        for ($a = 1; $a -le $maxKey; $a += $kc) {
            $b = [math]::Min($a + $kc - 1, $maxKey); $set = "{1<%LinkKey={"">=$a<=$b""}>}"
            $v = QN "Sum($set Aggr($set $($lchk[$k]), %LinkKey))"; $tot += [double]$v
            if ($v -gt 0 -and -not $firstBad) { $firstBad = "first in key range $a..$b" }
        }
        $kk = $k.Split('|'); Test-QaEq $kk[0] $kk[1] 0.0 $tot -Note $firstBad
    }
    Add-QaResult 'D-25' 'Info: link Aggr checks duration' '-' ("{0:n1} s" -f $sw.Elapsed.TotalSeconds) 'INFO'

    # ---- CN dump
    $sw.Restart()
    $cn = New-Object 'System.Collections.Generic.List[object]'
    $nCN = [int]$rows['CreditNotes']
    for ($a = 1; $a -le $nCN; $a += $Chunk) {
        $b = [math]::Min($a + $Chunk - 1, $nCN); $set = "{1<CreditNoteLineID={"">=$a<=$b""}>}"
        $txt = QT ("Concat($set Aggr($set Num(CreditNoteLineID, '0', '.', '') & ';' & Only(CreditNoteNo) & ';' & Num(Only(CreditNoteDate), '0.######', '.', '') & ';' & Only(CN_OrigInvoiceNo)" +
                   " & ';' & Num(Only(CN_OrigInvoiceLineID), '0', '.', '') & ';' & Num(Sum(CreditQty), '0.####', '.', '') & ';' & Num(Sum(CreditAmount), '0.####', '.', '') & ';' & Num(Sum(CreditCost), '0.####', '.', '')" +
                   " & ';' & Num(Only(%DateKey), '0.######', '.', '') & ';' & Only(CustomerID) & ';' & Only(ProductID) & ';' & Only(SalesRepID) & ';' & Only(ChannelID) & ';' & Only(ReturnReasonID), CreditNoteLineID), '|')")
        if ($txt -match '^\s*Error') { throw "CN dump failed: $txt" }
        foreach ($r in $txt.Split('|')) { if ($r) { $cn.Add($r.Split(';')) } }
    }
    Test-QaEq 'D-40' 'CN rows dumped' $nCN $cn.Count
    $need = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($c in $cn) { [void]$need.Add($c[4]) }
    # ---- invoice dump (all lines: date = link date check; keep only referenced lines)
    $inv = New-Object 'System.Collections.Generic.Dictionary[string,string[]]'
    $nINV = [int]$rows['Invoices']; $invDateBad = 0; $invDateSample = ''; $invSeen = 0; $invAmbig = 0
    for ($a = 1; $a -le $nINV; $a += $Chunk) {
        $b = [math]::Min($a + $Chunk - 1, $nINV); $set = "{1<InvoiceLineID={"">=$a<=$b""}>}"
        $txt = QT ("Concat($set Aggr($set Num(InvoiceLineID, '0', '.', '') & ';' & Only(InvoiceNo) & ';' & Num(Only(InvoiceDate), '0.######', '.', '') & ';' & Num(Sum(Quantity), '0.####', '.', '')" +
                   " & ';' & Num(Sum(NetSales), '0.####', '.', '') & ';' & Num(Sum(CostOfSales), '0.####', '.', '') & ';' & Num(Only(%DateKey), '0.######', '.', '') & ';' & Only(CustomerID) & ';' & Only(ProductID)" +
                   " & ';' & Only(SalesRepID) & ';' & Only(ChannelID), InvoiceLineID), '|')")
        if ($txt -match '^\s*Error') { throw "Invoice dump failed: $txt" }
        foreach ($r in $txt.Split('|')) {
            if (-not $r) { continue }
            $c = $r.Split(';'); $invSeen++
            if ($c[6] -eq '' -or $c[7] -eq '' -or $c[8] -eq '') { $invAmbig++ }
            if ($c[2] -ne $c[6]) { $invDateBad++; if (-not $invDateSample) { $invDateSample = $r } }
            if ($need.Contains($c[0])) { $inv[$c[0]] = $c }
        }
    }
    Test-QaEq 'D-51' 'Invoice rows dumped' $nINV $invSeen
    Test-QaEq 'D-51' 'Invoice lines with a unique link date/customer/product' 0 $invAmbig
    Test-QaEq 'D-51' 'InvoiceDate = link %DateKey for all invoice lines' 0 $invDateBad -Note $invDateSample
    # ---- CN rule evaluation
    $v = [ordered]@{ Resolve = 0; InvNo = 0; Cust = 0; Prod = 0; Rep = 0; Chan = 0; DateGE = 0; DateLE = 0; DateLink = 0; Qty = 0; Amt = 0; Cost = 0; CumQty = 0; CumAmt = 0 }
    $smp = @{}
    $cumQ = @{}; $cumA = @{}
    $inv_ = [System.Globalization.NumberStyles]::Float
    foreach ($c in $cn) {
        # c: 0 id,1 no,2 date,3 origNo,4 origLine,5 qty,6 amt,7 cost,8 datekey,9 cust,10 prod,11 rep,12 chan,13 reason
        $i = $null
        if (-not $inv.TryGetValue($c[4], [ref]$i)) { $v.Resolve++; if (-not $smp.Resolve) { $smp.Resolve = ($c -join ';') }; continue }
        # i: 0 id,1 no,2 date,3 qty,4 net,5 cost,6 datekey,7 cust,8 prod,9 rep,10 chan
        $chk = [ordered]@{
            InvNo = ($c[3] -ceq $i[1]); Cust = ($c[9] -eq $i[7]); Prod = ($c[10] -eq $i[8]); Rep = ($c[11] -eq $i[9]); Chan = ($c[12] -eq $i[10])
            DateGE = ([double]::Parse($c[2], $QaInv) -ge [double]::Parse($i[2], $QaInv)); DateLE = ([double]::Parse($c[2], $QaInv) -le $D_END); DateLink = ($c[2] -eq $c[8])
            Qty = ([double]::Parse($c[5], $QaInv) -le [double]::Parse($i[3], $QaInv)); Amt = ([double]::Parse($c[6], $QaInv) -le [double]::Parse($i[4], $QaInv) + 0.005)
            Cost = ([double]::Parse($c[7], $QaInv) -ge 0 -and [double]::Parse($c[7], $QaInv) -le [double]::Parse($i[5], $QaInv) + 0.005)
        }
        foreach ($k in $chk.Keys) { if (-not $chk[$k]) { $v[$k]++; if (-not $smp[$k]) { $smp[$k] = 'CN ' + ($c -join ';') + ' / INV ' + ($i -join ';') } } }
        $cumQ[$c[4]] = [double]$cumQ[$c[4]] + [double]::Parse($c[5], $QaInv); $cumA[$c[4]] = [double]$cumA[$c[4]] + [double]::Parse($c[6], $QaInv)
    }
    foreach ($k in $cumQ.Keys) {
        $i = $inv[$k]
        if ($cumQ[$k] -gt [double]::Parse($i[3], $QaInv)) { $v.CumQty++; if (-not $smp.CumQty) { $smp.CumQty = "line $k credited qty $($cumQ[$k]) > $($i[3])" } }
        if ($cumA[$k] -gt [double]::Parse($i[4], $QaInv) + 0.01) { $v.CumAmt++; if (-not $smp.CumAmt) { $smp.CumAmt = "line $k credited $($cumA[$k]) > $($i[4])" } }
    }
    $lbl = [ordered]@{ Resolve = @('D-40', 'CN_OrigInvoiceLineID resolves to an invoice line'); InvNo = @('D-40', 'CN_OrigInvoiceNo = InvoiceNo of the referenced line')
        Cust = @('D-41', 'CN customer = original customer'); Prod = @('D-41', 'CN product = original product'); Rep = @('D-41', 'CN sales rep = original rep'); Chan = @('D-41', 'CN channel = original channel')
        DateGE = @('D-42', 'CreditNoteDate >= original InvoiceDate'); DateLE = @('D-42', 'CreditNoteDate <= 2026-09-30'); DateLink = @('D-42', 'CN %DateKey = CreditNoteDate')
        Qty = @('D-43', 'CreditQty <= original Quantity'); Amt = @('D-44', 'CreditAmount <= original NetSales'); Cost = @('D-45', '0 <= CreditCost <= original CostOfSales')
        CumQty = @('D-43', 'Sum of CreditQty per invoice line <= Quantity (cumulative)'); CumAmt = @('D-44', 'Sum of CreditAmount per invoice line <= NetSales (cumulative)') }
    foreach ($k in $lbl.Keys) {
        $soft = $k -in 'CumQty','CumAmt'
        Test-QaEq $lbl[$k][0] $lbl[$k][1] 0 $v[$k] -Soft:$soft -Note $(if ($smp[$k]) { 'e.g. ' + $smp[$k] } else { '' })
    }
    $multiCN = @($cumQ.Keys | Where-Object { $true }).Count
    Add-QaResult 'D-43' 'Info: distinct invoice lines credited' '-' "$multiCN lines for $($cn.Count) CN lines" 'INFO'
    Add-QaResult 'D-40' 'Info: deep join duration' '-' ("{0:n1} s" -f $sw.Elapsed.TotalSeconds) 'INFO'
}

} catch { Add-QaErr 'deep' $_ }
# ================================================================= snapshot
if ($Snapshot) {
    $snap = Get-QaSnapshot
    $f = Save-QaSnapshot $snap $Snapshot
    Add-QaResult 'P-01' 'Determinism snapshot saved' '-' $f 'INFO'
}

$appendix.Add(''); $appendix.Add("Total run time: {0:n1} s" -f $swAll.Elapsed.TotalSeconds)
Write-QaReport -Name $(if ($Deep) { 'data-deep' } else { 'data' }) -Title "QA data checks$(if ($Deep) { ' (deep)' })" -Appendix $appendix | Out-Null
