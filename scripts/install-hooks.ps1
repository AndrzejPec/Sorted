#!/usr/bin/env pwsh
param(
    [switch]$Force
)

if (-not $Force) {
    $existing = git config --get core.hooksPath
    if ($existing -and $existing -ne ".githooks") {
        Write-Host "core.hooksPath is set to '$existing'. Re-run with -Force to overwrite."
        exit 1
    }
}

git config core.hooksPath .githooks
Write-Host "Configured core.hooksPath to .githooks"
