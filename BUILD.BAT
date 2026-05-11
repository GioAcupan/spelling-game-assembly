@echo off
echo ========================================
echo  Spelling Game — Build Pipeline
echo ========================================

if not exist build mkdir build
if not exist bin mkdir bin

if "%1"=="TSTMAIN" goto TEST_MAIN
if "%1"=="TEST_ST" goto TEST_ST
if "%1"=="TEST_DT" goto TEST_DT
if "%1"=="TEST_GFX" goto TEST_GFX
if "%1"=="TEST_INP" goto TEST_INP

REM ============================================
REM Assemble each module to .OBJ
REM ============================================
tasm /zi /isrc src\MAIN.ASM
if errorlevel 1 goto FAIL
copy MAIN.OBJ build\MAIN.OBJ >nul
del MAIN.OBJ
tasm /zi /isrc src\GFX.ASM, build\GFX.OBJ
REM TODO: Day 3 — uncomment when AUDIO smoke test passes
REM tasm /zi /isrc src\AUDIO.ASM, build\AUDIO.OBJ
tasm /zi /isrc src\INPUT.ASM, build\INPUT.OBJ
REM TODO: Day 4 — uncomment when FILEIO smoke test passes
REM tasm /zi /isrc src\FILEIO.ASM, build\FILEIO.OBJ
REM TODO: Day 5 — uncomment when STATE smoke test passes
REM tasm /zi /isrc src\STATE.ASM, build\STATE.OBJ
tasm /zi /isrc src\DATA.ASM, build\DATA.OBJ
REM TODO: Day 5 — uncomment when screen modules pass
REM tasm /zi /isrc src\SCR_INTRO.ASM, build\SCR_INTRO.OBJ
REM tasm /zi /isrc src\SCR_GAME.ASM, build\SCR_GAME.OBJ
REM tasm /zi /isrc src\SCR_END.ASM, build\SCR_END.OBJ

REM ============================================
REM Link all .OBJ files into SPELL.EXE
REM Only include modules whose smoke tests pass
REM ============================================
tlink /v build\MAIN.OBJ, bin\SPELL.EXE
REM TODO: Add modules as they pass: +build\GFX.OBJ+build\AUDIO.OBJ+...
if errorlevel 1 goto FAIL

echo.
echo Build complete: bin\SPELL.EXE
goto DONE

:TEST_MAIN
echo Building smoke test: MAIN
tasm /zi /isrc tests\TSTMAIN.ASM
if errorlevel 1 goto FAIL
copy TSTMAIN.OBJ build\TSTMAIN.OBJ >nul
del TSTMAIN.OBJ
tasm /zi /isrc src\MAIN.ASM
if errorlevel 1 goto FAIL
copy MAIN.OBJ build\MAIN.OBJ >nul
del MAIN.OBJ
tlink /v build\TSTMAIN.OBJ+build\MAIN.OBJ, bin\TSTMAIN.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TSTMAIN.EXE
goto DONE

:TEST_ST
echo Building smoke test: STATE
tasm /zi /isrc tests\TEST_ST.ASM
if errorlevel 1 goto FAIL
copy TEST_ST.OBJ build\TEST_ST.OBJ >nul
del TEST_ST.OBJ
tasm /zi /isrc src\STATE.ASM
if errorlevel 1 goto FAIL
copy STATE.OBJ build\STATE.OBJ >nul
del STATE.OBJ
tlink /v build\TEST_ST.OBJ+build\STATE.OBJ, bin\TEST_ST.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_ST.EXE
goto DONE

:TEST_DT
echo Building smoke test: DATA
tasm /zi /isrc tests\TEST_DT.ASM
if errorlevel 1 goto FAIL
copy TEST_DT.OBJ build\TEST_DT.OBJ >nul
del TEST_DT.OBJ
tasm /zi /isrc src\DATA.ASM
if errorlevel 1 goto FAIL
copy DATA.OBJ build\DATA.OBJ >nul
del DATA.OBJ
tlink /v build\TEST_DT.OBJ+build\DATA.OBJ, bin\TEST_DT.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_DT.EXE
goto DONE

:TEST_GFX
echo Building smoke test: GFX
tasm /zi /isrc tests\TEST_GFX.ASM
if errorlevel 1 goto FAIL
copy TEST_GFX.OBJ build\TEST_GFX.OBJ >nul
del TEST_GFX.OBJ
tasm /zi /isrc src\GFX.ASM
if errorlevel 1 goto FAIL
copy GFX.OBJ build\GFX.OBJ >nul
del GFX.OBJ
tlink /v build\TEST_GFX.OBJ+build\GFX.OBJ, bin\TEST_GFX.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_GFX.EXE
goto DONE

:TEST_INP
echo Building smoke test: INPUT
tasm /zi /isrc tests\TEST_INP.ASM
if errorlevel 1 goto FAIL
copy TEST_INP.OBJ build\TEST_INP.OBJ >nul
del TEST_INP.OBJ
tasm /zi /isrc src\INPUT.ASM
if errorlevel 1 goto FAIL
copy INPUT.OBJ build\INPUT.OBJ >nul
del INPUT.OBJ
tlink /v build\TEST_INP.OBJ+build\INPUT.OBJ, bin\TEST_INP.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_INP.EXE
goto DONE

:FAIL
echo.
echo ******************************
echo  BUILD FAILED — check errors above
echo ******************************

:DONE
