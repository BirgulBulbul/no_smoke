param(
  [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$RunAnalyze = $false
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
  param(
    [Parameter(Mandatory=$true)][string[]]$Args,
    [switch]$AllowFail = $false
  )

  $output = & git -C $RepoPath @Args 2>&1
  $code = $LASTEXITCODE

  if (-not $AllowFail -and $code -ne 0) {
    throw "git $($Args -join ' ') failed: $output"
  }

  return @{ Output = $output; ExitCode = $code }
}

try {
  Invoke-Git -Args @('rev-parse', '--is-inside-work-tree') | Out-Null

  $branch = (Invoke-Git -Args @('branch', '--show-current')).Output.Trim()
  if ($branch -ne 'main') {
    Write-Output "skip: current branch is $branch"
    exit 0
  }

  $hasOrigin = Invoke-Git -Args @('remote', 'get-url', 'origin') -AllowFail
  if ($hasOrigin.ExitCode -ne 0) {
    Write-Output 'skip: origin remote missing'
    exit 0
  }

  $conflicts = (Invoke-Git -Args @('diff', '--name-only', '--diff-filter=U')).Output
  if ($conflicts) {
    Write-Output 'skip: merge conflicts detected'
    exit 0
  }

  $status = (Invoke-Git -Args @('status', '--porcelain')).Output
  if (-not $status) {
    Write-Output 'skip: no changes'
    exit 0
  }

  Invoke-Git -Args @('add', '-A') | Out-Null

  & git -C $RepoPath diff --cached --quiet
  if ($LASTEXITCODE -eq 0) {
    Write-Output 'skip: nothing staged after add'
    exit 0
  }

  if ($RunAnalyze) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -ne $flutter) {
      & $flutter.Source analyze | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Output 'skip: analyze failed, commit not created'
        exit 0
      }
    }
  }

  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $message = "chore(auto-sync): snapshot $stamp"
  Invoke-Git -Args @('commit', '-m', $message) | Out-Null

  $push = Invoke-Git -Args @('push', 'origin', 'main') -AllowFail
  if ($push.ExitCode -ne 0) {
    Write-Output 'warn: commit created but push failed'
    exit 0
  }

  Write-Output 'ok: auto-sync commit pushed'
  exit 0
}
catch {
  Write-Output "error: $($_.Exception.Message)"
  exit 0
}
