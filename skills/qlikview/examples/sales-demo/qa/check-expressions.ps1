# QA expression/variable checks for QLIK-CL (owner: QA).
# Compares every contract variable with an INDEPENDENT formula written from the contract, with no selections and under
# selection scenarios. Holds the COM lock while it selects; always ClearAll + restore the sheet + release.
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File <win path>\check-expressions.ps1 [-Quick] [-NoBookmarks]
param([switch]$Quick, [switch]$NoBookmarks)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-common.ps1"
$doc = Connect-QaDoc
$appendix = New-Object System.Collections.Generic.List[string]
$swAll = [Diagnostics.Stopwatch]::StartNew()

# ---------------------------------------------------------------- contract
$Base = @('NetSales','GrossSales','Discount','COGS','GrossMargin','GrossMarginPct','CreditAmount','CreditCost','CreditQty','Quantity','NetRevenue',
          'NetMargin','NetMarginPct','CreditRate','DiscountRate','Invoices','CreditNotes','ActiveCustomers','AvgInvoiceValue','Budget','BudgetAch','BudgetToDate')
$PerMeasures = @('NetSales','NetRevenue','CreditAmount','GrossMargin','NetMargin','NetMarginPct','CreditRate','DiscountRate','Invoices','AvgInvoiceValue','ActiveCustomers','Budget','BudgetAch')
$Periods = [ordered]@{ CYTD = @('2026-01-01','2026-09-30'); PYTD = @('2025-01-01','2025-09-30'); R12 = @('2025-10-01','2026-09-30'); PR12 = @('2024-10-01','2025-09-30')
                       CM = @('2026-09-01','2026-09-30'); PM = @('2026-08-01','2026-08-31'); PYM = @('2025-09-01','2025-09-30') }
$YoY = @('NetSales','NetRevenue','GrossMargin','NetMargin','Invoices'); $YoYpp = @('NetMarginPct','CreditRate','DiscountRate')
$CalClear = 'Year=,Quarter=,Month=,YearQuarter=,YearMonth=,Week=,Weekday=,Day=,Date=,Flag_CYTD=,Flag_PYTD=,Flag_R12=,Flag_PR12=,Flag_CM=,Flag_PM=,Flag_PYM='

function PSet([string]$p) { if (-not $p) { return '' }; return '{<' + $CalClear + ',' + (DRange $Periods[$p][0] $Periods[$p][1]) + '>}' }
# Independent formula for measure m in period p ('' = base measure, respects all selections)
# $dim: chart dimension context (E-12). Nested Aggr must include the chart dimension, otherwise a customer that belongs to several
# rows is allocated to only one row (classic QlikView nested-Aggr gotcha -> false positives on 14/10).
function Indep([string]$m, [string]$p, [string]$dim = '') {
    $s = PSet $p; $ad = if ($dim) { "[$dim], " } else { '' }
    $ns = "Sum($s NetSales)"; $ca = "Sum($s CreditAmount)"; $cc = "Sum($s CreditCost)"; $gm = "Sum($s GrossMargin)"
    switch ($m) {
        'NetSales'        { return $ns }
        'GrossSales'      { return "Sum($s GrossSales)" }
        'Discount'        { return "Sum($s Discount)" }
        'COGS'            { return "Sum($s CostOfSales)" }
        'GrossMargin'     { return $gm }
        'GrossMarginPct'  { return "($gm / $ns)" }
        'CreditAmount'    { return $ca }
        'CreditCost'      { return $cc }
        'CreditQty'       { return "Sum($s CreditQty)" }
        'Quantity'        { return "Sum($s Quantity)" }
        'NetRevenue'      { return "($ns - $ca)" }
        'NetMargin'       { return "($gm - $ca + $cc)" }
        'NetMarginPct'    { return "(($gm - $ca + $cc) / ($ns - $ca))" }
        'CreditRate'      { return "($ca / $ns)" }
        'DiscountRate'    { return "(Sum($s Discount) / Sum($s GrossSales))" }
        'Invoices'        { return "Count($s DISTINCT InvoiceNo)" }
        'CreditNotes'     { return "Count($s DISTINCT CreditNoteNo)" }
        'ActiveCustomers' { return "Sum($s Aggr($s If(Count($s InvoiceLineID) > 0, 1, 0), ${ad}CustomerID))" }
        'AvgInvoiceValue' { return "($ns / Count($s DISTINCT InvoiceNo))" }
        'Budget'          { return "Sum($s BudgetNetSales)" }
        # Q-001 lead decision 14/10: vBudget = full budget; vBudgetToDate = budget up to the data end date; base vBudgetAch = NetRevenue / budget to date.
        # Period variants: every period ends on/before the data end date, so their budget is already "to date".
        'BudgetToDate'    { return "Sum({<%DateKey={`"<=$(DNum '2026-09-30')`"}>} BudgetNetSales)" }
        'BudgetAch'       { if ($p) { return "(($ns - $ca) / Sum($s BudgetNetSales))" } else { return "(($ns - $ca) / Sum({<%DateKey={`"<=$(DNum '2026-09-30')`"}>} BudgetNetSales))" } }
    }
    throw "no independent formula for $m"
}
function VarRaw([string]$n) { try { $v = $doc.Variables($n); if ($v) { return [string]$v.GetRawContent() } } catch {}; return $null }
function VarEval([string]$n) { QE ('$(' + $n + ')') }

