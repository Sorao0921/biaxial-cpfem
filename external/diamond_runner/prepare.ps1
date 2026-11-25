[CmdletBinding()]
param(
    [string]$Root = $PSScriptRoot,
    [string[]]$Rhos, [int[]]$Seeds, [double[]]$Degrees, [string[]]$Textures,
    [switch]$Preview
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
function Get-DiamondCases {
    param([string]$Root, [string[]]$Rhos, [int[]]$Seeds, [double[]]$Degrees, [string[]]$Textures)
    foreach ($rho in @(Get-ChildItem -LiteralPath $Root -Directory | Sort-Object Name)) {
        if ($rho.Name -notmatch '^rho_(?<value>-?\d+(?:\.\d+)?)$') { continue }
        $rhoValue = $Matches.value
        if ($Rhos -and $rhoValue -notin $Rhos) { continue }
        foreach ($seed in @(Get-ChildItem -LiteralPath $rho.FullName -Directory | Where-Object Name -Match '^seed_\d+$' | Sort-Object { [int]($_.Name -replace '^seed_', '') })) {
            if ($seed.Name -notmatch '^seed_(?<value>\d+)$') { continue }
            $seedValue = [int]$Matches.value
            if ($Seeds -and $seedValue -notin $Seeds) { continue }
            foreach ($deg in @(Get-ChildItem -LiteralPath $seed.FullName -Directory | Where-Object Name -Match '^deg_\d+(?:\.\d+)?$' | Sort-Object { [double]($_.Name -replace '^deg_', '') })) {
                $degreeValue = [double]($deg.Name -replace '^deg_', '')
                if ($Degrees -and $degreeValue -notin $Degrees) { continue }
                foreach ($file in @(Get-ChildItem -LiteralPath $deg.FullName -File -Filter '*.k' | Sort-Object Name)) {
                    if ($file.BaseName -notmatch '^[a-zA-Z0-9_-]+$') { throw "Unsupported texture filename: $($file.FullName)" }
                    if ($Textures -and $file.BaseName -notin $Textures) { continue }
                    $caseDir = Join-Path $deg.FullName $file.BaseName
                    [PSCustomObject]@{
                        Source = $file.FullName; CaseDir = $caseDir
                        Model = Join-Path $caseDir 'model.k'
                        Label = "$($rho.Name)/$($seed.Name)/$($deg.Name)/$($file.BaseName)"
                    }
                }
            }
        }
    }
}


try {
    $cases = @(Get-DiamondCases -Root $Root -Rhos $Rhos -Seeds $Seeds -Degrees $Degrees -Textures $Textures)
    # Preflight the complete batch. Never replace a different existing model.k.
    foreach ($case in $cases) {
        if (Test-Path -LiteralPath $case.Model) {
            if ((Get-FileHash -LiteralPath $case.Source).Hash -ne (Get-FileHash -LiteralPath $case.Model).Hash) {
                throw "Prepared model differs from source; no inputs overwritten: $($case.Model)"
            }
        }
    }
    if ($Preview) {
        $cases | ForEach-Object { Write-Host "[PREVIEW] $($_.Label) -> model.k" }
        Write-Host "Selected $($cases.Count) source decks. No files changed."
        exit 0
    }
    $prepared = 0; $skipped = 0
    foreach ($case in $cases) {
        if (Test-Path -LiteralPath $case.Model) { $skipped++; continue }
        New-Item -ItemType Directory -Path $case.CaseDir -Force | Out-Null
        # Move + rename: no duplicate deck or per-case launcher is created.
        [System.IO.File]::Move($case.Source, $case.Model)
        $prepared++
    }
    Write-Host "Prepared=$prepared ExistingIdentical=$skipped. Existing prepared folders/results are retained."
    if ($cases.Count -eq 0) { Write-Host 'No remaining source decks. Prepared model.k files are left unchanged.' }
    exit 0
} catch { Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
