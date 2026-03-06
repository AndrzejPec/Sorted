# DO NOT RUN THIS SCRIPT MANUALLY. It is called automatically by the git commit-msg hook.
#
# It reads the commit message and appends an entry to ChangeLog.txt based on a prefix:
#   "First: <message>"    - starts a new changelog section with today's date
#   "Following: <message>"- adds a bullet point to the current section
#   "Last: <message>"     - adds a bullet point and closes the section with [ ------ ]
#
# Commits without one of these prefixes are ignored by this hook.
# Install the hook with:  .\scripts\install-hooks.ps1

param(
    [Parameter(Mandatory = $true)]
    [string]$CommitMsgPath
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$changeLogPath = Join-Path $repoRoot "Contents\mods\Sorted\42\ChangeLog.txt"

if (-not (Test-Path -Path $CommitMsgPath)) {
    exit 0
}

$rawSummary = Get-Content -Path $CommitMsgPath |
    Where-Object { $_ -and -not $_.StartsWith("#") } |
    Select-Object -First 1

if (-not $rawSummary) {
    exit 0
}

if (-not (Test-Path -Path $changeLogPath)) {
    New-Item -Path $changeLogPath -ItemType File -Force | Out-Null
}

$mode = $null
$dateOverride = $null
$summary = $rawSummary

if ($rawSummary -match '^(First|Following|Last)(?:\s+(.+?))?\s*:\s*(.+)$') {
    $mode = $matches[1]
    $dateOverride = $matches[2]
    $summary = $matches[3]
}

if (-not $mode) {
    exit 0
}

$date = $null
if ($mode -eq "First") {
    if ($dateOverride) {
        $date = $dateOverride.Trim()
    } else {
        $date = (Get-Date).ToString("dd MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
    }
}

$lines = @()
if ($mode -eq "First") {
    $lines += ""
    $lines += ""
    $lines += "[ $date ]"
}

$lines += "- $summary"

if ($mode -eq "Last") {
    $lines += "[ ------ ]"
    $lines += ""
}

Add-Content -Path $changeLogPath -Value $lines

& git add -- "$changeLogPath" | Out-Null
