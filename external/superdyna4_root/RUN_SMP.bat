@echo off
REM OPTION
set num_cpu=16
REM EXE DIR
set solver_dir="C:\LSDYNA\program\lsdyna_cp.exe"

REM MKDIR
rmdir /s /q run
mkdir run

scp model.k run

REM RUN
cd run
%solver_dir% I="model.k"  NCPU=%num_cpu% memory=200000000

pause