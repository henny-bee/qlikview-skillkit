# Creates cyclic / drill-down groups from a JSON file (idempotent: same-name groups are recreated).
#   [ {"Name":"drl_Geo","Cyclic":false,"Fields":["Region","Country","City"],"Labels":["Region","Country","City"]}, ... ]
#   qvrun.sh create-groups.ps1 -Json _build\spec\groups.json
param([Parameter(Mandatory)][string]$Json, [string]$Owner = 'engineer')
. "$PSScriptRoot\qvcom.ps1"
$groups = Get-Content $Json -Raw -Encoding UTF8 | ConvertFrom-Json
Enter-QvLock -Owner $Owner
try {
    $doc = Get-QvDoc
    $existing = @($doc.GetGroups()) | ForEach-Object { $_.GetProperties().Name }
    foreach ($g in $groups) {
        if ($existing -contains $g.Name) { $doc.RemoveGroup($g.Name) }
        $grp = $doc.CreateGroup($g.Name)
        foreach ($f in $g.Fields) { $grp.AddField($f) }
        $p = $grp.GetProperties(); $p.IsCyclic = [bool]$g.Cyclic
        if ($g.Labels) { try { $p.Labels = [object[]]$g.Labels } catch { Write-Warning "labels not set for $($g.Name)" } }
        $grp.SetProperties($p)
    }
} finally { Exit-QvLock -Owner $Owner }
foreach ($grp in @($doc.GetGroups())) {
    $p = $grp.GetProperties(); $f = @(); for ($i = 0; $i -lt $p.FieldDefs.Count; $i++) { $f += $p.FieldDefs.Item($i).Name }
    "{0,-16} cyclic={1,-5} {2}" -f $p.Name, $p.IsCyclic, ($f -join ' > ')
}
