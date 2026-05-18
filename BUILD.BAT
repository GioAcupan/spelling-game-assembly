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
if "%1"=="TEST_AUD" goto TEST_AUD
if "%1"=="TEST_FIO" goto TEST_FIO
if "%1"=="TEST_SCI" goto TEST_SCI
if "%1"=="TEST_SG" goto TEST_SG
if "%1"=="TEST_SE" goto TEST_SE
if "%1"=="TEST_BG" goto TEST_BG

REM ============================================
REM Assemble each module to .OBJ
REM ============================================
tasm /zi /isrc src\MAIN.ASM
if errorlevel 1 goto FAIL
copy MAIN.OBJ build\MAIN.OBJ >nul
del MAIN.OBJ
tasm /zi /isrc src\GFX.ASM, build\GFX.OBJ
tasm /zi /isrc src\AUDIO.ASM, build\AUDIO.OBJ
tasm /zi /isrc src\INPUT.ASM, build\INPUT.OBJ
tasm /zi /isrc src\FILEIO.ASM, build\FILEIO.OBJ
tasm /zi /isrc src\STATE.ASM, build\STATE.OBJ
tasm /zi /isrc src\DATA.ASM, build\DATA.OBJ
tasm /zi /isrc src\SCRINTRO.ASM, build\SCRINTRO.OBJ
tasm /zi /isrc src\SCR_GAME.ASM, build\SCR_GAME.OBJ
tasm /zi /isrc src\SCR_END.ASM, build\SCR_END.OBJ

REM ============================================
REM Link all .OBJ files into SPELL.EXE
REM Response file avoids DOS 127-char command tail limit
REM ============================================
ECHO build\MAIN.OBJ+>build\SPELL.LNK
ECHO build\GFX.OBJ+>>build\SPELL.LNK
ECHO build\INPUT.OBJ+>>build\SPELL.LNK
ECHO build\DATA.OBJ+>>build\SPELL.LNK
ECHO build\AUDIO.OBJ+>>build\SPELL.LNK
ECHO build\FILEIO.OBJ+>>build\SPELL.LNK
ECHO build\STATE.OBJ+>>build\SPELL.LNK
ECHO build\SCRINTRO.OBJ+>>build\SPELL.LNK
ECHO build\SCR_GAME.OBJ+>>build\SPELL.LNK
ECHO build\SCR_END.OBJ,bin\SPELL.EXE>>build\SPELL.LNK
tlink /v @build\SPELL.LNK
if errorlevel 1 goto FAIL
DEL build\SPELL.LNK >nul
if exist welcome.bin copy welcome.bin bin\welcome.bin >nul

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

:TEST_AUD
echo Building smoke test: AUDIO
tasm /zi /isrc tests\TEST_AUD.ASM
if errorlevel 1 goto FAIL
copy TEST_AUD.OBJ build\TEST_AUD.OBJ >nul
del TEST_AUD.OBJ
tasm /zi /isrc src\AUDIO.ASM
if errorlevel 1 goto FAIL
copy AUDIO.OBJ build\AUDIO.OBJ >nul
del AUDIO.OBJ
tlink /v build\TEST_AUD.OBJ+build\AUDIO.OBJ, bin\TEST_AUD.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_AUD.EXE
goto DONE

:TEST_FIO
echo Building smoke test: FILEIO
tasm /zi /isrc tests\TEST_FIO.ASM
if errorlevel 1 goto FAIL
copy TEST_FIO.OBJ build\TEST_FIO.OBJ >nul
del TEST_FIO.OBJ
tasm /zi /isrc src\FILEIO.ASM
if errorlevel 1 goto FAIL
copy FILEIO.OBJ build\FILEIO.OBJ >nul
del FILEIO.OBJ
tasm /zi /isrc src\GFX.ASM
if errorlevel 1 goto FAIL
copy GFX.OBJ build\GFX.OBJ >nul
del GFX.OBJ
tasm /zi /isrc src\DATA.ASM
if errorlevel 1 goto FAIL
copy DATA.OBJ build\DATA.OBJ >nul
del DATA.OBJ
tlink /v build\TEST_FIO.OBJ+build\FILEIO.OBJ+build\GFX.OBJ+build\DATA.OBJ, bin\TEST_FIO.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_FIO.EXE
goto DONE

