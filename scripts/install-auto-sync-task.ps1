param(
  [string]$TaskName = 'NoSmokeAutoSync',
  [int]$EveryMinutes = 5,
  [switch]$RunAnalyze = $false
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$syncScript = Join-Path $PSScriptRoot 'auto-sync.ps1'

$analyzeArg = if ($RunAnalyze) { ' -RunAnalyze' } else { '' }
$taskCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$syncScript`" -RepoPath `"$repoRoot`"$analyzeArg"

schtasks /Delete /TN $TaskName /F 2>$null | Out-Null
schtasks /Create /SC MINUTE /MO $EveryMinutes /TN $TaskName /TR $taskCommand /RL LIMITED /F | Out-Null

Write-Output "ok: task $TaskName created (every $EveryMinutes minutes)"
