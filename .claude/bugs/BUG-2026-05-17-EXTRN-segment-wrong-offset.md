# BUG — EXTRN Data Symbol in .CODE Causes Wrong LEA Offset

**Date:** 2026-05-17 15:00 GMT+8
**Severity:** BLOCKER — game hangs with continuous speaker noise, keys unresponsive
**Toolchain:** TASM 4.1 + TLINK, DOSBox
**Module:** `src/SCRINTRO.ASM`
**Affected procs:** SCR_TITLE_RUN (caller), SND_PLAY_PATTERN (victim)

---

## Symptom

Game builds and runs. Title screen displays, but a continuous high-pitch tone plays and no keypresses are recognized. Game appears hung.

## Root Cause

`EXTRN SND_TITLE_JINGLE:WORD` was placed in the `.CODE` section of SCRINTRO.ASM, but `SND_TITLE_JINGLE` is a data symbol defined in DATA.ASM's `.DATA` section (DGROUP).

In TASM 4.1 `.MODEL SMALL` with simplified segment directives, the assembler uses EXTRN placement to determine the **assumed segment** for offset calculation. A data EXTRN declared in `.CODE` is treated as code-relative; `LEA SI, SND_TITLE_JINGLE` computes an offset within the code segment instead of DGROUP:

```
DS = @DATA (correct, set by MAIN.ASM)
SI = offset computed relative to _TEXT (WRONG — should be relative to DGROUP)
DS:SI → random memory in DGROUP, not the DW pattern data
```

`SND_PLAY_PATTERN` then reads garbage values as (frequency, duration) pairs. The loop — `MOV BX, [SI]` / `OR BX, BX` / `JZ SPP_DONE` — never encounters a zero word, so it loops forever. The speaker stays enabled (continuous high-pitch tone) and the game never reaches `INP_WAIT_KEY`.

## Evidence

**SCR_GAME.ASM** (correct — no issues):
```
.DATA
    EXTRN SPRITE_TABLE:BYTE, SOUND_TABLE:WORD     ; ← data EXTRNs in .DATA
.CODE
    EXTRN GFX_DRAW_SPRITE:PROC                      ; ← code EXTRNs in .CODE
```

**SCRINTRO.ASM** (bug — EXTRN in wrong section):
```
.DATA
    ...local strings only, no SND_TITLE_JINGLE EXTRN...
.CODE
    EXTRN SND_TITLE_JINGLE:WORD                     ; ← DATA EXTRN IN .CODE!
```

The existing data EXTRNs in SCRINTRO.ASM (STR_TITLE, BG_TITLE, etc.) were all in `.DATA`. Only the newly-added `SND_TITLE_JINGLE` was misplaced.

## Fix

Move `EXTRN SND_TITLE_JINGLE:WORD` from `.CODE` to `.DATA`:

```diff
+.DATA
+    EXTRN SND_TITLE_JINGLE:WORD
+
 .CODE
-    EXTRN SND_TITLE_JINGLE:WORD
     EXTRN GFX_LOAD_BG:PROC, GFX_CLEAR:PROC, GFX_DRAW_STRING:PROC
```

**Lines:** `src/SCRINTRO.ASM` ~43 (moved into .DATA before .CODE directive)

## Prevention

- Data EXTRNs (`:BYTE`, `:WORD`, `:DWORD`) MUST be placed in `.DATA` section
- Code EXTRNs (`:PROC`) MUST be placed in `.CODE` section
- This is consistent with how SCR_GAME.ASM and every other module in the project handles EXTRN placement
- The `tasm-conventions` skill and `integration-checker` agent should flag cross-segment EXTRN placement

## Related

- `BUG-2026-05-13-SCR_GAME-gfx-register-clobber.md` — same module had register clobber issues from GFX calls; this bug is the *next* instruction after those were fixed, making the symptom deceptively similar (game hung, GFX display visible)
