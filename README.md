# Spelling Game

An educational toddler spelling game for Intel 8086 real mode, running in DOSBox. Built with TASM 4.1 and TLINK.

Kids spell words across three difficulty tiers. Visual sprite rewards, PC speaker sound effects, and a persistent leaderboard. (To update pa po UI)

## Requirements

- [DOSBox](https://www.dosbox.com/) (or any DOS emulator with VGA and PC speaker support)
- The game itself: `bin\SPELL.EXE`

No host toolchain needed to run — just drop the `bin\` folder into DOSBox and launch.

## Building (for developers)

Build runs **inside DOSBox**. The toolchain:
- **Assembler:** Borland Turbo Assembler 4.1 (TASM)
- **Linker:** TLINK
- **Runtime:** DOSBox (8086 real mode, VGA Mode 13h, PC speaker)

```
BUILD.BAT              → assemble + link → bin\SPELL.EXE
BUILD.BAT test_GFX     → build GFX smoke test → bin\TEST_GFX.EXE
BUILD.BAT test_BG      → build background previewer → bin\TEST_BG.EXE
CLEAN.BAT              → delete build\*.OBJ and bin\*.EXE
```

Available smoke test targets: `TSTMAIN`, `TEST_ST`, `TEST_DT`, `TEST_GFX`, `TEST_INP`, `TEST_AUD`, `TEST_FIO`, `TEST_SCI`, `TEST_SG`, `TEST_SE`, `TEST_BG`.

## How to play

1. Launch DOSBox, mount the project, and run `bin\SPELL.EXE`
2. **Title screen** — press any key
3. **Enter name** — type your 3-letter name, press Enter
4. **Choose difficulty** — Easy (3-letter words), Medium (4-letter), or Hard (5-letter)
5. **Instructions** — review the controls, press any key
6. **Gameplay** — a scrambled word appears with a hint sprite. Type the correct spelling and press Enter
7. **Judge screen** — see if you got it right! 2-player mode shows side-by-side results
8. **Leaderboard** — top scores persisted across sessions

Keyboard controls during gameplay:
- Type letters to spell the word
- **Backspace** to erase
- **Escape** to quit to title

## Project structure

```
src/         — module .ASM source
tests/       — per-module standalone smoke tests
build/       — .OBJ output (gitignored)
bin/         — final .EXE (gitignored)
docs/        — design spec and study notes
BUILD.BAT    — build pipeline
CLEAN.BAT    — clean build artifacts
```