# expected variable list
$exp = [ordered]@{}
foreach ($m in $Base) { $exp["v$m"] = @{ Kind = 'base'; M = $m; P = '' } }
foreach ($p in $Periods.Keys) { $exp["vSet$p"] = @{ Kind = 'set'; P = $p } }
foreach ($m in $PerMeasures) { foreach ($p in $Periods.Keys) { $exp["v${m}_$p"] = @{ Kind = 'period'; M = $m; P = $p } } }
foreach ($m in $YoY) { $exp["v${m}_YoY"] = @{ Kind = 'yoy'; M = $m } }
foreach ($m in $YoYpp) { $exp["v${m}_YoYpp"] = @{ Kind = 'yoypp'; M = $m } }
$uiVars = [ordered]@{ vTopN = '10'; vShowHelp = '1'; vDataEndDate = '30/09/2026'; vDataEndDateNum = [string](DNum '2026-09-30'); vFmtMoney = "$QaEuro #,##0"; vFmtPct = '0.0%'
                      vCfgInvoiceLines = '900000'; vCfgCreditNoteLines = '100000' }

# ================================================================= E-01 / E-02 existence and SET style
# Read the variable list robustly (Invoke-QvRetry: QV may be busy); never swallow errors silently. A per-name lookup
# ($doc.Variables(name)) is the independent second source, so a broken list read can never report "0 found" again.
$docVars = New-Object System.Collections.Generic.List[string]; $listErr = $null
try {
    $vdl = Invoke-QvRetry { $doc.GetVariableDescriptions() }
    for ($i = 0; $i -lt $vdl.Count; $i++) { $d = $vdl.Item($i); if (-not $d.IsReserved -and -not $d.IsConfig) { $docVars.Add([string]$d.Name) } }
} catch { $listErr = $_.Exception.Message }
$docVars = @($docVars)
if ($listErr -or $docVars.Count -eq 0) { Add-QaResult 'E-01' 'Read variable list (GetVariableDescriptions)' '> 0 user variables' $(if ($listErr) { $listErr } else { 0 }) 'WARN' 'checker fallback: per-name lookup only' }
function VarExists([string]$n) { if ($docVars -ccontains $n) { return $true }; try { $v = Invoke-QvRetry { $doc.Variables($n) }; return [bool]($v -and $null -ne $v.GetRawContent()) } catch { return $false } }
$allExp = @(@($exp.Keys) + @($uiVars.Keys))
$missing = @($allExp | Where-Object { -not (VarExists $_) })
Test-Qa 'E-01' 'All contract variables exist (exact case)' "$($allExp.Count) variables" "$($allExp.Count - $missing.Count) found" ($missing.Count -eq 0) -Note $(if ($missing) { 'missing: ' + ($missing -join ', ') } else { '' })
$extra = @($docVars | Where-Object { -not $exp.Contains($_) -and -not $uiVars.Contains($_) })
Add-QaResult 'E-01' 'Info: document user variables (non-reserved, non-config)' '-' $docVars.Count 'INFO' ("$($extra.Count) beyond contract: " + ($extra -join ', '))
$eq = @($exp.Keys | Where-Object { $r = VarRaw $_; $r -and $r.TrimStart().StartsWith('=') })
Test-Qa 'E-02' 'Measure/set variables are SET-style (no leading =)' 'none with =' "$($eq.Count)" ($eq.Count -eq 0) -Note ($eq -join ', ')
$raws = [ordered]@{}; foreach ($k in $exp.Keys) { $raws[$k] = VarRaw $k }

