# BUG — GFX Procedure Register Clobber Cascade in SCR_GAME.ASM

**Date:** 2026-05-13 17:30–22:00 GMT+8
**Severity:** BLOCKER — scramble hint stuck, echo broken, score garbage
**Toolchain:** TASM 4.1 + TLINK, DOSBox
**Module:** `src/SCR_GAME.ASM`
**Affected procs:** GFX_DRAW_CHAR (root), GFX_DRAW_STRING (propagates)

---

## Root Cause Pattern

`GFX_DRAW_CHAR` clobbers registers without the caller's knowledge. Its header says:

```
; Preserves: DS, BP
; Clobbers:  AX, CX, DX, SI, DI
```

But it also **silently corrupts BH** via `MOV BH, BL` (copies color byte to high byte) and **sets ES = A000h**. This means:

| Register | Header claims | Actually happens |
|----------|--------------|-----------------|
| BH | Unlisted (assumed preserved) | Overwritten with color value |
| ES | Unlisted (assumed preserved) | Set to A000h |
| DI | Listed as clobbered | Set to framebuffer y*320+x |

Any code that holds a 16-bit value in BX across a GFX call loses the high byte. Any code using ES:DI addressing loses both. This caused **four distinct bugs**, all with the same root cause.

---

## Bug 1: Input Echo — Buffer Stored to VRAM

**Symptom:** Typing "CAT" got "OOPS!" every time. Only the first character landed in INPUT_BUFFER.

**Trace:**
```
    LEA  DI, INPUT_BUFFER        ; DI = buffer offset
SRR_CHAR_LOOP:
    CALL INP_WAIT_KEY            ; AL = char
    MOV  [DI+BX], AL             ; store via DS:DI+BX ✓ (first char only)
    ...
    CALL GFX_DRAW_CHAR           ; DI ← framebuffer addr, ES ← A000h
    ...
    JMP  SRR_CHAR_LOOP           ; next char: [DI+BX] stores to A000h:DI ✗
```

After the first `CALL GFX_DRAW_CHAR`, DI pointed into video memory. All subsequent character stores went to the framebuffer instead of the input buffer.

**Attempts:**
1. Tried saving/restoring DI around GFX_DRAW_CHAR — still broken because ES was also clobbered
2. Tried PUSH/POP of AX, CX, DX, SI, DI, ES, BX — still fragile due to BX/BH corruption
3. Tried switching to `INP_READ_STRING` (silent) + post-facto echo — worked but no real-time echo

**Fix:** Full register save/restore (7 registers: AX, CX, DX, SI, DI, ES, BX) around every GFX_DRAW_CHAR call in the echo loop. Buffer addressed via `DS:[DI+BX]` (implicit DS) so ES clobber doesn't matter.

**Lines:** `src/SCR_GAME.ASM` ~295-345 (SRR_STORE, SRR_BACKSPACE blocks)

---

## Bug 2: Scramble Hint Always Shows "ATC"

**Symptom:** DEBUG proved C=1, S=1 on round 2, but hint still showed "ATC" (word 0) instead of "ODG" (word 1). A single-byte probe `MOV AL, [SCRAMBLE_TABLE + SCRAMBLE_OFF]` drew 'O' correctly — proving the address was right.

**Trace:**
```
    MOV  AX, SCRAMBLE_OFF        ; AX = 16 (correct)
    LEA  SI, STR_HINT
    ... draw "HINT: " ...
    CALL GFX_DRAW_STRING         ; clobbers AX!
    LEA  SI, SCRAMBLE_TABLE
    ADD  SI, AX                  ; AX = garbage from GFX call → SI = wrong address
    CALL GFX_DRAW_STRING         ; draws whatever is at garbage address
```

`GFX_DRAW_STRING` clobbers AX (listed in its Clobbers header). The offset was loaded into AX, then destroyed by the "HINT: " label draw. The subsequent `ADD SI, AX` used a garbage value, making SI point to random memory.

The single-byte T-probe worked because it used `ADD SI, SCRAMBLE_OFF` (direct memory operand), bypassing AX entirely.

**Attempts:**
1. Stored global word index in BP — didn't work (BP was clobbered by some procedure chain)
2. Stored in `.DATA` variable `GLOBAL_IDX` — didn't work (same AX-clobber timing issue)
3. Pre-computed `SCRAMBLE_OFF` immediately after CURRENT_WORD read — didn't work (still loaded into AX before GFX call)

**Fix:** Moved `MOV AX, SCRAMBLE_OFF` to *after* the `CALL GFX_DRAW_STRING("HINT: ")`, right before `ADD SI, AX`.

**Lines:** `src/SCR_GAME.ASM` ~208-216

---

## Bug 3: Score Shows Garbage "20545"

