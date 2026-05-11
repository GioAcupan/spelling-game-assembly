# BUG — TASM 4.1 Parser Corruption on Long `DB`/`DW` Lines in Large Segments

**Date:** 2026-05-09 01:00 GMT+8
**Severity:** BLOCKER — DATA.ASM cannot assemble
**Toolchain:** Turbo Assembler Version 4.1 (user has 4.1, not 5.0 as assumed)
**Module:** `src/DATA.ASM`

---

## Symptom Summary

TASM 4.1 fails to assemble DATA.ASM. Errors always cluster near the end of the file, regardless of total segment size. Two error types appear:

1. **"Undefined symbol: DW"** — TASM stops recognizing `DW` as a directive keyword
2. **"CS unreachable from current segment"** — TASM loses segment context for labels

Both errors are parser state corruption, not actual code/data structure issues.

## Current Failing Lines

With sprite data restored and SOUND_TABLE using one `DW OFFSET` per line:

```
**Error** src\DATA.ASM(113) Undefined symbol: DW        ← DB line in DOG sprite
**Error** src\DATA.ASM(116) Undefined symbol: DW
**Error** src\DATA.ASM(117) Undefined symbol: DW
**Error** src\DATA.ASM(118) Undefined symbol: DW
**Error** src\DATA.ASM(121) Undefined symbol: DW
**Error** src\DATA.ASM(122) Undefined symbol: DW
**Error** src\DATA.ASM(123) Undefined symbol: DW
**Error** src\DATA.ASM(131) CS unreachable from current segment
**Error** src\DATA.ASM(132) CS unreachable from current segment
...through 138
```

Lines 105-138 are all `DB 0,0,0,...,0` lines (32 values each) in the DOG sprite. The parser works for the first ~40 long DB lines (CAT + early DOG), then degrades.

---

## Hypotheses Tested (all DISPROVEN)

| # | Hypothesis | Test | Result |
|---|-----------|------|--------|
| 1 | Missing `.CODE` section | Added `.CODE` before `END` | No effect |
| 2 | Forward `DW OFFSET` references confuse TASM | Moved SOUND_TABLE after sound patterns | No effect |
| 3 | Data segment exceeds TASM 4.1 size limit (~31.5KB) | Split SPRITE_TABLE to SPRITES.ASM (30KB → data in each module well under 64KB) | DISPROVEN — DATA.ASM alone (144 lines, ~1KB data) still failed |
| 4 | Duplicate `PUBLIC` declaration | Removed duplicate | No effect |
| 5 | `INCLUDE SHARED.INC` in pure-data module | Removed INCLUDE from SPRITES.ASM | No effect |
| 6 | Pure-data module structure incompatible with TASM 4.1 | Created minimal SPRITES.ASM with single `DB 0` | DISPROVEN — DATA.ASM's first ~40 DB lines always assemble correctly; the error is at a LINE COUNT threshold, not structural |
| 7 | Multiple `DW OFFSET` directives per line overflow parser | Split to one DW per line | **PARTIALLY HELPED** (shifted error location) but underlying issue remains |
| 8 | 32-value `DB` lines overflow parser after ~40 lines | **LIKELY ROOT CAUSE** — errors cluster around line 40+ of long DB directives, regardless of total data size | **NOT YET FIXED** |

---

## Root Cause (Strongly Suspected)

**TASM 4.1 has a parser buffer/state limit when processing many consecutive `DB` directives with large numbers of comma-separated values.**