# ================================================================= E-08 UI / format variables
foreach ($k in $uiVars.Keys) {
    $raw = VarRaw $k; $val = if ($null -ne $raw) { (QE "'$('$(' + $k + ')')'").Text } else { $null }
    $ok = ($null -ne $raw) -and ($raw -ceq $uiVars[$k] -or $val -ceq $uiVars[$k] -or $raw -ceq ("'" + $uiVars[$k] + "'"))
    if (-not $ok -and $null -ne $raw -and $k -eq 'vDataEndDateNum') { $n = (QE '$(vDataEndDateNum)').Num; $ok = ($n -eq [double]$uiVars[$k]) }
    if (-not $ok -and $null -ne $raw -and $k -eq 'vDataEndDate') { $ok = ((QE '$(vDataEndDate)').Text -ceq $uiVars[$k]) -or ((QE 'Date($(vDataEndDate))').Text -ceq $uiVars[$k]) }
    Test-Qa 'E-08' "$k value" $uiVars[$k] "raw=[$raw] expanded=[$val]" $ok
}

# ================================================================= E-09 groups
$expGroups = [ordered]@{
    drl_Geography = @($false, 'CustomerRegion','CustomerCountry','CustomerCity','CustomerName'); drl_Product = @($false, 'ProductCategory','ProductGroup','ProductName')
    drl_Time = @($false, 'Year','YearQuarter','YearMonth','Date'); drl_Sales = @($false, 'SalesTeam','SalesRepName')
    cyc_Dimension = @($true, 'CustomerRegion','ProductCategory','Channel','SalesTeam','CustomerSegment','Brand'); cyc_Time = @($true, 'Year','YearQuarter','YearMonth','Week','Weekday')
    cyc_Returns = @($true, 'ReturnReason','ReturnReasonGroup','ProductCategory'); cyc_Customer = @($true, 'CustomerName','CustomerCountry','CustomerSegment') }
$docGroups = @{}
# Read groups with explicit Count/Item loops (COM IArrayOf* collections) and retry; FieldDefs is read per group, errors are reported.
try {
    $gl = Invoke-QvRetry { $doc.GetGroups() }
    for ($gi = 0; $gi -lt $gl.Count; $gi++) {
        $gp = Invoke-QvRetry { $gl.Item($gi).GetProperties() }; $fields = @(); $ferr = ''
        try { $fdl = $gp.FieldDefs; for ($fi = 0; $fi -lt $fdl.Count; $fi++) { $fields += [string]$fdl.Item($fi).Name } } catch { $ferr = $_.Exception.Message }
        $docGroups[[string]$gp.Name] = @{ Cyclic = [bool]$gp.IsCyclic; Fields = $fields; Err = $ferr }
    }
} catch { Add-QaResult 'E-09' 'Read groups via COM' 'ok' $_.Exception.Message 'WARN' 'checker error' }
foreach ($k in $expGroups.Keys) {
    $e = $expGroups[$k]; $ef = @($e[1..($e.Count - 1)])
    if (-not $docGroups.ContainsKey($k)) { Add-QaResult 'E-09' "Group $k" ("{0}: {1}" -f $(if ($e[0]) { 'cyclic' } else { 'drill' }), ($ef -join ' > ')) 'missing' 'FAIL'; continue }
    $a = $docGroups[$k]
    Test-Qa 'E-09' "Group $k" ("{0}: {1}" -f $(if ($e[0]) { 'cyclic' } else { 'drill' }), ($ef -join ' > ')) ("{0}: {1}" -f $(if ($a.Cyclic) { 'cyclic' } else { 'drill' }), ($a.Fields -join ' > ')) (($a.Cyclic -eq $e[0]) -and (($a.Fields -join '>') -ceq ($ef -join '>'))) -Note $(if ($a.Err) { "FieldDefs read error: $($a.Err)" } else { '' })
}

