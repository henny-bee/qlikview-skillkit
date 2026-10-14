# Windows-native version of qv-init.sh: bootstraps <project>\_build and copies the toolkit into _build\tools.
#   powershell -ExecutionPolicy Bypass -File qv-init.ps1 -Project C:\Projects\SalesApp [-Document SalesApp.qvw]
param([Parameter(Mandatory)][string]$Project, [string]$Document)
$ErrorActionPreference = 'Stop'
$proj = (Resolve-Path $Project).Path
$b = Join-Path $proj '_build'
foreach ($d in 'tools','script','spec','build','backup','logs','shots','status','qa') { New-Item -ItemType Directory -Force -Path (Join-Path $b $d) | Out-Null }
Copy-Item -Force (Join-Path $PSScriptRoot 'toolkit\*') (Join-Path $b 'tools')
# starter templates (never overwrite your own files)
foreach ($t in @(@('app-settings.ps1','build'), @('build-SH_TEMPLATE.ps1','build'), @('build-SH_INSIGHTS.ps1','build'), @('metrics.tsv','spec'), @('groups.json','spec'))) {
    $dst = Join-Path (Join-Path $b $t[1]) $t[0]
    if (-not (Test-Path $dst)) { Copy-Item (Join-Path $PSScriptRoot "templates\$($t[0])") $dst }
}
if ($Document) { Set-Content -Path (Join-Path $b 'qv.config') -Value (Join-Path $proj $Document) }
$gi = Join-Path $b '.gitignore'
if (-not (Test-Path $gi)) { Set-Content -Path $gi -Value ".locks/`nbackup/`nlogs/`nshots/`nfinal-shots/`n*.qvw`n*.qvw.log" }
"QlikView workspace ready: $b"
