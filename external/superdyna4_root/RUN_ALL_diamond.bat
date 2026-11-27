@echo off
setlocal EnableExtensions
REM Edit solver settings here. Use your existing crystal-plasticity UMAT executable.
set "DIAMOND_SOLVER=C:\LSDYNA\program\lsdyna_cp.exe"
set "DIAMOND_NCPU=16"
set "DIAMOND_MEMORY=200000000"

set "DIAMOND_ROOT=%~dp0"
set "DIAMOND_RUNNER=%~f0"
set "DIAMOND_RETRY=0"
set "DIAMOND_PREVIEW=0"
set "DIAMOND_CONTINUE=0"
:options
if "%~1"=="" goto execute
if /I "%~1"=="-Retry" (set "DIAMOND_RETRY=1") else if /I "%~1"=="-Preview" (set "DIAMOND_PREVIEW=1") else if /I "%~1"=="-ContinueOnError" (set "DIAMOND_CONTINUE=1") else (
    echo Unknown option: %~1
    echo Usage: RUN_ALL.bat [-Preview] [-Retry] [-ContinueOnError]
    exit /b 1
)
shift
goto options
:execute
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$t=[System.IO.File]::ReadAllText($env:DIAMOND_RUNNER); $m=[Environment]::NewLine+'# POWERSHELL_BEGIN'; & ([scriptblock]::Create($t.Substring($t.IndexOf($m)+$m.Length)))"
set "RC=%ERRORLEVEL%"
if /I not "%DIAMOND_NO_PAUSE%"=="1" pause
exit /b %RC%
# POWERSHELL_BEGIN
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = $env:DIAMOND_ROOT
$SolverPath = $env:DIAMOND_SOLVER
$NumCpu = [int]$env:DIAMOND_NCPU
$Memory = $env:DIAMOND_MEMORY
$Retry = $env:DIAMOND_RETRY -eq '1'
$Preview = $env:DIAMOND_PREVIEW -eq '1'
$ContinueOnError = $env:DIAMOND_CONTINUE -eq '1'
function Get-PreparedCases {
    # A copy in rho_* processes that rho; a copy at diamond_models processes all rhos.
    $base = Get-Item -LiteralPath $root
    if ($base.Name -match '^rho_-?\d+(?:\.\d+)?$') {
        $rhoDirs = @($base)
    } else {
        $rhoDirs = @(Get-ChildItem -LiteralPath $root -Directory | Where-Object Name -Match '^rho_-?\d+(?:\.\d+)?$' | Sort-Object Name)
    }
    if ($rhoDirs.Count -eq 0) { throw 'Place RUN_ALL.bat in rho_* or diamond_models (not in seed_* or deg_*).' }
    foreach ($rho in $rhoDirs) {
        foreach ($seed in @(Get-ChildItem -LiteralPath $rho.FullName -Directory | Where-Object Name -Match '^seed_\d+$' | Sort-Object { [int]($_.Name -replace '^seed_', '') })) {
            foreach ($deg in @(Get-ChildItem -LiteralPath $seed.FullName -Directory | Where-Object Name -Match '^deg_\d+(?:\.\d+)?$' | Sort-Object { [double]($_.Name -replace '^deg_', '') })) {
                foreach ($case in @(Get-ChildItem -LiteralPath $deg.FullName -Directory | Sort-Object Name)) {
                    if (Test-Path -LiteralPath (Join-Path $case.FullName 'model.k') -PathType Leaf) {
                        [PSCustomObject]@{ CaseDir=$case.FullName; Label="$($rho.Name)/$($seed.Name)/$($deg.Name)/$($case.Name)" }
                    }
                }
            }
        }
    }
}
function Assert-DiamondSolver {
    if (-not (Test-Path -LiteralPath $SolverPath -PathType Leaf)) { throw "Set DIAMOND_SOLVER at the top of RUN_ALL.bat. Executable not found: $SolverPath" }
    if ($NumCpu -lt 1) { throw 'NumCpu must be positive.' }
    if ([string]$Memory -notmatch '^[1-9]\d*(?:[mMgG])?$') { throw 'Memory must be a positive LS-DYNA memory value.' }
    if ([string]$Memory -match '^0+$') { throw 'Memory must be positive.' }
}

function Test-DiamondNormalTermination {
    param([string]$RunDir)
    # Check a solver message, not a particular d3plot state number.
    foreach ($name in @('d3hsp', 'messag', 'stdout.log')) {
        $path = Join-Path $RunDir $name
        if ((Test-Path -LiteralPath $path -PathType Leaf) -and
            (Select-String -LiteralPath $path -Pattern '^\s*(?:\*+\s*)?n\s*o\s*r\s*m\s*a\s*l\s+t\s*e\s*r\s*m\s*i\s*n\s*a\s*t\s*i\s*o\s*n\b' -Quiet)) { return $true }
    }
    return $false
}

