# Creates the demo-story document bookmarks. Idempotent: same-name bookmarks are replaced.
# Each bookmark holds the story selections and is created while the story's sheet is active with layout state,
# so recalling it also opens that sheet. Afterwards every bookmark is recalled from SH_HELP and checked. Ends with ClearAll.
. "$PSScriptRoot\..\tools\qvcom.ps1"
$stories = @(
  @{ Id='BM_STORY1';  Sheet='SH_CN';    Name='Story 1 – Networking quality issue';   Info='Credit rate Networking 2.8% (2024) → 9.0% (2026), driven by Quality defect returns. Sheet: Credit Notes.'; Sel=@(@{F='ProductCategory'; V=@('Networking')}) },
  @{ Id='BM_STORY2';  Sheet='SH_SALES'; Name='Story 2 – Seasonality and growth';      Info='Q4 peak, August dip; +8.5% (2025) / +4.8% (CYTD). CEE grows fastest, UK & Ireland is flat. Sheet: Sales Analysis.'; Sel=@(@{F='CustomerRegion'; V=@('CEE','UK & Ireland')}) },
  @{ Id='BM_STORY3';  Sheet='SH_TEAM';  Name='Story 3 – UK & Ireland below budget';   Info='Sales team UK & Ireland at 88% of the 2026 budget; other teams 99–105%. Sheet: Team & Budget.'; Sel=@(@{F='SalesTeam'; V=@('UK & Ireland')}, @{F='Year'; V=@('2026')}) },
  @{ Id='BM_STORY4';  Sheet='SH_SALES'; Name='Story 4 – E-Commerce discounts';        Info='E-Commerce: highest discount rate (14.8%), lowest gross margin (17.9%), fastest growth. Sheet: Sales Analysis.'; Sel=@(@{F='Channel'; V=@('E-Commerce')}) }
)
function Get-SheetIds($doc) { $r = @(); for ($i = 0; $i -lt $doc.NoOfSheets(); $i++) { $r += $doc.GetSheet($i).GetProperties().SheetId }; $r }
$out = @()
Enter-QvLock -Owner engineer
try {
  $doc = Get-QvDoc
  $sheets = Get-SheetIds $doc
  $existing = @($doc.GetDocBookmarkNames())
  foreach ($s in $stories) {
    if ($existing -contains $s.Name) { $doc.RemoveDocBookmark($s.Name) }
    $hasSheet = $sheets -contains "Document\$($s.Sheet)"
    if ($hasSheet) { [void]$doc.ActivateSheetById("Document\$($s.Sheet)") }
    $doc.ClearAll($true)
    foreach ($sel in $s.Sel) {
      $f = $doc.Fields($sel.F)
      [void]$f.Select($sel.V[0])
      for ($i = 1; $i -lt $sel.V.Count; $i++) { [void]$f.ToggleSelect($sel.V[$i]) }
    }
    (Get-QvApp).WaitForIdle()
    $check = ($s.Sel | ForEach-Object { $_.F + '=' + $doc.Evaluate("GetFieldSelections($($_.F), ', ', 10)") }) -join '; '
    # (ShowPopupInfo, Name, Id, PopupTime, ExcludeSelections, IncludeLayoutState, IncludeScrollPos, IncludeInputFieldValues, InfoText, HideFromMenu)
    # NB: verified 14/10 via ExportBookmarks - the 3rd argument is the ID (stored as 'Document\<id>'), the 9th the info text.
    $doc.CreateDocBookmark($false, $s.Name, $s.Id, 0, $false, $hasSheet, $false, $false, $s.Info, $false)
    $out += "{0,-10} created on {1,-9} (sheet exists: {2}) -> {3}" -f $s.Id, $s.Sheet, $hasSheet, $check
    Update-QvLock -Owner engineer
  }
  # recall test: from SH_HELP, recall each bookmark, read selections + active sheet
  foreach ($s in $stories) {
    $doc.ClearAll($true)
    if ($sheets -contains 'Document\SH_HELP') { [void]$doc.ActivateSheetById('Document\SH_HELP') }
    $doc.RecallDocBookmarkById("Document\$($s.Id)"); (Get-QvApp).WaitForIdle()
    $sel = ($s.Sel | ForEach-Object { $_.F + '=' + $doc.Evaluate("GetFieldSelections($($_.F), ', ', 10)") }) -join '; '
    $act = $doc.ActiveSheet().GetProperties().SheetId
    $out += "recall {0,-10} -> {1} | active sheet {2} (want {3})" -f $s.Id, $sel, $act, $s.Sheet
  }
} finally {
  try { $doc.ClearAll($true) } catch {}
  Exit-QvLock -Owner engineer
}
$out += "--- doc bookmarks: " + (@($doc.GetDocBookmarkNames()) -join ' | ')
$out | Tee-Object -FilePath "$QvBuildRoot\logs\bookmarks-run.txt"