# ================================================================= E-11 spec/variables.md covers the document
$vmd = Join-Path $QvBuildRoot 'spec\variables.md'
if (Test-Path $vmd) {
    $txt = Get-Content -Raw -Encoding UTF8 $vmd
    $listed = @([regex]::Matches($txt, '\bv[A-Z][A-Za-z0-9_]*') | ForEach-Object Value | Sort-Object -Unique)
    $notListed = @($docVars | Where-Object { $_ -like 'v*' -and $listed -cnotcontains $_ })
    Test-Qa 'E-11' 'spec/variables.md lists every document variable' 'all' "$($notListed.Count) not listed" ($notListed.Count -eq 0) -Soft -Note ($notListed -join ', ')
} else { Add-QaResult 'E-11' 'spec/variables.md exists' 'present' 'missing' 'WARN' }

# ================================================================= scenarios (under lock)
$teamA = QT 'MinString({1} SalesTeam)'; $cust1 = QT 'MinString({1} CustomerName)'; $prod1 = QT 'MinString({1} ProductName)'
$Scen = @(
    @{ Name = 'S0 no selections';                  Sel = @();                                                                 Cal = $false }
    @{ Name = 'S1 Year=2025';                      Sel = @(,@('Year', '2025'));                                               Cal = $true }
    @{ Name = 'S2 Quarter=Q1 + Month=Mar';         Sel = @(@('Quarter', 'Q1'), @('Month', 'Mar'));                            Cal = $true }
    @{ Name = 'S3 Date 01/02/2025..15/02/2025';    Sel = @(,@('Date', '>=01/02/2025<=15/02/2025'));                           Cal = $true }
    @{ Name = 'S4 Week=10 + Weekday=Mon';          Sel = @(@('Week', '10'), @('Weekday', 'Mon'));                             Cal = $true }
    @{ Name = 'S5 YearMonth=*2024 (all of 2024)';  Sel = @(,@('YearMonth', '*2024'));                                         Cal = $true }
    @{ Name = 'S6 CustomerRegion=CEE';             Sel = @(,@('CustomerRegion', 'CEE'));                                      Cal = $false }
    @{ Name = 'S7 Networking + E-Commerce';        Sel = @(@('ProductCategory', 'Networking'), @('Channel', 'E-Commerce'));   Cal = $false }
    @{ Name = "S8 SalesTeam=$teamA";               Sel = @(,@('SalesTeam', $teamA));                                          Cal = $false }
    @{ Name = "S9 CustomerName=$cust1";            Sel = @(,@('CustomerName', $cust1));                                       Cal = $false; NoBudget = $true }
    @{ Name = "S10 ProductName=$prod1";            Sel = @(,@('ProductName', $prod1));                                        Cal = $false; NoBudget = $true }
    @{ Name = 'S11 Year=2025 + CustomerRegion=CEE'; Sel = @(@('Year', '2025'), @('CustomerRegion', 'CEE'));                   Cal = $false }
)
if ($Quick) { $Scen = @($Scen[0], $Scen[1], $Scen[6], $Scen[9]) }
$s0 = @{}; $matrix = [ordered]@{}; foreach ($k in $exp.Keys) { $matrix[$k] = @() }
$scenSummary = @()

