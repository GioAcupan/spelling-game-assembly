# 📚 Spelling Game — Dev Study Guide

> **Companion document to:** `SPELLING_GAME_MVP.md`
> **Audience:** The 3 devs (Lead, Dev 2: Graphics+Input, Dev 3: Audio+File I/O)
> **Philosophy:** Learn *only* what the MVP needs, in the order you'll need it. Skip everything else.
> **Format:** Concept → why it matters → MVP module it unlocks → resources (book + video + web)

---

## 📖 Reference Books (Pick 1, Use Throughout)

We're anchoring to **two books only** — one primary, one backup. Don't scatter across five books. Pick your primary based on learning style and stick with it.

### 🥇 PRIMARY — *Assembly Language Programming and Organization of the IBM PC* (Ytha Yu & Charles Marut, 1992)

**Why this one:** The standard university textbook for 8086 assembly across most CS programs. It targets exactly our setup (IBM PC, DOS, real mode, TASM/MASM syntax). Chapters map cleanly to our MVP modules. Used in many SE Asian CS curricula — good chance your prof learned from it too.

- Readable for beginners; builds concepts progressively.
- Covers exactly our topics: registers, flow control, stack, arrays, strings, keyboard, graphics, BIOS/DOS interrupts, file I/O.
- **Does not cover:** PC speaker port-level programming (we supplement with web).
- **PDF:** Available on academia.edu — search `"Ytha Yu" "Assembly Language Programming" PDF`
- **Exercise solutions:** github.com/shawon100/Assembly-8086

### 🥈 BACKUP — *The Art of Assembly Language Programming* (Randall Hyde, DOS/16-bit edition)

**Why as backup only:** More theoretical. Excellent for *deeply* understanding a concept you've gotten stuck on, but heavy for speed-learning. Free and legit online.

- **Free, official:** `https://www.plantation-productions.com/Webster/www.artofasm.com/DOS/index.html` (DOS/16-bit edition — pick this one, NOT the HLA or newer 32-bit edition)
- Use when Yu/Marut is too brief on a topic and you need deeper intuition.

### 🎥 PRIMARY VIDEO RESOURCE — ChibiAkumas 8086 Playlist

**Why:** The best free 8086 video tutorials on YouTube. Beginner-friendly, tool-agnostic (works with TASM), game-dev focused. Perfect for devs who prefer watching over reading.

- **Main page:** `https://www.chibiakumas.com/8086/` (text + code + linked videos per lesson)
- **YouTube channel:** `https://www.youtube.com/c/ChibiAkumas/playlists` → look for the 8086 playlist
- Each lesson has: a written article + source code + matching YouTube video. Pick your format.

### 🌐 TARGETED WEB REFERENCES (Specific Concepts)

Used for concepts the book doesn't cover well. Full URLs in the relevant sections below:

- **INightmare's Blog** (`devdocs.inightmare.org`) — Mode 13h graphics, DOS file I/O
- **FenixFox Studios** (`fenixfox-studios.com`) — VGA mode 13h, PC speaker programming
- **Gavin's Guide to 80x86 Assembly** — DOS file handling
- **Care4you INT 21h reference** — Quick lookup for DOS interrupts

---

## 🗺️ How to Use This Guide

1. **Every dev reads Part 1 (Foundations).** Non-negotiable. Without these, none of the module-specific chapters will make sense.
2. **Each dev then jumps to their role's learning track** in Part 2.
3. **Each concept maps to an MVP chapter.** After studying the concept, open the MVP doc's corresponding chapter — the code should now be readable.
4. **Time estimates assume 1 study hour/day.** If you have more, learn faster. If less, focus on the resources marked ⭐ (essential) and skip ✨ (supplemental).
5. **Don't aim for mastery. Aim for "enough to read the MVP chapter and write the code."** Optimization and deep theory come after ship day.

---

# PART 1 — FOUNDATIONS (ALL 3 DEVS)

These are the concepts that are required no matter which module you're building. Estimate: **~3-4 study hours total**, spread across Days 1-2.

## F1. TASM + DOSBox Toolchain Setup ⭐
**Why:** If you can't build and run a "Hello World," nothing else matters. This is Day 1, hour 1.

**MVP chapters unlocked:** All. This is the prerequisite for even opening the repo.