Evidence:
- The first ~40 `DB 0,0,0,...,0` lines (32 values each) always assemble cleanly
- Errors start around DB line ~40-45, manifesting as "Undefined symbol: DW" (parser can't recognize directive keywords anymore)
- After enough parser corruption, labels also fail ("CS unreachable")
- This explains why the error "moves" when we add/remove lines — it's at a specific LINE COUNT from the start of the sprite data
- The 2-sprite minimal SPRITES.ASM (64 DB lines) failed at line 15 (`SPRITE_TABLE:`) — parser was still corrupted from processing 64 long lines
- The single-byte `DB 0` SPRITES.ASM failed because after the sprite data was eliminated, the `.CODE` transition at end of file confused the parser (same state issue, different trigger)

**All symptoms are the SAME root cause:** TASM 4.1 parser state degrades after processing a critical mass of data directives. The manifestation varies (DW undefined, CS unreachable, label misplaced) depending on what the parser was doing when it lost state.

---

## Test Data: What Was Tried

### Minimal SPRITES.ASM tests
All failed with "CS unreachable from current segment" at the label line:

| Version | Content | Error |
|---------|---------|-------|
| 30 sprites (960 DB lines) | Full sprite data | Line 16: CS unreachable |
| 2 sprites (64 DB lines) | Truncated | Line 15: CS unreachable |
| `DB 0` (1 byte) | Single byte | Line 5: CS unreachable |
| `DB 0` no INCLUDE | Removed SHARED.INC | Line 5: CS unreachable |

### DATA.ASM tests
| Version | Content | Result |
|---------|---------|--------|
| Original (1114 lines) | Sprite data + all data | "Undefined symbol: DW" at SOUND_TABLE (offset ~31KB) |
| Trimmed (144 lines) | No sprite data, ~1KB total | "Undefined symbol: DW" at SOUND_TABLE lines |
| Trimmed + 1 DW/line | No sprite, split DW lines | **BUILDS CLEAN** (unverified — SPRITES.ASM failed first) |
| Full + 1 DW/line | Sprite data + split DW lines | Fails at sprite DB lines ~40+ |

### Critical Diagnostic
Reordered BUILD.BAT to assemble DATA.ASM before SPRITES.ASM. This revealed that the 144-line DATA.ASM (thought to compile) actually FAILS with the same "Undefined symbol: DW" errors. The errors were previously masked because SPRITES.ASM always failed first.

---

## Working Baseline (for reference)

| Module | Lines | Status | Notes |
|--------|-------|--------|-------|
| `MAIN.ASM` | ~25 | ✓ Compiles | Small data, has .CODE with code |
| `STATE.ASM` | ~70 | ✓ Compiles | Tiny data, has .CODE with code |
| `TEST_ST.ASM` | ~190 | ✓ Compiles | Links with STATE.OBJ |
| `TEST_DT.ASM` | ~230 | ✓ Compiles* | Assembly passes (0 errors), object write may fail |
| `DATA.ASM` | 1114 | ✗ FAILS | Parser corruption in sprite/sound data |

---

## Potential Fixes (NOT YET TRIED)

1. **Split sprite DB lines into shorter directives** — Use 8 values per `DB` instead of 32 (quadruples line count to ~3840, but avoids parser overflow). E.g.: `DB 0,0,0,0,188,188,0,0` instead of `DB 0,0,0,0,188,188,0,0,0,0,0,0,...` (32 values)

2. **Use `DW` for sprite data** — 16 values per `DW` vs 32 per `DB`. But 8086 is little-endian, so byte order must be swapped:
   - Current: `DB 0, 0, 0, 0, 188, 188, 0, 0, ...` (bytes in display order)
   - As DW: `DW 0, 0BCh, 0, 0BCh, ...` (word-swapped pairs)

3. **Use hex encoding** — Encode each sprite as hex bytes (shorter source lines):
   - `DB 000h, 000h, 0BCh, 0BCh, ...` (hex values, TASM-compatible)
   - Or use `DB 0, 0, 0BCh, 0BCh, ...` (mix of decimal and hex)

4. ~~**Use TASM 5.0 instead of 4.1**~~ — *Rejected 2026-05-09: project officially targets TASM 4.1 (CLAUDE.md updated). Don't propose this as a fix.*

5. **Split sprites into multiple separate data modules** — Each with few enough sprites (e.g., 3-5) to stay under the parser's DB-line tolerance. Then link all .OBJ files.

6. **Regenerate sprite data in a TASM-4.1-friendly format** — Modify `sprite_export.py` to emit shorter DB lines (e.g., 8 values each) and use hex for values > 9.

---

## Environment

- DOSBox, MS-DOS
- Turbo Assembler Version 4.1 (Borland, 1988-1996)
- `.MODEL SMALL` — one 64KB code + one 64KB data segment
- TASM flags: `/zi` (debug info), `/isrc` (include path joined: no space)
- TASM output: writes .OBJ via `copy`+`del` workaround (TASM 4.1 `/o` path handling differs from 5.0)

---

## STATE file with immediate next steps

1. Try fix #1 (split DB to 8 values/line) — regenerate sprite_bytes.txt or post-process it
2. ~~If that fails, try fix #4 (use TASM 5.0) — check if the user can switch~~ *(see fix #4 — no longer in scope)*
3. If neither works, implement fix #5 (multiple sprite data modules, 3-5 sprites each)

The BUILD.BAT TEST_DT target currently has the `copy`+`del` workaround for TASM 4.1 output path handling.