:TEST_SCI
echo Building smoke test: SCRINTRO
tasm /zi /isrc tests\TEST_SCI.ASM
if errorlevel 1 goto FAIL
copy TEST_SCI.OBJ build\TEST_SCI.OBJ >nul
del TEST_SCI.OBJ
tasm /zi /isrc src\SCRINTRO.ASM
if errorlevel 1 goto FAIL
copy SCRINTRO.OBJ build\SCRINTRO.OBJ >nul
del SCRINTRO.OBJ
tasm /zi /isrc src\GFX.ASM
if errorlevel 1 goto FAIL
copy GFX.OBJ build\GFX.OBJ >nul
del GFX.OBJ
tasm /zi /isrc src\INPUT.ASM
if errorlevel 1 goto FAIL
copy INPUT.OBJ build\INPUT.OBJ >nul
del INPUT.OBJ
tasm /zi /isrc src\AUDIO.ASM
if errorlevel 1 goto FAIL
copy AUDIO.OBJ build\AUDIO.OBJ >nul
del AUDIO.OBJ
tasm /zi /isrc src\FILEIO.ASM
if errorlevel 1 goto FAIL
copy FILEIO.OBJ build\FILEIO.OBJ >nul
del FILEIO.OBJ
tasm /zi /isrc src\DATA.ASM
if errorlevel 1 goto FAIL
copy DATA.OBJ build\DATA.OBJ >nul
del DATA.OBJ
REM Build response file to avoid DOS 127-byte command tail limit
REM + at end of line = TLINK continuation (all obj files become one arg)
ECHO build\TEST_SCI.OBJ+>build\TEST_SCI.LNK
ECHO build\SCRINTRO.OBJ+>>build\TEST_SCI.LNK
ECHO build\GFX.OBJ+>>build\TEST_SCI.LNK
ECHO build\INPUT.OBJ+>>build\TEST_SCI.LNK
ECHO build\AUDIO.OBJ+>>build\TEST_SCI.LNK
ECHO build\FILEIO.OBJ+>>build\TEST_SCI.LNK
ECHO build\DATA.OBJ,bin\TEST_SCI.EXE>>build\TEST_SCI.LNK
tlink /v @build\TEST_SCI.LNK
if errorlevel 1 goto FAIL
DEL build\TEST_SCI.LNK >nul
echo Build complete: bin\TEST_SCI.EXE
goto DONE

:TEST_SG
echo Building smoke test: SCR_GAME
tasm /zi /isrc tests\TEST_SG.ASM
if errorlevel 1 goto FAIL
copy TEST_SG.OBJ build\TEST_SG.OBJ >nul
del TEST_SG.OBJ
tasm /zi /isrc src\SCR_GAME.ASM
if errorlevel 1 goto FAIL
copy SCR_GAME.OBJ build\SCR_GAME.OBJ >nul
del SCR_GAME.OBJ
tasm /zi /isrc src\GFX.ASM
if errorlevel 1 goto FAIL
copy GFX.OBJ build\GFX.OBJ >nul
del GFX.OBJ
tasm /zi /isrc src\INPUT.ASM
if errorlevel 1 goto FAIL
copy INPUT.OBJ build\INPUT.OBJ >nul
del INPUT.OBJ
tasm /zi /isrc src\AUDIO.ASM
if errorlevel 1 goto FAIL
copy AUDIO.OBJ build\AUDIO.OBJ >nul
del AUDIO.OBJ
tasm /zi /isrc src\DATA.ASM
if errorlevel 1 goto FAIL
copy DATA.OBJ build\DATA.OBJ >nul
del DATA.OBJ
ECHO build\TEST_SG.OBJ+>build\TEST_SG.LNK
ECHO build\SCR_GAME.OBJ+>>build\TEST_SG.LNK
ECHO build\GFX.OBJ+>>build\TEST_SG.LNK
ECHO build\INPUT.OBJ+>>build\TEST_SG.LNK
ECHO build\AUDIO.OBJ+>>build\TEST_SG.LNK
ECHO build\DATA.OBJ,bin\TEST_SG.EXE>>build\TEST_SG.LNK
tlink /v @build\TEST_SG.LNK
if errorlevel 1 goto FAIL
DEL build\TEST_SG.LNK >nul
echo Build complete: bin\TEST_SG.EXE
goto DONE

