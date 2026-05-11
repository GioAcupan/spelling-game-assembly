@echo off
echo ========================================
echo  Spelling Game — Build Pipeline
echo ========================================

if not exist build mkdir build
if not exist bin mkdir bin

if "%1"=="test_MAIN" goto TEST_MAIN
if "%1"=="TEST_ST" goto TEST_ST
if "%1"=="TEST_DT" goto TEST_DT

REM ============================================
REM Assemble each module to .OBJ
REM ============================================
tasm /zi /isrc src\MAIN.ASM, build\MAIN.OBJ
if errorlevel 1 goto FAIL
REM TODO: Day 2 — uncomment when GFX smoke test passes
REM tasm /zi /isrc src\GFX.ASM, build\GFX.OBJ
REM TODO: Day 3 — uncomment when AUDIO smoke test passes
REM tasm /zi /isrc src\AUDIO.ASM, build\AUDIO.OBJ
REM TODO: Day 4 — uncomment when INPUT smoke test passes
REM tasm /zi /isrc src\INPUT.ASM, build\INPUT.OBJ
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
tasm /zi /isrc tests\test_MAIN.asm, build\TEST_MAIN.OBJ
if errorlevel 1 goto FAIL
tlink /v build\TEST_MAIN.OBJ, bin\TEST_MAIN.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_MAIN.EXE
goto DONE

:TEST_ST
echo Building smoke test: STATE
tasm /zi /isrc tests\TEST_ST.ASM, build\TEST_ST.OBJ
if errorlevel 1 goto FAIL
tasm /zi /isrc src\STATE.ASM, build\STATE.OBJ
if errorlevel 1 goto FAIL
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

:FAIL
echo.
echo ******************************
echo  BUILD FAILED — check errors above
echo ******************************

:DONE
