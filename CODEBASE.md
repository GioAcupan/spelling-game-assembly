# Spelling Game — Codebase Overview

A high-level tour of the spelling game: an educational DOS game for toddlers built in 8086 assembly. Kids see a picture, hear a word, and type the spelling. The game runs in DOSBox using VGA Mode 13h graphics and PC speaker audio.

---

## 1. How the Game Works

### The Big Picture

The game is a **state machine** cycling through 11 screens. At the center is a dispatcher called `GAME_TICK` that reads a `CURRENT_STATE` byte and calls the right screen handler. Each handler does its job (show a title, run a spelling round, display the leaderboard) then writes the next state before returning. A tight loop in `MAIN.ASM` keeps calling `GAME_TICK` until the state becomes `STATE_QUIT`.

```
TITLE → LOGIN → MODE → NAME → DIFF → INSTR → ROUND ⇄ JUDGE → SCORE → END → QUIT
```

The modules fall into six natural groups:

| Group | Modules | What they do |
|---|---|---|
| **Game Loop & State** | `MAIN.ASM`, `STATE.ASM` | Program entry point, runtime variables, state dispatch |
| **Graphics** | `GFX.ASM` | VGA setup, sprites, fonts, backgrounds |
| **Input** | `INPUT.ASM` | Keyboard reading via BIOS interrupts |
| **Audio** | `AUDIO.ASM` | PC speaker tones and jingles |
| **File I/O** | `FILEIO.ASM` | Saving/loading leaderboard and user accounts to disk |
| **Data** | `DATA.ASM` | All static assets: words, sprites, sounds, strings |
| **Screens** | `SCRINTRO.ASM`, `SCR_GAME.ASM`, `SCR_END.ASM` | The 8 screen handlers that make up the actual game flow |

### 1.1 How does the main game mechanic work?

The player picks a difficulty (Easy/Medium/Hard), then enters a loop of spelling rounds:

1. **A sprite is drawn** on screen — a picture of the word (e.g. a cat, an apple, a chicken).
2. **A scrambled hint is shown** — the letters of the word rearranged (e.g. "PAPEL" for APPLE).
3. **A sound cue plays** — a short ascending tone pattern unique to each word.
4. **The player types their answer.** The game times how long they take (using the BIOS tick counter).
5. **Judging:** If correct, the player earns `max(100 − ticks×2, 10)` points. If wrong, they lose a heart.
6. **The round repeats** with the next word until all 10 words in the tier are done, or any player runs out of hearts (3 max).
7. **Scores are shown**, then the player's best score is inserted into a persistent top-5 leaderboard.

In two-player mode, both players alternate on the same keyboard. Each answers the same word in turn, and scores are compared side-by-side.

The word for each round is selected by a global index: `DIFFICULTY × 10 + CURRENT_WORD`. This index pulls the correct word, its scrambled version, its sprite, and its sound pattern — all from parallel tables in `DATA.ASM`.

### 1.2 How does the game draw sprites and backgrounds?