**Symptom:** Correct answer showed "SCORE: 20545" — `20545 = 0x5041 = ASCII "PA"` from a nearby string in the data segment.

**Trace:**
```
    ADD  SCORES[BX], CX          ; BX = 0 (word index for P1)
    ...
    MOV  BL, 15                  ; BL = color (white)
    CALL GFX_DRAW_STRING("SCORE:") ; inside GFX_DRAW_CHAR: MOV BH, BL → BH = 15
    MOV  AX, SCORES[BX]          ; BX = 0x0F00 = 3840 → SCORES[3840] = garbage
```

`GFX_DRAW_CHAR` does `MOV BH, BL` — reads BL (color=15), writes BH. This corrupts the high byte of BX. BL was set to 15 for the color, making the full BX = `0x0F00` = 3840 instead of 0. `SCORES[3840]` reads far past the 4-byte SCORES array into string data.

The GFX_DRAW_CHAR header doesn't list BX as clobbered — BL is preserved (read-only), but the header doesn't mention that BH is silently overwritten.

**Fix:** Read `SCORES[BX]` into AX *before* the GFX call, push AX to preserve it, draw the label, pop AX, then convert to string.

**Lines:** `src/SCR_GAME.ASM` ~539-549

---

## Bug 4: Backspace Doesn't Visually Erase

**Symptom:** Pressing Backspace didn't remove the last character from screen.

**Root Cause:** GFX_DRAW_CHAR with space character (glyph index 0) draws nothing. The font glyph for space is `DB 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h` — all zero bits. The transparency check `SHL AL, 1 / JNC GDS_SKIP` skips every pixel because all font bits are 0. So drawing a black space character is a no-op.

**Fix:** Direct framebuffer write using `REP STOSB` — compute `DI = y*320 + x`, set `ES = A000h`, write 8 bytes of 0x00 per row for 8 rows.

**Lines:** `src/SCR_GAME.ASM` ~330-370 (SRR_BACKSPACE block)

---

## Bug 5: Conditional Jumps Out of Range

**Symptom:** "Relative jump out of range by 0010h bytes" (and similar).

**Root Cause:** 8086 conditional jumps limited to ±128 bytes. As the echo loop and backspace handler grew with full register save/restore blocks, backward `JB`/`JE` jumps exceeded the limit.

**Affected jumps:**
- `JB SRR_PLAYER_LOOP` (backward, >128 bytes) → `JAE SRR_ALL_DONE / JMP SRR_PLAYER_LOOP`
- `JB SJR_LOOP` (backward, >128 bytes) → `JAE SJR_LOOP_DONE / JMP SJR_LOOP`
- `JE SRR_INPUT_DONE` (forward, >128 bytes) → `JNE SRR_NOT_ENTER / JMP SRR_INPUT_DONE`

**Fix:** Invert condition to nearest next instruction + near JMP to far target.

---

## Lessons Learned

1. **Never hold a value in AX across a GFX call.** GFX_DRAW_STRING and GFX_DRAW_CHAR both clobber AX. Reload immediately before use, or push/pop.

2. **Never hold a 16-bit value in BX across a GFX call.** GFX_DRAW_CHAR silently corrupts BH via `MOV BH, BL`. Only BL (the low byte) is preserved. If you need the full 16-bit BX value, save/restore it.

3. **Never rely on ES after a GFX call.** GFX_DRAW_CHAR sets ES = A000h. Reload ES before any ES-based addressing.

4. **Never rely on DI after a GFX call.** GFX_DRAW_CHAR computes `DI = y*320 + x` for the framebuffer. Reload DI before any buffer addressing.

5. **The GFX_DRAW_CHAR header is incomplete.** It should list BH (high byte corruption) and ES (A000h) in its Clobbers list. Callers must defensively save these registers.

6. **GFX_DRAW_STRING clobbers everything useful.** Between string draws, assume AX, BX (high byte), CX, DX, SI, DI, and ES are all lost. Reload from memory or push/pop.

7. **Diagnostic probes are invaluable.** The single-byte T-probe (`MOV AL, [SCRAMBLE_TABLE + SCRAMBLE_OFF]`) proved the address was correct while GFX_DRAW_STRING was not — isolating the bug to the call pattern rather than data or addressing.

---

## Affected Code

| File | Lines | Bug |
|------|-------|-----|
| `src/SCR_GAME.ASM` | ~295-345 | Echo loop — register clobber cascade |
| `src/SCR_GAME.ASM` | ~208-216 | Scramble hint — AX clobbered by GFX_DRAW_STRING |
| `src/SCR_GAME.ASM` | ~539-549 | Score display — BH clobber + stale BX index |
| `src/SCR_GAME.ASM` | ~330-370 | Backspace erase — transparent space glyph |
| `src/SCR_GAME.ASM` | ~299, ~505, ~283 | Conditional jump range limits |