**Resources:**
- **Video ⭐:** "How to run assembly program using TASM" → `https://www.youtube.com/watch?v=vQvpSyW3dVs` (~10 min setup walkthrough)
- **Article ⭐:** "Making Music using Assembly, Part 1" by M Salman A on Medium → covers DOSBox + TASM folder setup step-by-step.
- **Quick check:** You can `mount c c:\tasm`, then `tasm hello.asm`, `tlink hello.obj`, and run `hello.exe` successfully.

## F2. 8086 Register Model & Memory Segmentation ⭐
**Why:** Everything in assembly is "move data between these named boxes." You *must* know what `AX`, `BX`, `CS`, `DS`, `ES`, `SS`, `SP`, `BP`, `SI`, `DI` are and why segment registers exist. Given your SAP-1/2/3 background, most of this will click fast — 8086 is just SAP with more registers and segmentation added.

**MVP chapters unlocked:** All. Every single module reads/writes registers.

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 3 ("Organization of the IBM Personal Computers") and Chapter 4 ("Introduction to IBM PC Assembly Language"). Read both together; they introduce registers and the basic `MOV`/`ADD`/`SUB` instructions.
- **Video ⭐:** ChibiAkumas 8086 Lesson 1 ("Introduction for Beginners") → covers registers visually. Then Lesson 2 (Addressing Modes) for segment:offset.
- **Reference ✨:** Art of Assembly (Hyde), Chapter 3 ("System Organization") for deeper register theory.

**Quick self-test:** You can answer these without looking up:
- What's the difference between `AX`, `AH`, `AL`?
- Why is `MOV DS, 1234h` invalid but `MOV AX, 1234h; MOV DS, AX` valid?
- What segment is the stack in?

## F3. TASM Program Skeleton (`.MODEL SMALL`, segments, `INT 21h/4Ch` exit) ⭐
**Why:** Every `.ASM` file in our project starts with the same boilerplate. You need to understand it, not just paste it.

**MVP chapters unlocked:** All modules (they all have this skeleton).

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 4 (sample programs section). Shows the classic `.MODEL SMALL` / `.STACK` / `.DATA` / `.CODE` / `END` skeleton.
- **Video ✨:** "ASSEMBLY LANGUAGE BASICS #1 | 8086 PROGRAMMING | TASM" → `https://www.youtube.com/watch?v=FtJwZtb6x6s` (demo + explain of a minimal TASM program)
- **Reference ⭐:** MVP doc Appendix A ("TASM Cheatsheet") has the skeleton — use this as a living reference.

## F4. Flow Control: `CMP`, Conditional Jumps, `LOOP` ⭐
**Why:** All game logic uses branching. `if (hearts == 0)` in C becomes `CMP HEARTS, 0; JE ...` in assembly.

**MVP chapters unlocked:** All — every state transition, every comparison.

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 6 ("Flow Control Instructions"). This is THE chapter for branches and loops.
- **Video ✨:** ChibiAkumas 8086 Lesson 3 (Jumps & Conditionals)
- **Cheat ⭐:** MVP doc Appendix A shows `JE/JNE/JA/JB/JG/JL` — know which ones are signed vs unsigned.

## F5. Stack, `PUSH`/`POP`, `CALL`/`RET`, Procedures ⭐
**Why:** Every module exports procedures. You need to understand how calls save return addresses, how to preserve registers across calls, and why forgetting `POP` corrupts the stack.

**MVP chapters unlocked:** All — everyone writes `PROC`/`ENDP` blocks.

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 8 ("The Stack and Introduction to Procedures"). Covers push/pop, `CALL`, `RET`, and register preservation conventions.
- **Video ⭐:** ChibiAkumas 8086 Lesson 4 ("The Stack") → `https://www.classcentral.com/course/youtube-x86-8086-assembly-tutorial-lesson-4-the-stack-176036` (35 min, very clear)
- **Critical concept:** "Clobbering" — if a subroutine uses `AX` and doesn't push/pop, the caller's `AX` is gone. **Read this twice.**

## F6. Multi-Module Assembly: `PUBLIC`, `EXTRN`, linking ⭐
**Why:** Our project is 10 `.ASM` files linked into one `.EXE`. Without understanding `PUBLIC`/`EXTRN`, your module can't call anyone else's code.

