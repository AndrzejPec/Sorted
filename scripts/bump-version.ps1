# USAGE: Run this script AFTER you have added all commits for the new version.
#
#   .\scripts\bump-version.ps1 -Version "3.5"
#
# This script updates the version number in three places:
#   - mod.info       (modversion field)
#   - Sorted_LatestVersion.lua  (CURRENT_VERSION constant)
#   - content.txt    (filled with the latest changelog section)
#
# After running, commit the changed files as the release commit.

param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$changeLogPath  = Join-Path $repoRoot "Contents\mods\Sorted\42\ChangeLog.txt"
$contentPath    = Join-Path $repoRoot "Contents\mods\Sorted\common\content.txt"
$luaVersionPath = Join-Path $repoRoot "Contents\mods\Sorted\42\media\lua\client\VersionModal\Sorted_LatestVersion.lua"
$modInfoPath    = Join-Path $repoRoot "Contents\mods\Sorted\common\mod.info"
$debugPath      = Join-Path $repoRoot "Contents\mods\Sorted\42\media\lua\client\0_Sorted_Debug.lua"

# 1. Update modversion in mod.info
$modInfo = Get-Content $modInfoPath -Raw
$newModInfo = $modInfo -replace '(?m)^modversion=.*$', "modversion=$Version"
if ($newModInfo -eq $modInfo) {
    Write-Warning "modversion not found in mod.info"
} else {
    Set-Content $modInfoPath -Value $newModInfo -NoNewline
    Write-Host "Updated modversion -> $Version in mod.info"
}

# 2. Update CURRENT_VERSION in Lua
$lua = Get-Content $luaVersionPath -Raw
$newLua = $lua -replace 'CURRENT_VERSION = "[^"]*"', "CURRENT_VERSION = `"$Version`""
if ($newLua -eq $lua) {
    Write-Warning "CURRENT_VERSION not found or already set to $Version in Sorted_LatestVersion.lua"
} else {
    Set-Content $luaVersionPath -Value $newLua -NoNewline
    Write-Host "Updated CURRENT_VERSION -> $Version in Sorted_LatestVersion.lua"
}

# 2. Extract last changelog section (between last date header and its closing [ ------ ])
$changelogLines = Get-Content $changeLogPath

$lastStart = -1
for ($i = 0; $i -lt $changelogLines.Length; $i++) {
    if ($changelogLines[$i] -match '^\[ \d') {
        $lastStart = $i
    }
}

if ($lastStart -lt 0) {
    Write-Warning "No changelog section found - content.txt not updated."
    exit 0
}

$sectionLines = [System.Collections.Generic.List[string]]::new()
for ($i = $lastStart; $i -lt $changelogLines.Length; $i++) {
    if ($changelogLines[$i] -match '^\[ ------' -and $i -gt $lastStart) { break }
    $sectionLines.Add($changelogLines[$i])
}

Set-Content $contentPath -Value $sectionLines
Write-Host "Updated content.txt with $($sectionLines.Count) lines from last changelog section"

# Ensure debug logging is disabled before release
$debug = Get-Content $debugPath -Raw
$newDebug = $debug -replace '(Sorted\.debug\s*=\s*\{[^}]*enabled\s*=\s*)true', '${1}false'
if ($newDebug -eq $debug) {
    Write-Host "Debug already disabled in 0_Sorted_Debug.lua"
} else {
    Set-Content $debugPath -Value $newDebug -NoNewline
    Write-Host "Disabled debug logging in 0_Sorted_Debug.lua"
}

Write-Host ""
Write-Host "Done. Version modal will show: $Version"
Write-Host "Edit content.txt manually if you want a different message."