:TEST_SE
echo Building smoke test: SCR_END
tasm /zi /isrc tests\TEST_SE.ASM
if errorlevel 1 goto FAIL
copy TEST_SE.OBJ build\TEST_SE.OBJ >nul
del TEST_SE.OBJ
tasm /zi /isrc src\SCR_END.ASM
if errorlevel 1 goto FAIL
copy SCR_END.OBJ build\SCR_END.OBJ >nul
del SCR_END.OBJ
tasm /zi /isrc src\GFX.ASM
if errorlevel 1 goto FAIL
copy GFX.OBJ build\GFX.OBJ >nul
del GFX.OBJ
tasm /zi /isrc src\INPUT.ASM
if errorlevel 1 goto FAIL
copy INPUT.OBJ build\INPUT.OBJ >nul
del INPUT.OBJ
tasm /zi /isrc src\AUDIO.ASM
if errorlevel 1 goto FAIL
copy AUDIO.OBJ build\AUDIO.OBJ >nul
del AUDIO.OBJ
tasm /zi /isrc src\FILEIO.ASM
if errorlevel 1 goto FAIL
copy FILEIO.OBJ build\FILEIO.OBJ >nul
del FILEIO.OBJ
tasm /zi /isrc src\DATA.ASM
if errorlevel 1 goto FAIL
copy DATA.OBJ build\DATA.OBJ >nul
del DATA.OBJ
ECHO build\TEST_SE.OBJ+>build\TEST_SE.LNK
ECHO build\SCR_END.OBJ+>>build\TEST_SE.LNK
ECHO build\GFX.OBJ+>>build\TEST_SE.LNK
ECHO build\INPUT.OBJ+>>build\TEST_SE.LNK
ECHO build\AUDIO.OBJ+>>build\TEST_SE.LNK
ECHO build\FILEIO.OBJ+>>build\TEST_SE.LNK
ECHO build\DATA.OBJ,bin\TEST_SE.EXE>>build\TEST_SE.LNK
tlink /v @build\TEST_SE.LNK
if errorlevel 1 goto FAIL
DEL build\TEST_SE.LNK >nul
echo Build complete: bin\TEST_SE.EXE
goto DONE

:TEST_BG
echo Building smoke test: BACKGROUND PREVIEW
tasm /zi /isrc tests\TEST_BG.ASM
if errorlevel 1 goto FAIL
copy TEST_BG.OBJ build\TEST_BG.OBJ >nul
del TEST_BG.OBJ
tasm /zi /isrc src\GFX.ASM
if errorlevel 1 goto FAIL
copy GFX.OBJ build\GFX.OBJ >nul
del GFX.OBJ
tlink /v build\TEST_BG.OBJ+build\GFX.OBJ, bin\TEST_BG.EXE
if errorlevel 1 goto FAIL
if exist welcome.bin copy welcome.bin bin\welcome.bin >nul
echo Build complete: bin\TEST_BG.EXE
goto DONE

:FAIL
echo.
echo ******************************
echo  BUILD FAILED — check errors above
echo ******************************

:DONE
