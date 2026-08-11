$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$runSmpSource = Join-Path $root "RUN_SMP.bat"

Write-Host ""
Write-Host "============================================"
Write-Host " LS-DYNA Run Preparation"
Write-Host "============================================"
Write-Host ""

# ------------------------------------------------------------
# Check master RUN_SMP.bat
# ------------------------------------------------------------

if (-not (Test-Path $runSmpSource)) {
    Write-Host "[ERROR] RUN_SMP.bat was not found:" -ForegroundColor Red
    Write-Host "        $runSmpSource"
    exit 1
}

# ------------------------------------------------------------
# Find candidate .k files
#
# Expected:
# rho_{rho}_seed{seed}\{texture}_sigma{sd}_seed{seed}.k
# ------------------------------------------------------------

$candidates = @()

$rhoDirs = Get-ChildItem -Path $root -Directory |
    Where-Object { $_.Name -match '^rho_.+_seed\d+$' }

foreach ($rhoDir in $rhoDirs) {

    # Seed number from parent directory
    if ($rhoDir.Name -notmatch '_seed(?<parentSeed>\d+)$') {
        continue
    }

    $parentSeed = [int]$Matches.parentSeed

    $kFiles = Get-ChildItem -Path $rhoDir.FullName -File -Filter "*.k"

    foreach ($file in $kFiles) {

        # Example:
        # brass_sigma2_seed1.k
        if ($file.Name -notmatch '^(?<texture>.+)_sigma(?<sd>\d+)_seed(?<seed>\d+)\.k$') {
            continue
        }

        $texture = $Matches.texture
        $sd      = [int]$Matches.sd
        $seed    = [int]$Matches.seed

        # ----------------------------------------------------
        # Only even sd values
        # ----------------------------------------------------

        if ($sd % 2 -ne 0) {
            continue
        }

        # ----------------------------------------------------
        # Validate seed
        # ----------------------------------------------------

        if ($seed -ne $parentSeed) {
            Write-Host "[WARNING] Seed mismatch - skipped:" -ForegroundColor Yellow
            Write-Host "          $($file.FullName)"
            Write-Host "          Folder seed = $parentSeed, File seed = $seed"
            continue
        }

        $modelName = "${texture}_sd${sd}_seed${seed}"
        $modelDir  = Join-Path $rhoDir.FullName $modelName
        $modelK    = Join-Path $modelDir "model.k"
        $runSmpDst = Join-Path $modelDir "RUN_SMP.bat"

        # Existing model.k must never be overwritten
        if (Test-Path $modelK) {
            Write-Host "[SKIP] model.k already exists: $modelName" -ForegroundColor DarkYellow
            continue
        }

        $candidates += [PSCustomObject]@{
            Source     = $file.FullName
            RhoDir     = $rhoDir.Name
            Texture    = $texture
            SD         = $sd
            Seed       = $seed
            ModelName  = $modelName
            ModelDir   = $modelDir
            ModelK     = $modelK
            RunSmpDst  = $runSmpDst
        }
    }
}

# ------------------------------------------------------------
# Nothing to prepare
# ------------------------------------------------------------

if ($candidates.Count -eq 0) {
    Write-Host ""
    Write-Host "No models need to be prepared."
    Write-Host ""
    exit 0
}

# ------------------------------------------------------------
# Preview
# ------------------------------------------------------------

Write-Host ""
Write-Host "The following models will be prepared:"
Write-Host ""

foreach ($item in $candidates) {

    Write-Host "[$($item.RhoDir)]"
    Write-Host "  SD     : $($item.SD)"
    Write-Host "  Source : $($item.Source)"
    Write-Host "  ->     : $($item.ModelK)"
    Write-Host ""
}

Write-Host "============================================"
Write-Host " Total models : $($candidates.Count)"
Write-Host " Only even SD values are included."
Write-Host "============================================"
Write-Host ""

# ------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------

$answer = Read-Host "Type YES to continue"

if ($answer -cne "YES") {
    Write-Host ""
    Write-Host "[CANCELLED] No files were changed." -ForegroundColor Yellow
    exit 0
}

# ------------------------------------------------------------
# Execute
# ------------------------------------------------------------

Write-Host ""
Write-Host "Preparing models..."
Write-Host ""

$prepared = 0
$failed   = 0

foreach ($item in $candidates) {

    try {

        Write-Host "[PREPARE] $($item.ModelName)"

        # 1. Create model directory
        if (-not (Test-Path $item.ModelDir)) {
            New-Item -ItemType Directory -Path $item.ModelDir | Out-Null
        }

        # Safety check again immediately before move
        if (Test-Path $item.ModelK) {
            Write-Host "  [SKIP] model.k appeared before move." -ForegroundColor Yellow
            continue
        }

        # 2 + 3.
        # Move source .k and rename it to model.k
        Move-Item `
            -LiteralPath $item.Source `
            -Destination $item.ModelK

        # 4.
        # Copy RUN_SMP.bat only if it does not already exist
        if (-not (Test-Path $item.RunSmpDst)) {
            Copy-Item `
                -LiteralPath $runSmpSource `
                -Destination $item.RunSmpDst
        }

        Write-Host "  [OK]"
        $prepared++

    }
    catch {

        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "============================================"
Write-Host " Preparation completed"
Write-Host " Prepared : $prepared"
Write-Host " Failed   : $failed"
Write-Host "============================================"
Write-Host ""