**MVP chapters unlocked:** All — every module uses `PUBLIC` and `EXTRN`.

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 8, section on separately assembled modules. (May also appear in Chapter 12 "Macros" in some editions.)
- **Web ⭐:** "Assembler for Dummies" tutorial on INightmare's blog covers cross-module calls.
- **MVP reference ⭐:** Chapter 2.5 of MVP doc (`BUILD.BAT`) shows the linker syntax.

## F7. ASCII, Uppercase/Lowercase, Null-Terminated Strings ⭐
**Why:** We compare spellings. We read names. All of this is bytes that happen to be letters. Knowing ASCII arithmetic (`'a' - 'A' = 32`) is essential.

**MVP chapters unlocked:** Input handling (all screens), spelling comparison (SCR_GAME), name entry (SCR_INTRO).

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 2 ("Representation of Numbers and Characters"). Light reading, mostly reference.
- **Web ✨:** Any ASCII table — `asciitable.com`

---

# PART 2 — ROLE-SPECIFIC TRACKS

Each dev follows the track for their role. Total study time per role: ~8-12 hours across Days 1-5.

---

## 🧑‍💻 TRACK A — DEV 1 (LEAD): Game Loop, State Machine, Screens, Integration

> **Your modules:** `MAIN.ASM`, `STATE.ASM`, `SHARED.INC`, `SCR_INTRO.ASM`, `SCR_GAME.ASM`, `SCR_END.ASM`
> **Your MVP chapters:** 3.1, 3.2, 3.3 (partial), 5.1, 5.2, 5.3
> **Your total study load:** ~10-12 hours (you lead — you need the widest knowledge)
> **Your learning order:** A1 → A2 → A3 → A4 → A5 → A6 → A7

### A1. Data Declaration: `DB`, `DW`, `DUP`, labels, `EQU` ⭐
**Why:** You're defining all the global state (`CURRENT_STATE`, `SCORE`, `HEARTS`, `INPUT_BUFFER`). You need fluency in declaring bytes/words/arrays.

**MVP chapter unlocked:** 3.1 (`MAIN.ASM` global state block)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 4 (data definition section) + Chapter 10 (arrays, addressing modes).
- **Video ✨:** ChibiAkumas 8086 Lesson 2 (Data, Memory, Addressing)
- **Pattern to internalize:** `MYVAR DB 0` (1 byte, initial 0), `MYARRAY DB 16 DUP(0)` (16 bytes of 0), `MAX_VAL EQU 99` (compile-time constant).

### A2. Branching Patterns for State Dispatchers ⭐
**Why:** `STATE.ASM` is a cascade of `CMP`/`JE`. You need to write this cleanly. Later, you might upgrade to a jump table (optional).

**MVP chapter unlocked:** 3.2 (`STATE.ASM`)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 6 (flow control) + Chapter 10 section on jump tables if you want to optimize.
- **Web ✨:** Search "8086 jump table" on chibiakumas.com for the optimization pattern.

### A3. DOS Console I/O: `INT 21h` AH=01/02/09/0A ⭐
**Why:** Your intro screens may use simple text output before graphics are done. Also useful for debugging (printing a register value to screen).

**MVP chapter unlocked:** 5.1 (`SCR_INTRO.ASM`) — fallback if graphics aren't ready

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 11 ("Text Display and Keyboard Programming") — covers `INT 21h` I/O.
- **Web ⭐:** Yassine Bridi's reference → `https://yassinebridi.github.io/asm-docs/8086_bios_and_dos_interrupts.html`
- **Reference ⭐:** MVP doc Appendix B.

### A4. BIOS Timer for Speed Scoring ⭐
**Why:** Your scoring formula uses elapsed time. Reading the BIOS tick counter at `0040:006Ch` via `INT 1Ah AH=0`.

**MVP chapter unlocked:** 5.2 (`SCR_GAME.ASM` — `TIMER_START` logic)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 14 ("BIOS and DOS Interrupts"). Also mentioned in Chapter 11.
- **Web ⭐:** Search "INT 1Ah AH=0 BIOS tick count" — many quick references.
- **Code pattern:**
  ```
  MOV AH, 0
  INT 1Ah        ; CX:DX = ticks since midnight
  ```

### A5. Number-to-ASCII Conversion (Decimal) ⭐
**Why:** You need to display `SCORE` (a 16-bit integer) as readable digits on the end screen. Standard algorithm: divide by 10 repeatedly, collect remainders, reverse.