# Lock is held PER SCENARIO / per batch (short holds: 3 builders share it). Exit-QaLock always ClearAll's first.
$prevSheet = $null; try { $prevSheet = $doc.ActiveSheet().GetProperties().SheetId } catch {}
    foreach ($sc in $Scen) {
      Enter-QaLock
      try {
        Invoke-QvRetry { $doc.ClearAll($true) } | Out-Null
        $selOk = $true; $selInfo = @()
        foreach ($sel in $sc.Sel) {
            $fld = $doc.Fields($sel[0])
            if (-not $fld) { $selOk = $false; $selInfo += "$($sel[0]): field missing"; continue }
            [void](Invoke-QvRetry { $fld.Select($sel[1]) })
            $n = 0; try { $n = $fld.GetSelectedValues().Count } catch {}
            if ($n -lt 1) { $selOk = $false }
            $selInfo += "$($sel[0])=$($sel[1]) ($n values)"
        }
        $cur = (QE 'GetCurrentSelections()').Text
        if (-not $selOk) { Add-QaResult 'E-05' "$($sc.Name): selection applied" 'selected' ($selInfo -join '; ') 'WARN' 'scenario skipped'; continue }
        $pass = 0; $fail = 0; $warn = 0; $cache = @{}
        foreach ($k in $exp.Keys) {
            $e = $exp[$k]; $got = $null; $want = $null; $note = ''; $ev = $null
            switch ($e.Kind) {
                'set' {
                    $ev = QE ('Sum($(' + $k + ') NetSales)'); $got = $ev.Num
                    $want = QN ("Sum($(PSet $e.P) NetSales)")
                }
                'base' { $ev = VarEval $k; $got = $ev.Num; $want = QN (Indep $e.M '') }
                'period' { $ev = VarEval $k; $got = $ev.Num; $want = QN (Indep $e.M $e.P) }
                'yoy' {
                    $ev = VarEval $k; $got = $ev.Num; $cy = QN (Indep $e.M 'CYTD'); $py = QN (Indep $e.M 'PYTD')
                    $want = if ($py) { $cy / $py - 1 } else { $null }
                    if ($null -ne $got -and $null -ne $want -and -not (Test-Close $got $want) -and (Test-Close $got ($want * 100))) { $note = 'value is x100 (percent units)' }
                }
                'yoypp' {
                    $ev = VarEval $k; $got = $ev.Num; $cy = QN (Indep $e.M 'CYTD'); $py = QN (Indep $e.M 'PYTD')
                    # spec/variables.md: v<Measure>_YoYpp = (CYTD - PYTD) x 100 (percentage points)
                    $want = if ($null -ne $cy -and $null -ne $py) { ($cy - $py) * 100 } else { $null }
                    if ($null -ne $got -and $null -ne $want -and -not (Test-Close $got $want) -and (Test-Close $got ($want / 100))) { $note = 'value is /100 (ratio, not pp as per spec)' }
                }
            }
            $isErr = [bool]($ev -and $ev.IsErr)
            $ok = (-not $isErr) -and (Test-Close $got $want 1e-6 1e-9)
            if ($sc.Name -like 'S0*') { $s0[$k] = $got }
            if ($sc.Cal -and $e.Kind -in 'period','set','yoy','yoypp' -and $s0.ContainsKey($k) -and -not (Test-Close $got $s0[$k] 1e-9 1e-9)) {
                $ok = $false; $note = (($note, "changed by calendar selection (S0=$(Format-QaVal $s0[$k]))") | Where-Object { $_ }) -join '; '
            }
            if ($sc.NoBudget -and $e.M -in 'Budget','BudgetAch','BudgetToDate') {
                $bOk = if ($e.M -in 'Budget','BudgetToDate') { $null -eq $got -or $got -eq 0 } else { $null -eq $got }
                if (-not $bOk) { $ok = $false; $note = (($note, 'budget must be excluded for customer/product selections') | Where-Object { $_ }) -join '; ' }
            }
            if ($ok) { $pass++; $matrix[$k] += 'P' }
            else {
                if ($note -match 'x100|/100' -and $note -notmatch 'calendar|budget') { $warn++ } else { $fail++ }
                $matrix[$k] += $(if ($note -match 'x100|/100') { 'W' } else { 'F' })
                $st = if ($note -match 'x100|/100') { 'WARN' } else { 'FAIL' }
                $id = if ($isErr) { 'E-03' } elseif ($note -match 'calendar') { 'E-05' } elseif ($note -match 'budget') { 'E-07' } elseif ($sc.Name -like 'S0*') { 'E-04' } else { 'E-06' }
                Add-QaResult $id "$($sc.Name): $k" $want $(if ($isErr) { $ev.Text } else { $got }) $st (($note, "raw: $($raws[$k])") | Where-Object { $_ }) -join ' | '
            }
        }
        $scenSummary += "$($sc.Name): $pass pass / $warn warn / $fail fail  [$cur]"
        Add-QaResult $(if ($sc.Name -like 'S0*') { 'E-04' } elseif ($sc.Cal) { 'E-05' } else { 'E-06' }) "$($sc.Name): all variables = independent formula" "$($exp.Count) match" "$pass match, $warn scale-warn, $fail differ" $(if ($fail -gt 0) { 'FAIL' } elseif ($warn -gt 0) { 'WARN' } else { 'PASS' }) $cur
      } finally { Exit-QaLock }
    }
    # E-12 per chart dimension (emulates a chart: each variable vs independent formula per dimension value), no selections
    if (-not $Quick) {
        $dims = @('CustomerRegion', 'Channel', 'ProductCategory', 'SalesTeam', 'Year')
        $dimFail = @(); $dimRuns = 0; $batch = 0; $locked = $false
        try {
        foreach ($k in $exp.Keys) {
            $e = $exp[$k]; if ($e.Kind -notin 'base', 'period') { continue }
            if ($batch % 15 -eq 0) { if ($locked) { Exit-QaLock; $locked = $false }; Enter-QaLock; $locked = $true; Invoke-QvRetry { $doc.ClearAll($true) } | Out-Null }
            $batch++
            $a = '$(' + $k + ')'
            foreach ($d in $dims) {
                $b = Indep $e.M $e.P $d
                $cmp = "Sum(Aggr(If(Fabs(RangeSum($a) - RangeSum($b)) > 1e-6 * RangeMax(Fabs(RangeSum($a)), Fabs(RangeSum($b))) + 1e-9, 1, 0), [$d]))"
                $r = QE $cmp; $dimRuns++
                if ($r.IsErr -or $r.Num -ne 0) { $dimFail += "$k by $d -> $(if ($r.IsErr) { $r.Text } else { "$($r.Num) values differ" })" }
            }
        }
        } finally { if ($locked) { Exit-QaLock } }
        Test-Qa 'E-12' 'Variables = independent formula per chart dimension (Region, Channel, Category, Team, Year)' "$dimRuns checks" "$($dimFail.Count) differ" ($dimFail.Count -eq 0) -Note (($dimFail | Select-Object -First 25) -join '; ')
    }
    # E-10 bookmarks
    if (-not $NoBookmarks) {
        $bms = @(); try { $bn = $doc.GetDocBookmarkNames(); if ($bn -is [array]) { $bms = @($bn | Where-Object { $_ }) } elseif ($bn -and $bn.Count) { $bms = @(Get-QaComList $bn | ForEach-Object { [string]$_ }) } elseif ($bn) { $bms = @([string]$bn) } } catch {}
        if (-not $bms) { Add-QaResult 'E-10' 'Document bookmarks (demo stories)' '>= 4 (one per story)' 0 'INFO' 'none yet' }
        if ($bms.Count) { Enter-QaLock }
        try {
        foreach ($b in $bms) {
            Update-QvLock -Owner qa
            Invoke-QvRetry { $doc.ClearAll($true) } | Out-Null
            $ok = $true; $msg = ''
            try { [void]$doc.RecallDocBookmark([string]$b); $cs = (QE 'GetCurrentSelections()').Text; $ns = (VarEval 'vNetSales').Num; $msg = "selections: [$cs] vNetSales=$(Format-QaVal $ns)"; if (-not $cs -or $cs -eq '-') { $ok = $false } } catch { $ok = $false; $msg = $_.Exception.Message }
            Test-Qa 'E-10' "Bookmark '$b' recalls with selections" 'selections applied' $msg $ok -Soft
        }
        } finally { if ($bms.Count) { if ($prevSheet) { try { $doc.ActivateSheetById($prevSheet) | Out-Null } catch {} }; Exit-QaLock } }
        if ($bms.Count) { Test-Qa 'E-10' 'At least one bookmark per demo story' '>= 4' $bms.Count ($bms.Count -ge 4) -Soft -Note ($bms -join ', ') }
    }


# ================================================================= report
$appendix.Add(''); $appendix.Add('## Scenarios'); $appendix.Add('')
foreach ($s in $scenSummary) { $appendix.Add("* $s") }
$appendix.Add(''); $appendix.Add('## Variable x scenario matrix (P = matches independent formula, F = differs, W = scale warning)'); $appendix.Add('')
$appendix.Add('| Variable | ' + (($Scen | ForEach-Object { ($_.Name -split ' ')[0] }) -join ' | ') + ' | Raw definition |')
$appendix.Add('|---|' + (($Scen | ForEach-Object { '---' }) -join '|') + '|---|')
foreach ($k in $matrix.Keys) { $raw = ([string]$raws[$k]).Replace('|', '\|'); if ($raw.Length -gt 120) { $raw = $raw.Substring(0, 120) + '...' }; $appendix.Add("| $k | " + ($matrix[$k] -join ' | ') + " | ``$raw`` |") }
$appendix.Add(''); $appendix.Add("Total run time: {0:n1} s" -f $swAll.Elapsed.TotalSeconds)
Write-QaReport -Name 'expr' -Title 'QA expression and variable checks' -Appendix $appendix | Out-Null