**Backgrounds** are pre-rendered 320×200 pixel images stored as raw `.BIN` files (exactly 64,000 bytes each — one byte per pixel in VGA's 256-color palette). `GFX_LOAD_BG` opens the file via DOS and reads it directly into video memory at segment `A000h`. This is a raw framebuffer dump — no compression, no headers.

**Sprites** are 32×32 pixel arrays (1,024 bytes each) embedded directly in `DATA.ASM`. `GFX_DRAW_SPRITE` walks the array row by row and column by column, writing each byte to video memory. A palette index of **255 means transparent** — the renderer skips those pixels, leaving the background visible underneath. The framebuffer offset math uses `y×320 + x`, optimized as `y×256 + y×64 + x` to avoid slow multiplication.

**Text** is drawn with a custom 8×8 bitmap font. `GFX_DRAW_CHAR` maps an ASCII character to a glyph index (40 glyphs total: space, `!`, `.`, digits, `?`, A-Z), then renders the glyph one bit at a time. A `1` bit draws a pixel in the chosen color; a `0` bit leaves the background untouched. `GFX_DRAW_STRING` chains `GFX_DRAW_CHAR` calls, advancing the X cursor by 8 pixels per character and wrapping to the next line at the screen edge.

The **VGA palette** is 256 colors defined in `GFX.ASM` as 768 bytes (3 bytes per color: red, green, blue, each 0–63). It's programmed into the VGA DAC at startup via ports `3C8h`/`3C9h`.

### 1.3 How does the game play sounds?

All audio comes through the **PC speaker**, driven by the Intel 8253 Programmable Interval Timer (PIT). There is no Sound Blaster or digital audio.

`SND_PLAY_TONE` takes a frequency in Hertz and programs PIT channel 2 to generate a square wave at that pitch. The divisor is `1,193,180 ÷ frequency` (the PIT's base clock rate). It then enables the speaker via bit 0 of port `61h`. The tone plays continuously until `SND_SILENCE` clears that bit.

`SND_PLAY_PATTERN` plays a sequence of notes. A pattern is an array of `(frequency, duration_ms)` pairs, terminated by a `DW 0`. Each note is: play tone → wait → silence → 30ms gap. The gap prevents notes from bleeding into each other.

Sound data lives in `DATA.ASM`:
- **30 per-word sound cues** — 2 to 4 ascending tones depending on difficulty
- **Jingles** — title fanfare (C-E-G-C), win fanfare, lose descending line
- **SFX** — correct (ascending major third), wrong (descending minor third)

### 1.4 How does the game handle input?

All keyboard input goes through three thin wrappers around BIOS interrupt `INT 16h`:

- **`INP_WAIT_KEY`** — Blocks until a key is pressed. Returns the ASCII character and scan code.
- **`INP_CHECK_KEY`** — Non-blocking check. Returns immediately with or without a key.
- **`INP_READ_STRING`** — Reads a full line into a buffer. Converts lowercase to uppercase. Handles backspace (decrements buffer pointer). Terminates on Enter with a null byte. Does **not** echo to screen — callers in graphics mode must draw characters themselves.

For on-screen text entry (name input, spelling answers), the screen modules use `SCI_ECHO_INPUT` (in `SCRINTRO.ASM`) or inline loops that pair `INP_WAIT_KEY` with `GFX_DRAW_CHAR`. Before drawing each character, these routines **save the 8×8 pixel block** from video memory. On backspace, they restore the saved background — avoiding permanent black rectangles where deleted characters used to be.

### 1.5 How do the modules connect?

```
                    MAIN.ASM
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
       GFX_INIT  FILE_LOAD  USER_LOAD
            │          │          │
            └──────────┼──────────┘
                       ▼
                 GAME_TICK (STATE.ASM)
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    SCRINTRO.ASM   SCR_GAME.ASM   SCR_END.ASM
         │             │             │
         └─────────────┼─────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
      GFX.ASM     INPUT.ASM     AUDIO.ASM    FILEIO.ASM
                                              (score save at end)
```

The **service modules** (GFX, INPUT, AUDIO, FILEIO) are independent of each other. They only talk to DOS/BIOS/hardware — never to one another.

The **screen modules** (SCRINTRO, SCR_GAME, SCR_END) call into the service modules but never call each other. They all read and write the shared runtime state variables in `MAIN.ASM`.

All compile-time constants (`STATE_TITLE`, `MAX_HEARTS`, `SPRITE_SIZE`, etc.) are centralized in `SHARED.INC`, which every module includes.

### 1.6 How is data stored?

**Static game data** lives in `DATA.ASM` — a code-free module containing only `.DATA` section declarations. This includes all 30 words, their scrambled forms, 30 sprite images (~30 KB), 30 sound patterns, jingles, SFX, UI strings, and background filenames. Everything is `PUBLIC` so other modules can reference it.

**Runtime state** lives in `MAIN.ASM`'s `.DATA` section. This is the game's working memory: current state, player count, difficulty, scores, hearts, input buffer, leaderboard, user table, etc. All variables are `PUBLIC` so screen handlers can read and modify them.

**Persistent data** uses two DOS files managed by `FILEIO.ASM`:

| File | Format | Contents |
|---|---|---|
| `SCORES.DAT` | 40 bytes (5 × 8) | Top-5 leaderboard: name(3) + score(2) + difficulty(1) + padding(2) per entry |
| `USERS.DAT` | Variable (max 5 × 8) | User accounts: name(3) + password(5) per entry |

Both files are plain binary — no headers, no separators. `FILE_LOAD_SCORES` reads `SCORES.DAT` at startup; `FILE_SAVE_SCORES` writes it when a game ends. User accounts are loaded at startup and saved after a new user registers.

---

## 2. Module-by-Module Tour

### 2.1 MAIN.ASM — Entry Point & Runtime State

The program's starting point and the owner of all mutable game state. It initializes the graphics, loads persistent data, then enters the main loop that calls `GAME_TICK` forever.

```asm
MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX
    CALL GFX_INIT
    CALL FILE_LOAD_SCORES
    CALL USER_LOAD
GAME_LOOP:
    CALL GAME_TICK
    CMP  CURRENT_STATE, STATE_QUIT
    JNE  GAME_LOOP
    CALL GFX_SHUTDOWN
    MOV  AX, 4C00h
    INT  21h
MAIN ENDP
```

This is the entire program lifecycle in 12 instructions: set up data segment → init graphics → load scores and users → run game ticks until quit → restore text mode → exit to DOS. All complexity lives inside `GAME_TICK` and the handlers it calls.

The `.DATA` section here owns ~20 global variables: `CURRENT_STATE`, `NUM_PLAYERS`, `DIFFICULTY`, `CURRENT_WORD`, `SCORES` (2 words), `HEARTS_ARR` (2 bytes), `LEADERBOARD` (40 bytes), `USER_TABLE`, `INPUT_BUFFER`, and others. Every screen handler reads and writes these directly.

### 2.2 STATE.ASM — State Dispatcher

A single public procedure, `GAME_TICK`, that reads `CURRENT_STATE` and jumps to the matching handler via a chain of comparisons:

```asm
GAME_TICK PROC
    CMP  CURRENT_STATE, STATE_TITLE
    JNE  GT_CHECK_LOGIN
    CALL SCR_TITLE_RUN
    RET
GT_CHECK_LOGIN:
    CMP  CURRENT_STATE, STATE_LOGIN
    JNE  GT_CHECK_MODE
    CALL SCR_LOGIN_RUN
    RET
    ; ... one CMP/JNE/CALL/RET block per state ...
```

Ten compare-and-dispatch blocks, one per state. Unrecognized states fall through to `RET` — a safe no-op. This is the simplest possible dispatcher: no jump tables, no computed addressing, just linear comparison. It works because there are only 11 states and each handler call is cheap.

### 2.3 GFX.ASM — Graphics Engine

The entire visual layer. Seven public procedures covering initialization, sprite rendering, font rendering, and background loading.

**Sprite drawing with transparency** is the most performance-sensitive routine:

```asm
GFX_DRAW_SPRITE PROC
    ; DS:SI = sprite data, BX = X, DX = Y
    MOV  AX, DX
    SHL  AX, 6
    ADD  AX, DX
    MOV  DI, AX
    SHL  DI, 1
    SHL  DI, 1
    ADD  DI, BX           ; DI = Y*320 + X
    MOV  AX, 0A000h
    MOV  ES, AX
    MOV  DX, 32           ; row counter
GDS_ROW:
    MOV  CX, 32           ; column counter
GDS_COL:
    LODSB                 ; load pixel from sprite data
    CMP  AL, 255          ; transparency sentinel?
    JE   GDS_SKIP         ; yes — skip, leaving background
    STOSB                 ; no — write to framebuffer
    JMP  GDS_NEXT
GDS_SKIP:
    INC  DI               ; advance framebuffer without writing
GDS_NEXT:
    LOOP GDS_COL
    ADD  DI, 320-32       ; move to next row
    DEC  DX
    JNZ  GDS_ROW
    RET
GFX_DRAW_SPRITE ENDP
```

The framebuffer offset formula is `Y×320 + X`, computed with shifts: `Y×64 + Y×256 + X`. Color index 255 is the universal "don't draw" sentinel — every sprite exporter in the asset pipeline uses it. The routine walks all 1,024 pixels (32 rows × 32 columns) and writes only opaque ones.

**Background loading** bypasses the data segment entirely:

```asm
GFX_LOAD_BG PROC
    ; DS:DX = filename
    MOV  AX, 3D00h        ; DOS open file, read-only
    INT  21h
    MOV  BG_HANDLE, AX
    MOV  BX, AX
    PUSH DS
    MOV  AX, 0A000h
    MOV  DS, AX           ; temporarily point DS at VRAM
    MOV  DX, 0
    MOV  CX, 64000
    MOV  AH, 3Fh          ; DOS read file
    INT  21h
    POP  DS
    ; ... close file ...
```

The trick: DOS file read expects the buffer at `DS:DX`. Since the target is video memory, the routine momentarily swaps `DS` to `A000h` so the 64,000-byte read lands directly in the framebuffer — no intermediate copy.

### 2.4 INPUT.ASM — Keyboard Input

Three thin wrappers around BIOS keyboard services. The buffered string reader is the most complex:

```asm
INP_READ_STRING PROC
    ; ES:DI = buffer, CX = max length
    XOR  BX, BX           ; BX = current length
IRS_LOOP:
    CALL INP_WAIT_KEY     ; blocks until keypress, returns AL=ASCII
    CMP  AL, 13           ; Enter?
    JE   IRS_DONE
    CMP  AL, 8            ; Backspace?
    JE   IRS_BACK
    CMP  BX, CX           ; buffer full?
    JAE  IRS_LOOP         ; ignore
    CMP  AL, 'a'
    JB   IRS_STORE
    CMP  AL, 'z'
    JA   IRS_STORE
    SUB  AL, 32           ; lowercase → uppercase
IRS_STORE:
    MOV  ES:[DI+BX], AL
    INC  BX
    JMP  IRS_LOOP
IRS_BACK:
    TEST BX, BX
    JZ   IRS_LOOP         ; nothing to delete
    DEC  BX
    JMP  IRS_LOOP
IRS_DONE:
    MOV  BYTE PTR ES:[DI+BX], 0   ; null-terminate
    MOV  CX, BX           ; return actual length in CX
    RET
INP_READ_STRING ENDP
```

This is a pure buffer manager. It maintains `BX` as a write cursor, converts lowercase to uppercase (since the game only deals in uppercase), ignores input when the buffer is full, and silently drops backspace when the buffer is empty. Critically, it does **no screen drawing** — graphics-mode callers handle echo themselves so they can position text anywhere on screen.

### 2.5 AUDIO.ASM — PC Speaker Audio

Four procedures that turn the PC's internal speaker into a simple synthesizer.

```asm
SND_PLAY_TONE PROC
    ; BX = frequency in Hz
    MOV  AX, 34DDh        ; DX:AX = 1,193,180 (PIT clock)
    MOV  DX, 0012h
    DIV  BX               ; AX = divisor = 1193180 / freq
    MOV  BX, AX
    MOV  AL, 0B6h         ; PIT channel 2, mode 3 (square wave)
    OUT  43h, AL
    MOV  AX, BX
    OUT  42h, AL          ; divisor low byte
    MOV  AL, AH
    OUT  42h, AL          ; divisor high byte
    IN   AL, 61h
    OR   AL, 03h          ; enable speaker (bits 0-1)
    OUT  61h, AL
    RET
SND_PLAY_TONE ENDP
```

The PIT (Programmable Interval Timer) runs at ~1.19 MHz. Dividing that clock by the desired frequency gives the counter value that produces a square wave at that pitch. Writing to port `43h` configures channel 2, then port `42h` receives the divisor. Port `61h` bit 0 gates the speaker on.

`SND_PLAY_PATTERN` iterates through an array of `(freq, duration)` pairs, calling `SND_PLAY_TONE` → `SND_DELAY` → `SND_SILENCE` → 30ms gap for each note. A zero frequency terminates the pattern.

### 2.6 FILEIO.ASM — Score & User Persistence

Manages two binary files through DOS INT 21h file operations. The leaderboard insert is the most interesting routine:

```asm
FILE_INSERT_SCORE PROC
    ; DS:SI = player name, BP = score, DL = difficulty
    MOV  CX, LB_MAX_ENTRIES
    XOR  BX, BX           ; BX = entry index
FIS_FIND:
    CMP  BYTE PTR [LEADERBOARD+BX], 0  ; empty slot?
    JE   FIS_SHIFT
    PUSH BX
    MOV  AX, WORD PTR [LEADERBOARD+BX+3]  ; existing score
    CMP  BP, AX           ; our score > existing?
    JA   FIS_SHIFT_POP    ; yes — insert here
    POP  BX
    ADD  BX, LB_ENTRY_SIZE
    LOOP FIS_FIND
    RET                   ; not good enough for top 5
FIS_SHIFT_POP:
    POP  BX
FIS_SHIFT:
    ; shift entries down from bottom, insert at BX
    ; ... copy name(3) + score(2) + difficulty(1) ...
```

The leaderboard is always kept sorted descending. To insert a new score, the routine walks from top to bottom, finds the first entry the new score beats (or an empty slot), shifts all lower entries down by 8 bytes, and writes the new record. The bottom entry falls off if the board is full.

User authentication (`USER_AUTH`) follows the same pattern: linear scan through `USER_TABLE` comparing 3-byte usernames with `REPE CMPSB`, then 5-byte passwords. Returns a status code: OK, new user registered, wrong password, or table full.

### 2.7 DATA.ASM — Static Game Assets

A `.CODE`-less module. Every symbol is `PUBLIC` data. It contains:

- **30 words** across 3 tiers, each padded to 16 bytes with zeros
- **TIER_TABLE** — a 3-entry pointer array (`DW EASY_WORDS, MED_WORDS, HARD_WORDS`) for difficulty-indexed lookup
- **30 scrambled words** — hardcoded anagrams of each word
- **30 sprites** — 1,024 bytes each of raw 32×32 pixel data (color 255 = transparent)
- **30 sound patterns** — per-word tone sequences
- **3 jingles + 2 SFX** — title, win, lose, correct, wrong
- **~15 UI strings** — labels like "YOUR TURN!", "HINT:", difficulty names, player banners
- **11 background filenames** — `.BIN` paths for each screen

A representative excerpt showing the table structure:

```asm
TIER_TABLE DW EASY_WORDS, MED_WORDS, HARD_WORDS

EASY_WORDS DB 'CAT', 13 DUP(0)
           DB 'DOG', 13 DUP(0)
           DB 'EGG', 13 DUP(0)
           ; ... 7 more ...

MED_WORDS  DB 'APPLE', 11 DUP(0)
           DB 'GRAPE', 11 DUP(0)
           ; ... 8 more ...

HARD_WORDS DB 'ORANGE', 9 DUP(0)
           DB 'SCHOOL', 9 DUP(0)
           ; ... 8 more ...

SCRAMBLE_TABLE:
           DB 'ATC', 13 DUP(0)      ; CAT
           DB 'OGD', 13 DUP(0)      ; DOG
           ; ... 28 more ...
```

All parallel arrays are indexed by `DIFFICULTY × 10 + CURRENT_WORD` so the correct word, scramble, sprite, and sound are always in lockstep.

### 2.8 SCRINTRO.ASM — Pre-Game Screens

Six screen handlers that walk the player from title to gameplay: `SCR_TITLE_RUN`, `SCR_LOGIN_RUN`, `SCR_MODE_RUN`, `SCR_NAME_RUN`, `SCR_DIFF_RUN`, `SCR_INSTR_RUN`.

Each follows the same pattern: clear screen → load background `.BIN` → draw any dynamic text → wait for user input → set next state. For example, the difficulty screen:

```asm
SCR_DIFF_RUN PROC
    MOV  CURRENT_STATE, STATE_DIFF
    CALL GFX_CLEAR
    MOV  DX, OFFSET BG_DIFF
    CALL GFX_LOAD_BG
SDR_WAIT:
    CALL INP_WAIT_KEY
    CMP  AL, '1'
    JE   SDR_EASY
    CMP  AL, '2'
    JE   SDR_MED
    CMP  AL, '3'
    JE   SDR_HARD
    JMP  SDR_WAIT
SDR_EASY:
    MOV  DIFFICULTY, DIFF_EASY
    JMP  SDR_NEXT
; ... MED and HARD set DIFFICULTY similarly ...
SDR_NEXT:
    MOV  CURRENT_STATE, STATE_INSTR
    RET
SCR_DIFF_RUN ENDP
```

The module also provides `SCI_ECHO_INPUT`, a shared text-entry routine used by the login, name, and mode screens. It pairs `INP_WAIT_KEY` with `GFX_DRAW_CHAR` and maintains a 5-slot background save buffer so backspace restores the original background pixels instead of leaving black holes.

### 2.9 SCR_GAME.ASM — Gameplay & Judging

Two large handlers: `SCR_ROUND_RUN` (the spelling round) and `SCR_JUDGE_RUN` (scoring and heart management). Together they implement the core gameplay loop.

`SCR_ROUND_RUN` selects the current word from the tier, loads the round background, draws the sprite at (144, 35), shows the scramble hint, plays the word's sound cue, then enters a per-player input loop:

```asm
    ; After drawing sprite, scramble, and labels...
    MOV  AH, 00h
    INT  1Ah               ; CX:DX = BIOS tick count
    MOV  PLAYER_TIMES[BP], DX   ; record start time
SRR_INPUT_LOOP:
    CALL INP_WAIT_KEY
    CMP  AL, 13            ; Enter = submit
    JE   SRR_CHECK
    CMP  AL, 8             ; Backspace
    JE   SRR_BACKSPACE
    ; ... upcase, store in INPUT_BUFFER, save BG, draw char ...
    JMP  SRR_INPUT_LOOP
SRR_CHECK:
    MOV  BYTE PTR [INPUT_BUFFER+BX], 0   ; null-terminate
    ; ... compare INPUT_BUFFER vs correct word ...
```

The timing is particularly neat: it snapshots the BIOS tick counter before input starts, and on a correct answer subtracts the current tick count to get elapsed time. The score formula `100 − ticks×2` (minimum 10) rewards faster answers.

`SCR_JUDGE_RUN` handles both 1P and 2P modes. In 1P, it shows a full-screen result per player ("YES!" or "OOPS!") with updated scores and hearts. In 2P, both results share one screen with a vertical divider at X=158. After judging, it checks end conditions: any player at 0 hearts, or all 10 words used — either sends the game to the score screen.

### 2.10 SCR_END.ASM — Score Screen & Leaderboard

Two handlers: `SCR_SCORE_RUN` displays the final tally, and `SCR_END_RUN` manages the persistent leaderboard.

`SCR_SCORE_RUN` chooses the right background (`SCORE1.BIN` or `SCORE2.BIN`), plays a win or lose jingle based on remaining hearts, and renders player names with their scores and "PTS" labels. In 2P mode it also declares a winner or a tie.

`SCR_END_RUN` inserts the player's score into the in-memory leaderboard via `FILE_INSERT_SCORE`, persists it with `FILE_SAVE_SCORES`, then renders the top 5 entries:

```asm
    ; Render each leaderboard entry
    MOV  CX, LB_MAX_ENTRIES
    XOR  SI, SI            ; SI = byte offset into LEADERBOARD
SER_ENTRY:
    CMP  BYTE PTR [LEADERBOARD+SI], 0   ; empty entry?
    JE   SER_SKIP
    ; Draw name at (82, row)
    ; Draw " | " separator
    ; Draw score as decimal
    ; Draw " | " separator
    ; Draw difficulty letter (E/M/H)
SER_SKIP:
    ADD  SI, LB_ENTRY_SIZE
    INC  row_counter
    LOOP SER_ENTRY
```

After displaying the leaderboard, any keypress sets `CURRENT_STATE = STATE_QUIT`, the game loop in MAIN exits, and the program returns to DOS.

---

## Toolchain & Conventions

- **Assembler:** Borland TASM 4.1 (not MASM/NASM/TASM 5.x)
- **Linker:** TLINK
- **Memory model:** `.MODEL SMALL` — one 64 KB code segment, one 64 KB data segment
- **Graphics:** VGA Mode 13h — 320×200 pixels, 256 colors, linear framebuffer at `A000:0000`
- **Build:** `BUILD.BAT` (run inside DOSBox) assembles each `.ASM` with `TASM /isrc`, links with `TLINK`, produces `bin\SPELL.EXE`
- **Module boundaries:** `PUBLIC`/`EXTRN` declarations cross-checked by the `integration-checker` agent before linking
- **Register safety:** Every `PROC` lists preserved registers in its header comment; callers can rely on those guarantees
