@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"

echo ==========================================
echo LS-DYNA Sequential Runner
echo ==========================================
echo Directory: %ROOT%
echo.

REM ==========================================================
REM Loop over prepared model directories
REM ==========================================================

for /d %%D in ("%ROOT%*_sd*_seed*") do (

    if exist "%%~fD\RUN_SMP.bat" (

        echo.
        echo ------------------------------------------
        echo Checking: %%~nxD

        REM ==================================================
        REM Completed analysis -> skip
        REM ==================================================

        if exist "%%~fD\run\d3plot13" (

            echo [SKIP] %%~nxD
            echo        d3plot13 already exists.

        ) else (

            echo [RUN ] %%~nxD
            echo        Start: %date% %time%

            REM Enter model directory
            pushd "%%~fD"

            REM Run existing RUN_SMP.bat.
            REM <nul prevents its pause command from stopping
            REM this sequential runner.
            call RUN_SMP.bat <nul

            popd

            echo [DONE] %%~nxD
            echo        End: %date% %time%
        )
    )
)

echo.
echo ==========================================
echo All target folders processed.
echo ==========================================

pause