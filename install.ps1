# Installs the qlikview Agent Skill on Windows (user level) by copying (default) or junction-linking skills\qlikview.
#   powershell -ExecutionPolicy Bypass -File install.ps1                  both: %USERPROFILE%\.claude\skills and %USERPROFILE%\.agents\skills
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Agent claude    only Claude Code   (-Agent agents: only the shared .agents folder)
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Target D:\x\skills   any other tool's skills folder
#   add -Link to create a junction to this repo instead of a copy (updates when you git pull)
param([ValidateSet('all','claude','agents')][string]$Agent = 'all', [string[]]$Target, [switch]$Link)
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'skills\qlikview'
if (-not $Target) {
    $Target = switch ($Agent) {
        'claude' { @("$env:USERPROFILE\.claude\skills") }
        'agents' { @("$env:USERPROFILE\.agents\skills") }
        default  { @("$env:USERPROFILE\.claude\skills", "$env:USERPROFILE\.agents\skills") }
    }
}
foreach ($dir in $Target) {
    $dst = Join-Path $dir 'qlikview'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (Test-Path $dst) {
        $item = Get-Item $dst -Force
        if ($item.LinkType) { $item.Delete() } else { Remove-Item -Recurse -Force $dst }   # never delete through a junction
    }
    if ($Link) { New-Item -ItemType Junction -Path $dst -Target $src | Out-Null } else { Copy-Item -Recurse $src $dst }
    "Installed: $dst"
}
"Start a new session in your agent, then ask for any QlikView task."