function Write-DiamondLiveOutput {
    param($Process, $StdoutFile, $StderrFile)
    # Read both pipes concurrently without waiting for a newline or process exit.
    # Keep raw bytes in the logs and decode incrementally for console display.
    $states = @(
        [PSCustomObject]@{ Stream=$Process.StandardOutput.BaseStream; Log=$StdoutFile; Writer=[Console]::Out; Encoding=$Process.StandardOutput.CurrentEncoding; Buffer=(New-Object byte[] 4096); Decoder=$null; Chars=$null; Task=$null; Done=$false },
        [PSCustomObject]@{ Stream=$Process.StandardError.BaseStream; Log=$StderrFile; Writer=[Console]::Error; Encoding=$Process.StandardError.CurrentEncoding; Buffer=(New-Object byte[] 4096); Decoder=$null; Chars=$null; Task=$null; Done=$false }
    )
    foreach ($state in $states) {
        $state.Decoder = $state.Encoding.GetDecoder()
        $state.Chars = New-Object char[] ($state.Encoding.GetMaxCharCount(4096))
        $state.Task = $state.Stream.ReadAsync($state.Buffer, 0, $state.Buffer.Length)
    }
    while (-not $states[0].Done -or -not $states[1].Done) {
        $progressed = $false
        foreach ($state in $states) {
            if ($state.Done -or -not $state.Task.IsCompleted) { continue }
            $progressed = $true
            $count = $state.Task.GetAwaiter().GetResult()
            if ($count -gt 0) {
                $state.Log.Write($state.Buffer, 0, $count)
                $state.Log.Flush()
            }
            $chars = $state.Decoder.GetChars($state.Buffer, 0, $count, $state.Chars, 0, ($count -eq 0))
            if ($chars -gt 0) {
                $state.Writer.Write($state.Chars, 0, $chars)
                $state.Writer.Flush()
            }
            if ($count -eq 0) { $state.Done = $true }
            else { $state.Task = $state.Stream.ReadAsync($state.Buffer, 0, $state.Buffer.Length) }
        }
        if (-not $progressed) { Start-Sleep -Milliseconds 50 }
    }
    $Process.WaitForExit()
    return $Process.ExitCode
}

function Invoke-DiamondCase {
    param([string]$CaseDir, [switch]$Retry)
    $CaseDir = (Resolve-Path -LiteralPath $CaseDir).Path
    $model = Join-Path $CaseDir 'model.k'
    if (-not (Test-Path -LiteralPath $model -PathType Leaf)) { throw "Run prepare.ps1 first: $model" }
    $lockPath = Join-Path $CaseDir 'diamond_run.lock'
    # CreateNew refuses concurrent runners and never replaces an existing lock.
    $lock = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $hash = (Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash
        $run = Join-Path $CaseDir 'run'
        $marker = Join-Path $run 'diamond_success.json'
        if (Test-Path -LiteralPath $marker -PathType Leaf) {
            try {
                $status = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
                if ($status.InputSHA256 -eq $hash -and $status.ExitCode -eq 0 -and
                    (Test-DiamondNormalTermination $run)) {
                    Write-Host "[SKIP] Completed: $CaseDir"
                    return 'Skipped'
                }
            } catch { Write-Host '[INFO] Completion marker could not be verified.' }
        }
        if (Test-Path -LiteralPath $run) {
            if (-not $Retry) { throw "Existing run preserved: $run . Inspect it; use -Retry to archive and start again." }
            $archive = Join-Path $CaseDir 'archive'
            New-Item -ItemType Directory -Path $archive -Force | Out-Null
            $name = 'run_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8)
            Move-Item -LiteralPath $run -Destination (Join-Path $archive $name)
        }
        New-Item -ItemType Directory -Path $run | Out-Null
        Copy-Item -LiteralPath $model -Destination (Join-Path $run 'model.k')
        $arguments = @('i=model.k', "ncpu=$NumCpu", "memory=$Memory")
        Write-Host "[RUN] $CaseDir"
        Write-Host "      $SolverPath $($arguments -join ' ')"
        $started = Get-Date
        if ((Get-FileHash -LiteralPath (Join-Path $run 'model.k')).Hash -ne $hash) { throw 'Input changed while preparing the run.' }
        # ProcessStartInfo uses literal paths, including spaces and [brackets].
        # Tee both streams to the console and log files using bounded buffers.
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $SolverPath
        $process.StartInfo.Arguments = $arguments -join ' '
        $process.StartInfo.WorkingDirectory = $run
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $stdout = [System.IO.File]::Open((Join-Path $run 'stdout.log'), [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        $stderr = [System.IO.File]::Open((Join-Path $run 'stderr.log'), [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        try {
            if (-not $process.Start()) { throw 'Could not start solver.' }
            $code = Write-DiamondLiveOutput $process $stdout $stderr
        } finally {
            $stdout.Dispose(); $stderr.Dispose(); $process.Dispose()
        }
        if ($null -eq $code -or $code -ne 0 -or -not (Test-DiamondNormalTermination $run)) {
            throw "Solver did not complete normally (exit=$code). Results preserved: $run"
        }
        [ordered]@{ InputSHA256=$hash; ExitCode=$code; Solver=$SolverPath; Arguments=$arguments; Started=$started.ToString('o'); Finished=(Get-Date).ToString('o') } |
            ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
        Write-Host "[DONE] $CaseDir"
        return 'Completed'
    } finally {
        $lock.Dispose()
        Remove-Item -LiteralPath $lockPath
    }
}

try {
    $cases = @(Get-PreparedCases)
    if ($cases.Count -eq 0) { throw 'No prepared model.k found. Run prepare.ps1 first.' }
    if ($Preview) {
        $cases | ForEach-Object { Write-Host "[PREVIEW] $($_.Label)" }
        Write-Host "Selected $($cases.Count) prepared cases. Solver not started."
        exit 0
    }
    Assert-DiamondSolver
    $done = 0; $skipped = 0; $failed = 0
    foreach ($case in $cases) {
        try {
            $result = Invoke-DiamondCase -CaseDir $case.CaseDir -Retry:$Retry
            if ($result -eq 'Skipped') { $skipped++ } else { $done++ }
        } catch {
            $failed++
            Write-Host "[ERROR] $($case.Label): $($_.Exception.Message)" -ForegroundColor Red
            if (-not $ContinueOnError) { break }
        }
    }
    Write-Host "Selected=$($cases.Count) Completed=$done Skipped=$skipped Failed=$failed NotProcessed=$($cases.Count-$done-$skipped-$failed)"
    if ($failed -gt 0) { exit 1 }
    exit 0
} catch { Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