**MVP chapter unlocked:** 5.3 (`SCR_END.ASM`)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 9 ("Multiplication and Division") gives `DIV`; Chapter 10 covers the full integer-to-string routine as a worked example.
- **Web ✨:** Search "8086 number to ASCII decimal" on stackoverflow.com — plenty of ready-made routines to study (don't just copy — understand).

### A6. String Comparison (Optional but useful) ✨
**Why:** `SCR_GAME` compares input buffer to correct answer. You can hand-roll this or use `CMPSB`/`REPE CMPSB`.

**MVP chapter unlocked:** 5.2 (spelling check)

**Resources:**
- **Book ✨:** Yu & Marut — Chapter 10-11 (string instructions `CMPS`, `LODS`, `STOS`, `MOVS`, `SCAS`).
- **Book ✨:** Art of Assembly (Hyde), Chapter 11 ("The String Instructions") — deeper dive.
- **MVP code ⭐:** The `STR_COMPARE` proc in MVP Chapter 5.2 is hand-rolled. Understand it first; optimize with `REPE CMPSB` later if you want.

### A7. Pointer Tables & Indirect Addressing ⭐
**Why:** The 3-tier difficulty system uses `TIER_TABLE` — an array of word-pointers. `SCR_ROUND_RUN` indexes into it with `DIFFICULTY` to resolve the correct word array base at runtime. This is the trickiest new concept introduced by the difficulty update.

**MVP chapter unlocked:** 3.3 (`TIER_TABLE` in `DATA.ASM`), 5.2 (`SCR_ROUND_RUN` tier resolution)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 10 ("Arrays and Addressing Modes"). The section on indirect addressing (`MOV SI, [BX]`) is exactly what you need.
- **Pattern to internalize:**
  ```asm
  ; Select tier base by difficulty
  MOV  AL, DIFFICULTY     ; 0, 1, or 2
  MOV  AH, 0
  SHL  AX, 1              ; × 2 (DW pointers = 2 bytes each)
  LEA  BX, TIER_TABLE     ; BX → table
  ADD  BX, AX             ; BX → correct table slot
  MOV  SI, [BX]           ; SI = address of selected tier's word array
  ```
- **Self-test:** Trace through with `DIFFICULTY=2` (Hard). What is `AX` after `SHL`? What address does `[BX]` dereference to? Does `SI` end up pointing at `HARD_WORDS`?
- **Web ✨:** Search "8086 jump table indirect addressing" on chibiakumas.com — the same pattern applies to both jump tables and data pointer tables.

**⚠️ Integration role — you also need to:**
- **Read through every other module's chapter (4.1, 4.2, 4.3, 4.4)** at a *skim* level on Day 4. You don't need to be able to write them, but when Dev 2 says "the sprite routine takes BX=x, DX=y," you should nod and know why.

---

## 🧑‍💻 TRACK B — DEV 2: Graphics (`GFX.ASM`) + Input (`INPUT.ASM`)

> **Your modules:** `GFX.ASM`, `INPUT.ASM`
> **Your MVP chapters:** 4.1, 4.2
> **Your total study load:** ~9-10 hours
> **Your learning order:** B1 → B2 → B3 → B4 → B5

### B1. BIOS Video Services via `INT 10h` ⭐
**Why:** How to switch video modes (text → graphics → back), the framework for all graphics calls.

**MVP chapter unlocked:** 4.2 (`GFX_INIT`, `GFX_SHUTDOWN`)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 14 ("BIOS and DOS Interrupts") + Chapter 15 ("Color Graphics"). Chapter 15 is your **must-read** — it covers `INT 10h` video services in depth.
- **Web ⭐:** "VGA mode 13h" tutorial by INightmare → `https://devdocs.inightmare.org/tutorials/x86-assembly-graphics-part-i-mode-13h.html`

### B2. Mode 13h Framebuffer: Writing to `A000:0000` ⭐
**Why:** This is the entire mental model for drawing: one byte per pixel, linear memory layout. Once this clicks, sprites are just `MOV` in a loop.

**MVP chapter unlocked:** 4.2 (`GFX_CLEAR`, `GFX_DRAW_SPRITE`)

**Resources:**
- **Web ⭐:** INightmare's Mode 13h tutorial (above — the first tutorial you read).
- **Web ⭐:** FenixFox Studios "VGA-Mode 13h" → `https://fenixfox-studios.com/content/vga_mode_13/` — includes full boilerplate source code.
- **Book ⭐:** Yu & Marut — Chapter 15 (color graphics).
- **Video ✨:** "[MASM] 8086 Assembly Tips | Draw Pixel | Mode 13h" → `https://www.youtube.com/watch?v=lMk6SKWCiTw`
- **Key formula:** `pixel_offset = y * 320 + x`, set `ES = 0A000h`, then `MOV ES:[DI], color`.

### B3. String Instructions (`STOSB`, `STOSW`, `LODSB`, `MOVSB`, `REP`) ⭐
**Why:** `GFX_CLEAR` uses `REP STOSW` to fill 64KB of video memory fast. Sprite copy uses `LODSB`/`STOSB` variants. These are the performance-critical instructions in graphics.

**MVP chapter unlocked:** 4.2

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 10 (addressing modes) and the string instructions section (sometimes Chapter 10 or 11 depending on edition).
- **Book ⭐ (alternate):** Art of Assembly (Hyde), Chapter 11 ("The String Instructions") — excellent deep treatment.
- **Reference pattern:** `MOV CX, 32000; REP STOSW` fills 32000 words = 64000 bytes = entire Mode 13h screen.

### B4. Sprite Rendering with Transparency ⭐
**Why:** Your core routine. For each sprite byte: if zero → skip (transparent); else → write to framebuffer.

**MVP chapter unlocked:** 4.2 (`GFX_DRAW_SPRITE`)

**Resources:**
- **Web ⭐:** INightmare's blog has a follow-up tutorial on sprite rendering — explore `asm.inightmare.org`.
- **Book ✨:** Yu & Marut, Chapter 15 covers bitmap drawing (may not go as deep as you need; supplement with web).
- **Source study:** The GitHub repo `amrwc/8086-graphics` has working NASM mode 13h code — syntax differs from TASM but concepts are identical. Good for seeing a full working example.
- **Dev task:** You will implement `GFX_DRAW_SPRITE` as described in MVP Chapter 4.2. Get a test sprite working Day 2.

### B5. 8×8 Bitmap Font Rendering ⭐
**Why:** Mode 13h has no built-in text routine. You need to render characters manually using a font bitmap.

**MVP chapter unlocked:** 4.2 (`GFX_DRAW_CHAR`, `GFX_DRAW_STRING`)

**Resources:**
- **Web ⭐:** Search "8x8 bitmap font public domain" — find any one (e.g., the classic IBM PC BIOS font extracted as byte arrays). One good source: search GitHub for "8x8 font asm" or "BIOS font dump".
- **Alternative ⭐:** Use ROM BIOS font via `INT 10h AH=11h` (character generator services). Yu & Marut Chapter 15 covers this.
- **Implementation approach:** For each char, look up 8 bytes from font table (8 rows), each byte's 8 bits are the pixels of that row. Draw pixels where bits are set.
- **Fallback:** If font rendering takes too long, consider briefly switching to text mode for text screens (intro, instructions, end). Ugly but shippable.

### B6. BIOS Keyboard Services via `INT 16h` ⭐
**Why:** Your `INPUT.ASM` module. All keyboard reading goes through this interrupt.

**MVP chapter unlocked:** 4.1 (`INPUT.ASM`)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 11 ("Text Display and Keyboard Programming") — covers `INT 16h` in depth.
- **Web ⭐:** Yassine Bridi's interrupt reference (`yassinebridi.github.io/asm-docs/8086_bios_and_dos_interrupts.html`) — section on INT 16h.
- **Reference ⭐:** MVP doc Appendix B.
- **Key distinction:** `INT 16h AH=0` **blocks** (waits for key). `INT 16h AH=1` **polls** (checks buffer, doesn't wait). Both return ASCII in `AL` and scan code in `AH`.

### B7. Scan Codes vs ASCII ✨
**Why:** For arrow keys (if you implement arcade-style name entry), you'll need scan codes — arrow keys return `AL=0` with a special scan code in `AH`.

**MVP chapter unlocked:** 4.1 (polish feature — arcade-style name entry)

**Resources:**
- **Web ⭐:** Same as B6 — all scan codes listed there.
- **Priority:** Low. Skip unless time permits on Day 6.

---

## 🧑‍💻 TRACK C — DEV 3: Audio (`AUDIO.ASM`) + File I/O (`FILEIO.ASM`)

> **Your modules:** `AUDIO.ASM`, `FILEIO.ASM`
> **Your MVP chapters:** 4.3, 4.4
> **Your total study load:** ~7-8 hours (smallest of the three)
> **Your learning order:** C1 → C2 → C3 → C4

### C1. Port I/O: `IN` and `OUT` Instructions ⭐
**Why:** PC speaker is controlled through hardware ports (`42h`, `43h`, `61h`). You need to understand what `OUT port, AL` does at the hardware level. Your SAP-1 background helps here — this is the 8086 equivalent of "writing to an output register."

**MVP chapter unlocked:** 4.3 (`AUDIO.ASM`)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 14 ("BIOS and DOS Interrupts") usually introduces `IN`/`OUT` briefly. Chapter 15 also uses them.
- **Book ✨ (deeper):** Art of Assembly (Hyde), Chapter 3 ("System Organization") covers I/O ports at the hardware level.
- **Web ⭐:** "Internal Speaker" reference → `https://www.ic.unicamp.br/~celio/mc404s102/pcspeaker/InternalSpeaker.htm`

### C2. PIT (Programmable Interval Timer) + PC Speaker Control ⭐
**Why:** To make the speaker beep at a specific frequency, you program the PIT chip via port `43h` (mode control) and port `42h` (counter value), then enable bits 0-1 of port `61h`. This is *the* core knowledge for AUDIO.ASM.

**MVP chapter unlocked:** 4.3

**Resources:**
- **Web ⭐⭐ (BEST):** FenixFox Studios "PC-Speaker 61h" → `https://fenixfox-studios.com/content/pc_speaker/` — walkthrough with code, exactly what you need.
- **Web ⭐:** KriAga's GitHub `8086-Microprocessor---Music/Documentation.txt` — explains ports 40h-43h and 61h clearly.
- **Reference ⭐:** MVP doc Chapter 4.3 has the full working code sketch — match each instruction to the explanations in these resources.
- **Formula:** `divisor = 1,193,180 / frequency_hz`. Write divisor low byte then high byte to port 42h.
- **Video ✨:** Search YouTube "8086 pc speaker tasm tutorial" — multiple walkthroughs exist.

### C3. Timing and Delay Loops ⭐
**Why:** A tone needs to play for a *duration*. You need a delay routine — use `INT 15h AH=86h` (microsecond wait) for clean timing.

**MVP chapter unlocked:** 4.3 (`SND_DELAY`)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 14. Also covered in BIOS interrupt references.
- **Web ⭐:** Yassine Bridi interrupt reference — section on INT 15h.
- **Pattern:** `MOV AH, 86h; MOV CX:DX, microseconds; INT 15h`.
- **Avoid ❌:** Naive busy-loops (`LOOP label`). They run at different speeds on different CPUs and DOSBox cycles settings.

### C4. DOS File I/O: Open, Create, Read, Write, Close ⭐
**Why:** Leaderboard persistence. `INT 21h` functions `3Ch` (create), `3Dh` (open), `3Eh` (close), `3Fh` (read), `40h` (write).

**MVP chapter unlocked:** 4.4 (`FILEIO.ASM`)

**Resources:**
- **Book ⭐⭐:** Yu & Marut — Chapter 18 ("Disk Operations") or Chapter 19 (varies by edition — look for the "Disk and file operations" chapter). This is your primary reference.
- **Web ⭐⭐:** "Gavin's Guide to 80x86 Assembly - Part 5" → `https://stuff.pypt.lt/ggt80x86a/asm6.htm` — complete file I/O tutorial with working examples. Excellent.
- **Web ⭐:** INightmare's "DOS File Input and Output" → `https://devdocs.inightmare.org/tutorials/x86-assembly-dos-file-inputoutput.html`
- **Reference ⭐:** MVP doc Appendix B and Chapter 4.4 code sketch.
- **Key concept:** The **file handle** is returned by open/create in `AX`. Save it, use it in `BX` for all subsequent read/write/close calls.
- **ASCIIZ:** DOS expects filenames as null-terminated strings (`'SCORES.DAT',0`). Not dollar-terminated.

### C5. Carry Flag for Error Handling ⭐
**Why:** DOS file calls set `CF=1` on error. You must check with `JC`/`JNC` after every file operation. "File doesn't exist" is a normal case (first run) — don't crash.

**MVP chapter unlocked:** 4.4

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 5 ("The Processor Status and the FLAGS Register") covers the carry flag.
- **Pattern:**
  ```
  MOV AH, 3Dh
  LEA DX, FILENAME
  INT 21h
  JC  FILE_NOT_FOUND    ; handle gracefully
  MOV HANDLE, AX
  ```

### C6. Sorting/Inserting in Fixed-Size Array ✨
**Why:** `FILE_INSERT_SCORE` must insert a new entry into a sorted top-5 leaderboard — shift entries down and insert at the right spot. The entry now includes a difficulty byte (`AL` on call) at record offset 5 (`LB_DIFF`).

**MVP chapter unlocked:** 4.4 (`FILE_INSERT_SCORE`)

**Resources:**
- **Pattern is pure algorithm, not interrupt-specific.** Standard insertion-into-sorted-array logic.
- **Book ✨:** Yu & Marut — Chapter 10 (arrays) covers array access patterns.
- **MVP reference:** The algorithm and updated record layout (8 bytes, `LB_DIFF EQU 5`) are described in MVP Chapter 4.4. Implement directly from there.
- **Critical:** The calling convention changed from v1.0 — `FILE_INSERT_SCORE` now takes `AL = difficulty byte` in addition to `DS:SI = name` and `BX = score`. Make sure `SCR_END_RUN` passes all three before calling.

---

# PART 3 — INTEGRATION KNOWLEDGE (ALL DEVS, DAY 4-5)

These are the concepts needed when you stop building in isolation and start wiring modules together.

## I1. Calling Conventions & Register Preservation ⭐
**Why:** When Dev A calls Dev B's procedure, whose responsibility is it to preserve registers? Our convention: **the callee preserves all registers it clobbers except explicit outputs** (documented per-procedure in MVP doc).

**MVP chapter unlocked:** All (integration)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 8 (procedures).
- **MVP ref ⭐:** Chapter 6.1 (Module Integration Contracts).
- **Rule of thumb:** Every `PROC` starts with `PUSH` of every register it modifies, ends with matching `POP`s in reverse order. Exceptions are documented.

## I2. Global Data Access Across Modules ⭐
**Why:** `CURRENT_STATE` is declared in `MAIN.ASM`, accessed from `STATE.ASM`. You use `PUBLIC` in the defining module and `EXTRN` in the consuming module.

**MVP chapter unlocked:** All modules (see `SHARED.INC`)

**Resources:**
- **Book ⭐:** Yu & Marut — Chapter 8 or 12 (multi-module programs).
- **MVP ref ⭐:** Chapter 2.2 / 3.1 show this pattern explicitly.
- **Pitfall ❌:** Forgetting `EXTRN VARNAME:BYTE` (or `:WORD`) causes linker errors. The size must match.

## I3. Debugging with TD (Turbo Debugger) ✨
**Why:** When (not if) things break, stepping through assembly is faster than `printf`-debugging. TD ships with TASM.

**MVP chapter unlocked:** Debugging any module

**Resources:**
- **Web ⭐:** Search "Turbo Debugger TD tutorial" — many quick intros. FenixFox's boilerplate repo uses TD in their `debug.bat` for reference.
- **Priority:** Medium. Learn on Day 4-5 when integration bugs appear. Not essential if you're lucky.

---

# 📅 Recommended Study Schedule

Aligned with the 7-day sprint from the MVP doc. 1 study hour per day.

| Day | All Devs (F-series) | Dev 1 (Lead) | Dev 2 (GFX/Input) | Dev 3 (Audio/File) |
|---|---|---|---|---|
| **1** | F1 setup, F2 registers, F3 skeleton | A1 data declaration | B1 INT 10h basics | C1 IN/OUT ports |
| **2** | F4 flow control, F5 stack | A2 state dispatch | B2 Mode 13h framebuffer | C2 PIT + speaker |
| **3** | F6 multi-module, F7 ASCII | A3 DOS I/O | B3 string instructions | C3 timing, C4 file I/O open/read |
| **4** | — | A4 BIOS timer, A5 num→ASCII, **A7 pointer tables** | B4 sprite render, B5 font | C4 cont., C5 error handling |
| **5** | I1, I2 (integration) | A6 string compare (opt) | B6 keyboard, B7 scancodes (opt) | C6 leaderboard insert + difficulty byte |
| **6** | I3 debugger (if needed) | Integration support | Integration support | Integration support |
| **7** | (Buffer day — likely no new learning) | — | — | — |

**Adjust for reality:** If you fall behind, prioritize ⭐ items and skip ✨ items entirely.

---

# 🚦 Self-Check Gates

Before starting each MVP chapter, confirm you can honestly say "yes" to these. If any are "no," go back and study.

### Before writing ANY module (Day 1-2):
- [ ] I can assemble + link + run a Hello World in DOSBox
- [ ] I know what `AX`, `DS`, `ES`, `SP` each do
- [ ] I can read `MOV AX, [BX+SI]` and describe what it does
- [ ] I know the difference between `JE` and `JA`
- [ ] I understand `PUSH`/`POP` must balance, and why

### Before writing your module (Day 2-3):
- [ ] I've read my MVP chapter (4.x or 5.x) end-to-end
- [ ] I can trace through the code sketch and explain each line
- [ ] I know which interrupts / ports / memory addresses I'll touch
- [ ] I know what my module's `PUBLIC` procedures' inputs/outputs are

### Before integration (Day 4-5):
- [ ] My module builds cleanly (no assembler warnings)
- [ ] My module passes a standalone smoke test
- [ ] I can run `BUILD.BAT` and link against the other modules
- [ ] I've confirmed my register preservation contract with teammates

---

# 🆘 If You Get Stuck

**Do this, in order:**

1. **Re-read the MVP doc chapter** for your module. Often the answer is there.
2. **Check the register and port references** in MVP Appendix A/B.
3. **Search the concept** on `chibiakumas.com` or `inightmare.org` — both are solid and concise.
4. **Ask the team.** Share a minimal code snippet + error message in your group chat.
5. **Ask the AI coach (me).** Drop the failing snippet + what you expected vs got. I can usually debug in 1-2 replies.

**Don't:**
- Spend >30 minutes stuck on one issue without asking. Speedrun means unblocking fast.
- Copy code you don't understand. If you ship code you can't explain, your prof may penalize you — and you won't be able to debug it if it breaks.
- Go down Stack Overflow rabbit holes for 32-bit x86 — we're 16-bit only. Results for 32-bit/Linux syntax will mislead you.

---

# 🎯 One Final Principle

**You don't need to "learn assembly." You need to learn enough of 8 specific topics to ship a specific game.** The difference is hours vs months.

Every time you open a book or a tutorial, ask: *"Does this help me write code in my assigned MVP chapter?"* If yes, read. If no, close the tab. Move on.

**Version:** 1.1 — Difficulty modes revision
**Changes from v1.0:** Added concept A7 (pointer tables / indirect addressing) to Track A; updated C6 to document new `FILE_INSERT_SCORE` calling convention (difficulty byte); updated study schedule table; added spriter workload note (30 sprites).
**Companion doc:** `SPELLING_GAME_MVP.md` v1.1

---

# 📎 Quick Resource Index

### Books (downloadable PDFs)
- **Yu & Marut** — *Assembly Language Programming and Organization of the IBM PC* (1992)
  Search academia.edu: `"Ytha Yu" "Assembly Language Programming"`
- **Hyde** — *The Art of Assembly Language* (DOS/16-bit edition)
  `https://www.plantation-productions.com/Webster/www.artofasm.com/DOS/index.html`

### Video Series
- **ChibiAkumas 8086 playlist** — `https://www.chibiakumas.com/8086/` (text + video)
- **ChibiAkumas YouTube** — `https://www.youtube.com/c/ChibiAkumas/playlists`

### Web Tutorials
- **INightmare's Blog** — `https://devdocs.inightmare.org/` (Mode 13h, DOS file I/O)
- **FenixFox Studios** — `https://fenixfox-studios.com/` (VGA, PC speaker)
- **Gavin's Guide, Part 5** — `https://stuff.pypt.lt/ggt80x86a/asm6.htm` (file I/O)
- **Yassine Bridi Interrupt Ref** — `https://yassinebridi.github.io/asm-docs/`
- **Care4you INT 21h** — `https://care4you.in/int-21h-dos-interrupt/`

### GitHub Code References
- **Yu & Marut exercise solutions** — `github.com/shawon100/Assembly-8086`
- **Working Mode 13h example (NASM)** — `github.com/amrwc/8086-graphics`
- **PC Speaker music project** — `github.com/KriAga/8086-Microprocessor---Music`
