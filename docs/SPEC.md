# 🎮 Spelling Game — MVP Implementation Document

> **Project:** Educational Spelling Game for Toddlers
> **Platform:** Intel 8086 (16-bit Real Mode) via DOSBox
> **Toolchain:** TASM 4.1 + TLINK
> **Team:** 3 devs + 1 spriter
> **Timeline:** 1-week sprint (3-week deadline buffer)
> **Document Purpose:** Single Source of Truth for implementation. Every dev reads Chapters 1 & 2. Each dev reads their assigned Chapter 3+ module before coding.

---

## Table of Contents

- **Chapter 1 — High-Level System Architecture** *(read first, everyone)*
  - 1.1 What the Game Does
  - 1.2 The Five Subsystems
  - 1.3 Game State Machine
  - 1.4 Data Flow
  - 1.5 Runtime Environment & Memory Map
  - 1.6 Key Design Decisions (and Why)
- **Chapter 2 — Code Modules & File Structure** *(read first, everyone)*
  - 2.1 File Layout
  - 2.2 Module Responsibilities
  - 2.3 Module Interaction Map
  - 2.4 Team Workload Assignment
  - 2.5 Build System
- **Chapter 3 — Core Engine Modules** *(technical)*
  - 3.1 `MAIN.ASM` — Entry Point & Game Loop
  - 3.2 `STATE.ASM` — Game State Machine
  - 3.3 `DATA.ASM` — Word List & Assets
- **Chapter 4 — I/O Modules** *(technical)*
  - 4.1 `INPUT.ASM` — Keyboard Input
  - 4.2 `GFX.ASM` — Graphics (Mode 13h Sprite Rendering)
  - 4.3 `AUDIO.ASM` — PC Speaker Sound Cues
  - 4.4 `FILEIO.ASM` — Leaderboard Persistence
- **Chapter 5 — Screen Modules** *(technical)*
  - 5.1 `SCR_INTRO.ASM` — Title + Name Entry + Instructions
  - 5.2 `SCR_GAME.ASM` — Main Gameplay Screen
  - 5.3 `SCR_END.ASM` — Score + Leaderboard + Game Over
- **Chapter 6 — Integration & Testing**
  - 6.1 Module Integration Contracts
  - 6.2 Testing Strategy
  - 6.3 Known Risks & Mitigations
- **Appendices**
  - A. TASM Cheatsheet
  - B. Interrupt Quick Reference
  - C. Glossary

---

# 🎯 Preamble — Key Decisions Locked In

Before diving in, these decisions are **final** and reflected throughout the doc. If any of them need revisiting, flag it before devs start coding.

| Decision | Choice | Rationale |
|---|---|---|
| **Code organization** | Multiple `.ASM` files linked into one `.EXE` | Enables parallel dev work; isolates bugs; mandatory for 3-dev team |
| **Memory model** | `.MODEL SMALL` | One 64KB code segment, one 64KB data segment — more than enough |
| **Graphics mode** | VGA Mode 13h (320×200, 256 colors) | Industry-standard 8086 graphics mode; simple linear framebuffer at `A000h` |
| **Audio approach** | **PC Speaker beeps/tones** | Senior project used the same — confirmed-passing bar. Sound Blaster DAC is scope creep. |
| **Difficulty modes** | **3 tiers: Easy / Medium / Hard** (word-length based) | Required by prof |
| **Object count** | **10 words per tier = 30 total** (Easy: short, Medium: mid, Hard: long) | Prof required more words; word-length tiers are the difficulty axis |
| **Word list architecture** | **Option A: 3 separate arrays** (`EASY_WORDS`, `MED_WORDS`, `HARD_WORDS`) | Simpler pointer math than flat-list-with-tags; no searching needed |
| **Name input length** | 3 characters (arcade-style) | Matches spec |
| **Starting hearts** | 3 | Standard game feel |
| **Leaderboard size** | Top 5 entries per difficulty tier, stored in `SCORES.DAT` | Prof wants difficulty on leaderboard |
| **Leaderboard record** | Name (3B) + Score (2B) + Difficulty (1B) + padding = 8B per entry | Stores difficulty for display: `AAA \| 240pts \| HARD` |
| **Character encoding** | ASCII uppercase only | Simpler comparison logic; toddler-friendly |

---

# Chapter 1 — High-Level System Architecture

## 1.1 What the Game Does

The game is a **state-machine driven application** that cycles through distinct screens. At its core, it's a loop that:

1. Shows the player a **picture** of an object (e.g., apple).
2. Plays a **sound cue** (an audio pattern recognizable as that object).
3. Waits for the player to **type the spelling**.
4. **Compares** input to the correct answer.
5. Updates **score** (based on speed) or **hearts** (on wrong answer).
6. Repeats with the next object, or ends the game.

Around this core loop, there's an **intro flow** (title → name entry → instructions) and an **end flow** (final score → leaderboard → game over). Between rounds, the game saves high scores to disk so they persist across sessions.

Think of it as **6 screens connected by a state machine**, with 4 reusable I/O services (graphics, audio, keyboard, file) that each screen calls into.

## 1.2 The Five Subsystems

The codebase is organized into five conceptual layers. Everything we build maps into one of these:

```
┌─────────────────────────────────────────────────────────────┐
│                    GAME LOGIC LAYER                         │
│   (Screens, State Machine, Word List, Score, Hearts)        │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   GRAPHICS    │  │    AUDIO      │  │    INPUT      │
│ (Mode 13h     │  │ (PC Speaker   │  │ (Keyboard via │
│  sprite draw) │  │  tones)       │  │  INT 16h)     │
└───────────────┘  └───────────────┘  └───────────────┘
                            │
                            ▼
                   ┌───────────────┐
                   │  FILE I/O     │
                   │ (Leaderboard  │
                   │  via INT 21h) │
                   └───────────────┘
                            │
                            ▼
                   ┌───────────────┐
                   │  DOS / BIOS   │
                   │  (OS Services)│
                   └───────────────┘
```

**Subsystem roles:**

- **Game Logic Layer** — Knows the *rules* (what's a correct answer, when to lose a heart). Owns game state. Decides what screen comes next.
- **Graphics Subsystem** — Knows how to put pixels on screen. Has no idea what an "apple" is; just draws whatever sprite data it's handed.
- **Audio Subsystem** — Knows how to make the speaker beep at a frequency for a duration. Has no idea about spelling.
- **Input Subsystem** — Knows how to read the keyboard. Returns characters; doesn't judge them.
- **File I/O Subsystem** — Knows how to read/write files. Doesn't care about score semantics.

**Why this separation matters:** Each dev can work on their subsystem independently. When you're writing audio, you don't need to know anything about sprites. When you're writing the game loop, you just call `CALL PLAY_APPLE_SOUND` and trust it works.

## 1.3 Game State Machine

The entire program is one big state machine. At any moment, the game is in exactly **one state**, and transitions to another state based on events (key press, time elapsed, conditions met).

```
       ┌──────────────┐
       │ STATE_TITLE  │  ◄───────── program entry
       └──────┬───────┘
              │  [any key]
              ▼
       ┌──────────────┐
       │  STATE_NAME  │  (type 3-char name)
       └──────┬───────┘
              │  [ENTER after 3 chars]
              ▼
       ┌──────────────┐
       │  STATE_DIFF  │  (select Easy / Medium / Hard)   ← NEW
       └──────┬───────┘
              │  [1 / 2 / 3 key]
              ▼
       ┌──────────────┐
       │ STATE_INSTR  │  (show "type what you hear")
       └──────┬───────┘
              │  [any key]
              ▼
       ┌──────────────┐
       │ STATE_ROUND  │  ◄─── loops for each word in selected tier
       └──────┬───────┘
              │  [answer submitted]
              ▼
       ┌──────────────┐
       │ STATE_JUDGE  │  (right/wrong feedback, brief)
       └──────┬───────┘
              │
     ┌────────┴────────┐
     │                 │
 hearts>0 AND       hearts=0 OR
 words left?      no words left?
     │                 │
     └──► STATE_ROUND  ▼
              ┌──────────────┐
              │  STATE_END   │  (score + leaderboard)
              └──────┬───────┘
                     │  [any key]
                     ▼
              ┌──────────────┐
              │  STATE_QUIT  │ ──► return to DOS
              └──────────────┘
```

**How it works in code:** A single byte in memory (`CURRENT_STATE`) holds the current state as a number (0 = title, 1 = name, 2 = difficulty, 3 = instructions, etc.). The main game loop checks this byte and calls the appropriate screen handler. Each screen handler updates the byte before returning, which changes where the game goes next iteration.

This pattern is called a **state dispatcher**. It's the backbone of the game.

## 1.4 Data Flow

Where does the data live, and how does it move?

```
┌─────────────────────────────────────────┐
│  DATA SEGMENT (static, known at compile)│
│  ─────────────────────────────────────  │
│  • EASY_WORDS:  "CAT", "DOG", ...  (10) │
│  • MED_WORDS:   "APPLE", "TRAIN",. (10) │
│  • HARD_WORDS:  "ORANGE", "BRIDGE" (10) │
│  • SPRITE_DATA: 30 sprites × 1KB each  │
│  • SOUND_PATTERNS: one array per word   │
│  • UI strings: "GAME OVER", etc.        │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  RUNTIME STATE (updated as game plays)  │
│  ─────────────────────────────────────  │
│  • CURRENT_STATE  (byte)                │
│  • DIFFICULTY     (byte: 0=E, 1=M, 2=H)│  ← NEW
│  • CURRENT_WORD   (index 0..9)          │
│  • PLAYER_NAME    (3 chars)             │
│  • SCORE          (word, 16-bit int)    │
│  • HEARTS         (byte, 0..3)          │
│  • TIMER_START    (word, BIOS ticks)    │
│  • INPUT_BUFFER   (up to 16 chars)      │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  PERSISTENT STORAGE (disk)              │
│  ─────────────────────────────────────  │
│  • SCORES.DAT  — top 5 leaderboard      │
│    Format: 5 × { name(3) + score(2)     │
│                 + difficulty(1) + pad } │
└─────────────────────────────────────────┘
```

## 1.5 Runtime Environment & Memory Map

When the `.EXE` runs under DOSBox, the machine looks like this:

- **CPU:** Emulated 8086, 16-bit registers, real mode (no memory protection).
- **RAM:** 640 KB conventional memory; we use a tiny fraction.
- **Video memory:** `A000:0000` (Mode 13h framebuffer, 64000 bytes = 320×200 pixels × 1 byte each).
- **BIOS data area:** `0040:006C` holds a timer that ticks 18.2 times per second — our scoring clock.
- **DOS services:** Accessed via `INT 21h` (file I/O, console I/O, exit).
- **BIOS services:** Accessed via `INT 10h` (video), `INT 16h` (keyboard).

**Our program's memory footprint (approximate):**

| Section | Size | Contents |
|---|---|---|
| Code segment | ~6-10 KB | All the `.ASM` modules compiled together |
| Data segment | ~32-35 KB | 30 sprites × ~1KB + word lists + strings + variables |
| Stack segment | 1 KB | Function call stack |
| **Total** | **~39-46 KB** | Within 64 KB `.MODEL SMALL` limit — tight but safe |

> ⚠️ **Data segment warning:** 30 sprites × 1024 bytes = 30,720 bytes. Add word lists (~480 bytes), sound patterns (~1KB), strings, and variables — total is ~33KB. Well under 64KB but worth keeping in mind. Do **not** increase sprite size to 64×64 without recalculating.

## 1.6 Key Design Decisions (and Why)

- **PC Speaker audio, not Sound Blaster.** Senior project did beeps and passed. Sound Blaster requires DMA programming, IRQ handling, and `.WAV` parsing — easily 3-5 days of work alone. We buy that time back and spend it on polish.
- **Mode 13h graphics, not text mode.** Prof wants real sprites. Mode 13h is the easiest pixel-graphics mode: one byte per pixel, linear layout, no planar headaches.
- **30 words across 3 difficulty tiers (10 each).** Prof required more words and difficulty modes. Word length defines difficulty: Easy = 3-4 letter words, Medium = 5-6 letters, Hard = 7+ letters. 30 sprites is a real spriter workload — flag immediately.
- **Option A word list architecture (3 separate arrays).** `EASY_WORDS`, `MED_WORDS`, `HARD_WORDS` as fixed-width arrays. `DIFFICULTY` byte selects which array to use. Zero searching, simple pointer math: `word_addr = TIER_BASE + (index × WORD_RECORD_SIZE)`.
- **Difficulty stored in leaderboard.** Each leaderboard entry includes a `DIFFICULTY` byte so the display screen can show `AAA | 240pts | HARD`.
- **Modular `.ASM` files.** A 3-dev team cannot work in one file without merge pain. The small cost of a build script is worth the parallelism.
- **State machine pattern.** Makes the game easy to debug (print the state, know where you are) and easy to extend (new screen = new state). Adding `STATE_DIFF` cost 10 lines.
- **Data-driven word list.** Words, sprites, and sounds are all in `DATA.ASM`. Adding a word means adding data, not code.

---

# Chapter 2 — Code Modules & File Structure

## 2.1 File Layout

```
spelling_game/
├── src/
│   ├── MAIN.ASM          ← Entry point + main loop
│   ├── STATE.ASM         ← State dispatcher + transitions
│   ├── DATA.ASM          ← Word list, sprite data, sound data
│   │
│   ├── GFX.ASM           ← Mode 13h graphics primitives
│   ├── AUDIO.ASM         ← PC speaker tone/pattern playback
│   ├── INPUT.ASM         ← Keyboard read routines
│   ├── FILEIO.ASM        ← Leaderboard file read/write
│   │
│   ├── SCR_INTRO.ASM     ← Title, name entry, instructions screens
│   ├── SCR_GAME.ASM      ← Round gameplay screen
│   ├── SCR_END.ASM       ← Score + leaderboard + game over
│   │
│   └── SHARED.INC        ← Shared constants, macros, EXTRN decls
│
├── assets/
│   ├── sprites/          ← PNG mockups from spriter (reference only)
│   └── sprite_bytes.txt  ← Exported raw byte arrays, paste into DATA.ASM
│
├── build/
│   ├── BUILD.BAT         ← Assemble + link all modules
│   └── CLEAN.BAT         ← Delete .OBJ and .EXE
│
├── bin/
│   ├── SPELL.EXE         ← The shipping executable
│   └── SCORES.DAT        ← Leaderboard save file (created at runtime)
│
└── docs/
    ├── SPELLING_GAME_MVP.md   ← This file
    └── STUDY_GUIDE.md         ← Dev learning roadmap
```

## 2.2 Module Responsibilities

Each module is a `.ASM` file with a well-defined role and exported procedures. The **exported procedures** (marked `PUBLIC`) are callable from other modules. Everything else is private to the file.

### Core Engine

| Module | Owns | Exports |
|---|---|---|
| `MAIN.ASM` | Program entry, global game loop | (none — it's the top level) |
| `STATE.ASM` | `CURRENT_STATE` byte, transition logic | `GAME_TICK` (called every loop iteration) |
| `DATA.ASM` | All static game data | Labels: `EASY_WORDS`, `MED_WORDS`, `HARD_WORDS`, `SPRITE_TABLE`, `SOUND_TABLE` |

### I/O Services

| Module | Owns | Exports |
|---|---|---|
| `GFX.ASM` | Video mode, drawing primitives | `GFX_INIT`, `GFX_CLEAR`, `GFX_DRAW_SPRITE`, `GFX_DRAW_TEXT`, `GFX_SHUTDOWN` |
| `AUDIO.ASM` | Speaker port control | `SND_PLAY_PATTERN`, `SND_SILENCE` |
| `INPUT.ASM` | Keyboard polling | `INP_WAIT_KEY`, `INP_CHECK_KEY`, `INP_READ_STRING` |
| `FILEIO.ASM` | Disk I/O for scores | `FILE_LOAD_SCORES`, `FILE_SAVE_SCORES` |

### Screen Handlers

| Module | Owns | Exports |
|---|---|---|
| `SCR_INTRO.ASM` | Title, name, difficulty select, instructions screens | `SCR_TITLE_RUN`, `SCR_NAME_RUN`, `SCR_DIFF_RUN`, `SCR_INSTR_RUN` |
| `SCR_GAME.ASM` | Round logic, scoring, judgment | `SCR_ROUND_RUN`, `SCR_JUDGE_RUN` |
| `SCR_END.ASM` | Score display, leaderboard | `SCR_END_RUN` |

### Shared

| Module | Contents |
|---|---|
| `SHARED.INC` | `EQU` constants (`STATE_TITLE=0`, `STATE_NAME=1`, `STATE_DIFF=2`, `STATE_INSTR=3`, `STATE_ROUND=4`, `STATE_JUDGE=5`, `STATE_END=6`, `STATE_QUIT=7`, `DIFF_EASY=0`, `DIFF_MED=1`, `DIFF_HARD=2`, `MAX_HEARTS=3`, `WORDS_PER_TIER=10`, `WORD_RECORD_SIZE=16`, `SPRITE_SIZE=1024`), macros, `EXTRN` declarations |

## 2.3 Module Interaction Map

Arrows mean "calls into":

```
                       MAIN.ASM
                          │
                          ▼
                      STATE.ASM ────► (reads CURRENT_STATE)
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
    SCR_INTRO         SCR_GAME          SCR_END
         │                │                │
         ├─► GFX          ├─► GFX          ├─► GFX
         ├─► INPUT        ├─► INPUT        ├─► INPUT
         │                ├─► AUDIO        ├─► FILEIO
         │                ├─► FILEIO       │
         │                └─► DATA         │
         │                                 │
         └─► (all screens read DATA for strings)
```

**Dependency rules:**

- Screen modules (`SCR_*`) depend on service modules (`GFX`, `AUDIO`, `INPUT`, `FILEIO`) and `DATA`.
- Service modules are **independent** of each other. `GFX` doesn't call `AUDIO`; `AUDIO` doesn't call `INPUT`.
- `STATE.ASM` calls into screen modules but screen modules only *update* the state byte (they don't call back into `STATE`).
- `DATA.ASM` is pure data — no code, no calls.

This is a **layered architecture**. Upper layers call lower layers; lower layers never call upward.

## 2.4 Team Workload Assignment

Proposed split (2 effective devs over 7 days = ~28 dev-hours, spriter in parallel):

### 🧑‍💻 Dev 1 — Lead (You)
- `MAIN.ASM`, `STATE.ASM`, `SHARED.INC`
- `SCR_INTRO.ASM`, `SCR_GAME.ASM`, `SCR_END.ASM`
- Integration, final debugging
- **~15 hours total**
- *Reasoning:* Lead owns the spine of the program and glues subsystems together. Needs deepest understanding of the whole system.

### 🧑‍💻 Dev 2 — Graphics + Input
- `GFX.ASM` (Mode 13h, sprite draw, text draw)
- `INPUT.ASM` (keyboard routines)
- **~7 hours total**
- *Reasoning:* Graphics is the biggest single-module effort. Input pairs naturally (both are BIOS-interrupt focused).

### 🧑‍💻 Dev 3 — Audio + File I/O
- `AUDIO.ASM` (PC speaker patterns)
- `FILEIO.ASM` (leaderboard load/save)
- **~6 hours total**
- *Reasoning:* Both are smaller, self-contained modules. Good starter workload for the least-available dev.

### 🎨 Spriter (parallel, off critical path)
- **30 × 32×32 sprites** in 16-color VGA palette (10 Easy + 10 Medium + 10 Hard words)
- Export as raw byte arrays (`sprite_bytes.txt`), organized by tier
- `DATA.ASM` population (paste exported bytes into correct tier array)
- **~15-18 hours total** ← significant jump from original estimate; flag this to the spriter TODAY
- *Word suggestions by tier:*
  - **Easy (3-4 letters):** CAT, DOG, EGG, SUN, HAT, BAG, CUP, PIG, HEN, ANT
  - **Medium (5-6 letters):** APPLE, GRAPE, TRAIN, CHAIR, CLOCK, BREAD, TIGER, HORSE, CLOUD, PLANT
  - **Hard (7+ letters):** ORANGE, SCHOOL, BRIDGE, CHICKEN, RAINBOW, PENGUIN, BLANKET, THUNDER, LANTERN, DOLPHIN

> ⚠️ **If the spriter can't handle 30 sprites:** Reduce to 6-8 per tier (18-24 total) as a middle ground. Talk to them today — they need maximum lead time.

**If Dev 3 flakes:** Dev 1 absorbs `FILEIO.ASM` (smallest module). Dev 2 absorbs `AUDIO.ASM` (~2 hours).

## 2.5 Build System

### `BUILD.BAT` (runs inside DOSBox)

```batch
@echo off
REM Assemble each module to .OBJ
tasm /zi src\MAIN.ASM, build\MAIN.OBJ
tasm /zi src\STATE.ASM, build\STATE.OBJ
tasm /zi src\DATA.ASM, build\DATA.OBJ
tasm /zi src\GFX.ASM, build\GFX.OBJ
tasm /zi src\AUDIO.ASM, build\AUDIO.OBJ
tasm /zi src\INPUT.ASM, build\INPUT.OBJ
tasm /zi src\FILEIO.ASM, build\FILEIO.OBJ
tasm /zi src\SCR_INTRO.ASM, build\SCR_INTRO.OBJ
tasm /zi src\SCR_GAME.ASM, build\SCR_GAME.OBJ
tasm /zi src\SCR_END.ASM, build\SCR_END.OBJ

REM Link all .OBJ files into one .EXE
tlink /v build\MAIN.OBJ+build\STATE.OBJ+build\DATA.OBJ+^
  build\GFX.OBJ+build\AUDIO.OBJ+build\INPUT.OBJ+build\FILEIO.OBJ+^
  build\SCR_INTRO.OBJ+build\SCR_GAME.OBJ+build\SCR_END.OBJ,^
  bin\SPELL.EXE

echo Build complete: bin\SPELL.EXE
```

**Flags explained:**
- `/zi` on TASM — include debug info (helpful during dev, remove for final)
- `/v` on TLINK — verbose link

### Workflow

1. Edit `.ASM` files in your host editor (VS Code on Windows).
2. Switch to DOSBox, `cd` to the project folder.
3. Run `BUILD.BAT`.
4. Run `bin\SPELL.EXE`.
5. Iterate.

---

# Chapter 3 — Core Engine Modules

*From here on, chapters are technical. Study the relevant concepts from the Study Guide before reading.*

## 3.1 `MAIN.ASM` — Entry Point & Game Loop

### Purpose
The top-level module. Owns program initialization, the main loop, and shutdown. Everything begins and ends here.

### Dependencies
- `STATE.ASM` (calls `GAME_TICK`)
- `GFX.ASM` (calls `GFX_INIT`, `GFX_SHUTDOWN`)
- `FILEIO.ASM` (calls `FILE_LOAD_SCORES` at startup)
- `SHARED.INC` (constants)

### Structure

```asm
; MAIN.ASM — Entry point and game loop
.MODEL SMALL
.STACK 1024
.DATA
    INCLUDE SHARED.INC

    ; --- Runtime state (global variables) ---
    CURRENT_STATE   DB  STATE_TITLE    ; see SHARED.INC for state constants
    DIFFICULTY      DB  DIFF_EASY      ; 0=Easy, 1=Medium, 2=Hard  ← NEW
    PLAYER_NAME     DB  '   '          ; 3 spaces (filled during name entry)
    SCORE           DW  0              ; 16-bit score
    HEARTS          DB  MAX_HEARTS     ; starts at 3
    CURRENT_WORD    DB  0              ; index 0..9 within selected tier
    TIMER_START     DW  0              ; BIOS tick at round start
    INPUT_BUFFER    DB  17 DUP(0)      ; up to 16 chars + null

    PUBLIC CURRENT_STATE, DIFFICULTY, PLAYER_NAME, SCORE, HEARTS
    PUBLIC CURRENT_WORD, TIMER_START, INPUT_BUFFER

.CODE
    EXTRN GAME_TICK:PROC
    EXTRN GFX_INIT:PROC, GFX_SHUTDOWN:PROC
    EXTRN FILE_LOAD_SCORES:PROC

MAIN PROC
    ; --- Setup DS register ---
    MOV AX, @DATA
    MOV DS, AX

    ; --- Initialize subsystems ---
    CALL GFX_INIT              ; switch to Mode 13h
    CALL FILE_LOAD_SCORES      ; load leaderboard into memory

    ; --- Main game loop ---
GAME_LOOP:
    CALL GAME_TICK             ; run one frame of the current state
    CMP CURRENT_STATE, STATE_QUIT
    JNE GAME_LOOP

    ; --- Shutdown ---
    CALL GFX_SHUTDOWN          ; restore text mode
    MOV AH, 4Ch                ; DOS: terminate program
    MOV AL, 0                  ; exit code 0
    INT 21h
MAIN ENDP
END MAIN
```

### Design Notes

- **Global state lives here.** `CURRENT_STATE`, `DIFFICULTY`, `SCORE`, `HEARTS`, etc. are declared in `MAIN.ASM`'s data segment and exported via `PUBLIC`. Other modules reference them via `EXTRN`.
  - `DIFFICULTY` is set by `SCR_DIFF_RUN` and then read by `SCR_ROUND_RUN` to pick the correct word array.
  - *Why here and not in `DATA.ASM`?* `DATA.ASM` is for compile-time-constant data (word list, sprites). `MAIN.ASM` holds mutable runtime state.
- **The loop is dead simple.** All real work happens in `GAME_TICK`. This keeps `MAIN` a one-screen file that's easy to audit.
- **`STATE_QUIT` is the exit condition.** Any screen that wants to terminate the program sets `CURRENT_STATE = STATE_QUIT` and returns.
- **`GFX_SHUTDOWN` is critical.** Without it, the user returns to DOS still in Mode 13h with a garbled prompt. Always restore text mode before exiting.

### Edge Cases
- If `GFX_INIT` fails (shouldn't in DOSBox), the program will likely crash. We don't bother handling this — it's not a shipping product.
- If `SCORES.DAT` doesn't exist on first run, `FILE_LOAD_SCORES` must handle gracefully (initialize empty leaderboard in memory).

### Integration Contract
- **Inputs:** None (entry point).
- **Outputs:** Sets up `DS`, calls `GAME_TICK` forever until state is `STATE_QUIT`, exits to DOS.
- **Called by:** DOS (it's `main`).
- **Calls:** `GAME_TICK`, `GFX_INIT`, `GFX_SHUTDOWN`, `FILE_LOAD_SCORES`.

---

## 3.2 `STATE.ASM` — Game State Machine

### Purpose
Dispatches the current game state to the correct screen handler. This is the one place that knows about all possible states; adding a new screen means adding a case here.

### Dependencies
- All `SCR_*.ASM` modules
- `SHARED.INC`

### Structure

```asm
; STATE.ASM — State dispatcher
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE

.CODE
    EXTRN SCR_TITLE_RUN:PROC
    EXTRN SCR_NAME_RUN:PROC
    EXTRN SCR_DIFF_RUN:PROC         ; ← NEW
    EXTRN SCR_INSTR_RUN:PROC
    EXTRN SCR_ROUND_RUN:PROC
    EXTRN SCR_JUDGE_RUN:PROC
    EXTRN SCR_END_RUN:PROC

    PUBLIC GAME_TICK

GAME_TICK PROC
    MOV AL, CURRENT_STATE

    CMP AL, STATE_TITLE
    JE  GT_TITLE
    CMP AL, STATE_NAME
    JE  GT_NAME
    CMP AL, STATE_DIFF              ; ← NEW
    JE  GT_DIFF                     ; ← NEW
    CMP AL, STATE_INSTR
    JE  GT_INSTR
    CMP AL, STATE_ROUND
    JE  GT_ROUND
    CMP AL, STATE_JUDGE
    JE  GT_JUDGE
    CMP AL, STATE_END
    JE  GT_END
    ; STATE_QUIT or unknown: fall through to return
    RET

GT_TITLE:   CALL SCR_TITLE_RUN
            RET
GT_NAME:    CALL SCR_NAME_RUN
            RET
GT_DIFF:    CALL SCR_DIFF_RUN       ; ← NEW
            RET
GT_INSTR:   CALL SCR_INSTR_RUN
            RET
GT_ROUND:   CALL SCR_ROUND_RUN
            RET
GT_JUDGE:   CALL SCR_JUDGE_RUN
            RET
GT_END:     CALL SCR_END_RUN
            RET
GAME_TICK ENDP
END
```

### Design Notes

- **Screen handlers are responsible for setting the next state.** `STATE.ASM` just dispatches; it doesn't decide transitions. E.g., `SCR_TITLE_RUN` sets `CURRENT_STATE = STATE_NAME` before returning.
- **Pro-tier optimization (optional):** Replace the chain of `CMP`/`JE` with a **jump table**. Faster and cleaner:
  ```asm
  MOV BL, CURRENT_STATE
  XOR BH, BH
  SHL BX, 1                    ; BX = state * 2 (each pointer is 2 bytes in SMALL model)
  JMP [STATE_JUMP_TABLE + BX]
  STATE_JUMP_TABLE:
      DW SCR_TITLE_RUN, SCR_NAME_RUN, SCR_DIFF_RUN, SCR_INSTR_RUN, SCR_ROUND_RUN, SCR_JUDGE_RUN, SCR_END_RUN
  ```
  **Don't do this on day 1.** Get the chain-of-compares working first. Optimize only if asked.

### Integration Contract
- **Inputs:** Reads `CURRENT_STATE`.
- **Outputs:** Calls the appropriate screen handler; no return value.
- **Called by:** `MAIN.ASM`.
- **Calls:** All `SCR_*_RUN` procedures.

---

## 3.3 `DATA.ASM` — Word List & Assets

### Purpose
The project's "database." All compile-time-constant data lives here: the list of words to spell, their sprites, and their sound patterns. No code.

### Structure

```asm
; DATA.ASM — Word list (3 tiers), sprite data, sound patterns
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    ; ================================================================
    ; WORD LISTS — Option A: 3 separate fixed-width arrays (16 bytes/word)
    ; Address formula: tier_base + (index * WORD_RECORD_SIZE)
    ; DIFFICULTY byte in MAIN.ASM selects which tier base to use.
    ; ================================================================

    ; --- Easy tier (3-4 letter words) ---
    PUBLIC EASY_WORDS
EASY_WORDS:
    DB 'CAT',0,  12 DUP(0)   ; index 0
    DB 'DOG',0,  12 DUP(0)   ; index 1
    DB 'EGG',0,  12 DUP(0)   ; index 2
    DB 'SUN',0,  12 DUP(0)   ; index 3
    DB 'HAT',0,  12 DUP(0)   ; index 4
    DB 'BAG',0,  12 DUP(0)   ; index 5
    DB 'CUP',0,  12 DUP(0)   ; index 6
    DB 'PIG',0,  12 DUP(0)   ; index 7
    DB 'HEN',0,  12 DUP(0)   ; index 8
    DB 'ANT',0,  12 DUP(0)   ; index 9

    ; --- Medium tier (5-6 letter words) ---
    PUBLIC MED_WORDS
MED_WORDS:
    DB 'APPLE',0,  10 DUP(0) ; index 0
    DB 'GRAPE',0,  10 DUP(0) ; index 1
    DB 'TRAIN',0,  10 DUP(0) ; index 2
    DB 'CHAIR',0,  10 DUP(0) ; index 3
    DB 'CLOCK',0,  10 DUP(0) ; index 4
    DB 'BREAD',0,  10 DUP(0) ; index 5
    DB 'TIGER',0,  10 DUP(0) ; index 6
    DB 'HORSE',0,  10 DUP(0) ; index 7
    DB 'CLOUD',0,  10 DUP(0) ; index 8
    DB 'PLANT',0,  10 DUP(0) ; index 9

    ; --- Hard tier (7+ letter words) ---
    PUBLIC HARD_WORDS
HARD_WORDS:
    DB 'ORANGE',0,  9 DUP(0) ; index 0
    DB 'SCHOOL',0,  9 DUP(0) ; index 1
    DB 'BRIDGE',0,  9 DUP(0) ; index 2
    DB 'CHICKEN',0, 8 DUP(0) ; index 3
    DB 'RAINBOW',0, 8 DUP(0) ; index 4
    DB 'PENGUIN',0, 8 DUP(0) ; index 5
    DB 'BLANKET',0, 8 DUP(0) ; index 6
    DB 'THUNDER',0, 8 DUP(0) ; index 7
    DB 'LANTERN',0, 8 DUP(0) ; index 8
    DB 'DOLPHIN',0, 8 DUP(0) ; index 9

    WORD_RECORD_SIZE  EQU 16
    WORDS_PER_TIER    EQU 10
    PUBLIC WORD_RECORD_SIZE, WORDS_PER_TIER

    ; ================================================================
    ; TIER POINTER TABLE — lets SCR_GAME resolve tier base at runtime
    ; Usage: MOV BX, DIFFICULTY; SHL BX,1; MOV SI,[TIER_TABLE+BX]
    ; ================================================================
    PUBLIC TIER_TABLE
TIER_TABLE:
    DW OFFSET EASY_WORDS    ; DIFF_EASY = 0
    DW OFFSET MED_WORDS     ; DIFF_MED  = 1
    DW OFFSET HARD_WORDS    ; DIFF_HARD = 2

    ; ================================================================
    ; SPRITE TABLE — 30 sprites × 1024 bytes = 30,720 bytes
    ; Layout: [Easy 0..9][Medium 0..9][Hard 0..9]
    ; Address: SPRITE_TABLE + (tier*10 + index) * SPRITE_SIZE
    ; ================================================================
    PUBLIC SPRITE_TABLE
SPRITE_TABLE:
    ; Easy sprites (indices 0-9)
    DB 1024 DUP(?)   ; CAT
    DB 1024 DUP(?)   ; DOG
    DB 1024 DUP(?)   ; EGG
    DB 1024 DUP(?)   ; SUN
    DB 1024 DUP(?)   ; HAT
    DB 1024 DUP(?)   ; BAG
    DB 1024 DUP(?)   ; CUP
    DB 1024 DUP(?)   ; PIG
    DB 1024 DUP(?)   ; HEN
    DB 1024 DUP(?)   ; ANT
    ; Medium sprites (indices 10-19)
    DB 1024 DUP(?)   ; APPLE
    DB 1024 DUP(?)   ; GRAPE
    DB 1024 DUP(?)   ; TRAIN
    DB 1024 DUP(?)   ; CHAIR
    DB 1024 DUP(?)   ; CLOCK
    DB 1024 DUP(?)   ; BREAD
    DB 1024 DUP(?)   ; TIGER
    DB 1024 DUP(?)   ; HORSE
    DB 1024 DUP(?)   ; CLOUD
    DB 1024 DUP(?)   ; PLANT
    ; Hard sprites (indices 20-29)
    DB 1024 DUP(?)   ; ORANGE
    DB 1024 DUP(?)   ; SCHOOL
    DB 1024 DUP(?)   ; BRIDGE
    DB 1024 DUP(?)   ; CHICKEN
    DB 1024 DUP(?)   ; RAINBOW
    DB 1024 DUP(?)   ; PENGUIN
    DB 1024 DUP(?)   ; BLANKET
    DB 1024 DUP(?)   ; THUNDER
    DB 1024 DUP(?)   ; LANTERN
    DB 1024 DUP(?)   ; DOLPHIN
    SPRITE_SIZE EQU 1024
    PUBLIC SPRITE_SIZE

    ; ================================================================
    ; SOUND TABLE — pointer-per-word, 30 entries × 2 bytes = 60 bytes
    ; Same flat layout as sprite table: [Easy 0..9][Med 0..9][Hard 0..9]
    ; ================================================================
    PUBLIC SOUND_TABLE
SOUND_TABLE:
    ; Easy sounds (0-9)
    DW OFFSET SND_CAT,    DW OFFSET SND_DOG,    DW OFFSET SND_EGG
    DW OFFSET SND_SUN,    DW OFFSET SND_HAT,    DW OFFSET SND_BAG
    DW OFFSET SND_CUP,    DW OFFSET SND_PIG,    DW OFFSET SND_HEN
    DW OFFSET SND_ANT
    ; Medium sounds (10-19)
    DW OFFSET SND_APPLE,  DW OFFSET SND_GRAPE,  DW OFFSET SND_TRAIN
    DW OFFSET SND_CHAIR,  DW OFFSET SND_CLOCK,  DW OFFSET SND_BREAD
    DW OFFSET SND_TIGER,  DW OFFSET SND_HORSE,  DW OFFSET SND_CLOUD
    DW OFFSET SND_PLANT
    ; Hard sounds (20-29)
    DW OFFSET SND_ORANGE, DW OFFSET SND_SCHOOL, DW OFFSET SND_BRIDGE
    DW OFFSET SND_CHICKEN,DW OFFSET SND_RAINBOW,DW OFFSET SND_PENGUIN
    DW OFFSET SND_BLANKET,DW OFFSET SND_THUNDER,DW OFFSET SND_LANTERN
    DW OFFSET SND_DOLPHIN

    ; --- Sound patterns (freq Hz, duration ms pairs; terminated by 0,0) ---
    ; Each word gets a distinct melodic fingerprint.
    ; Devs: fill in all 30. Samples below show the pattern format.
SND_CAT:    DW 784, 100, 659, 100, 523, 200, 0, 0    ; high-mid-low
SND_DOG:    DW 220, 300, 196, 300, 0, 0              ; low tones
SND_EGG:    DW 523, 150, 523, 150, 523, 300, 0, 0   ; three Cs
SND_SUN:    DW 659, 200, 784, 400, 0, 0
SND_HAT:    DW 440, 150, 494, 150, 523, 300, 0, 0
SND_BAG:    DW 392, 200, 330, 400, 0, 0
SND_CUP:    DW 523, 150, 659, 300, 0, 0
SND_PIG:    DW 587, 100, 523, 100, 440, 200, 0, 0
SND_HEN:    DW 659, 200, 587, 200, 0, 0
SND_ANT:    DW 440, 100, 440, 100, 330, 300, 0, 0
SND_APPLE:  DW 440, 150, 523, 150, 659, 300, 0, 0
SND_GRAPE:  DW 392, 200, 494, 200, 0, 0
SND_TRAIN:  DW 196, 150, 220, 150, 247, 150, 262, 300, 0, 0
SND_CHAIR:  DW 523, 200, 659, 200, 523, 200, 0, 0
SND_CLOCK:  DW 440, 100, 494, 100, 440, 100, 494, 300, 0, 0
SND_BREAD:  DW 330, 200, 392, 200, 330, 300, 0, 0
SND_TIGER:  DW 220, 100, 196, 100, 165, 400, 0, 0
SND_HORSE:  DW 392, 150, 440, 150, 494, 150, 523, 300, 0, 0
SND_CLOUD:  DW 659, 300, 784, 300, 0, 0
SND_PLANT:  DW 330, 200, 392, 400, 0, 0
SND_ORANGE: DW 523, 150, 587, 150, 659, 150, 698, 300, 0, 0
SND_SCHOOL: DW 196, 200, 220, 200, 247, 400, 0, 0
SND_BRIDGE: DW 587, 200, 523, 200, 494, 300, 0, 0
SND_CHICKEN:DW 659, 100, 698, 100, 659, 100, 523, 300, 0, 0
SND_RAINBOW:DW 523, 100, 587, 100, 659, 100, 698, 100, 784, 300, 0, 0
SND_PENGUIN:DW 392, 200, 330, 200, 294, 300, 0, 0
SND_BLANKET:DW 440, 150, 392, 150, 330, 300, 0, 0
SND_THUNDER:DW 165, 100, 147, 100, 131, 400, 0, 0
SND_LANTERN:DW 523, 200, 587, 200, 659, 300, 0, 0
SND_DOLPHIN:DW 784, 150, 880, 150, 988, 300, 0, 0

    ; --- UI strings ---
    PUBLIC STR_TITLE, STR_INSTR, STR_GAMEOVER, STR_WIN
    PUBLIC STR_DIFF_PROMPT, STR_EASY, STR_MED, STR_HARD
STR_TITLE:       DB 'SPELLING FUN!',0
STR_INSTR:       DB 'TYPE WHAT YOU HEAR. PRESS ENTER.',0
STR_GAMEOVER:    DB 'GAME OVER',0
STR_WIN:         DB 'YOU DID IT!',0
STR_DIFF_PROMPT: DB 'CHOOSE DIFFICULTY:',0
STR_EASY:        DB '1. EASY',0
STR_MED:         DB '2. MEDIUM',0
STR_HARD:        DB '3. HARD',0

END
```

### Design Notes

- **3 separate fixed-width arrays (Option A).** `EASY_WORDS`, `MED_WORDS`, `HARD_WORDS` are each 10 × 16-byte records. `TIER_TABLE` holds pointers to each base, indexed by `DIFFICULTY`. Word address: `[TIER_TABLE + DIFFICULTY*2]` → base, then `base + (CURRENT_WORD × WORD_RECORD_SIZE)`.
- **Sprite table is flat, indexed globally.** `sprite_index = (DIFFICULTY × 10) + CURRENT_WORD`. Sprite address: `SPRITE_TABLE + sprite_index × SPRITE_SIZE`. This means the spriter must lay out sprites in the exact order: Easy 0-9, Medium 0-9, Hard 0-9.
- **Sound table is flat too.** Same indexing as sprites. `sound_ptr_index = DIFFICULTY×10 + CURRENT_WORD`. Two bytes per pointer, so offset = `sound_ptr_index × 2`.
- **Sprite data starts as placeholders.** `DB 1024 DUP(?)` reserves uninitialized bytes. Spriter replaces these with real pixel data.
- **Sound patterns are flexible length.** Terminated by `freq=0`. Patterns can be any number of (freq, duration) pairs.
- **All 30 sound patterns must be distinct.** Even crude differences (ascending vs descending vs repeated note) help distinguish words audibly.

### Integration Contract
- **Inputs:** None (it's pure data).
- **Outputs:** All labels exported via `PUBLIC`.
- **Called by:** No one — all data access is via reading memory at the exported labels.
- **Calls:** None.

---

# Chapter 4 — I/O Modules

## 4.1 `INPUT.ASM` — Keyboard Input

### Purpose
All keyboard reading goes through here. Three modes: wait for any key, check if a key is pressed (non-blocking), and read a string until Enter.

### Dependencies
None (pure BIOS interrupt wrapper).

### Core Interrupts
- **`INT 16h, AH=00h`** — Wait for key, return scan code in `AH` and ASCII in `AL`. **Blocks.**
- **`INT 16h, AH=01h`** — Check keyboard buffer, set Zero Flag if empty. **Non-blocking.**

### Structure

```asm
; INPUT.ASM — Keyboard services
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

.CODE
    PUBLIC INP_WAIT_KEY, INP_CHECK_KEY, INP_READ_STRING

;---------------------------------------------------------------
; INP_WAIT_KEY — Block until a key is pressed.
; Out: AL = ASCII char, AH = scan code
;---------------------------------------------------------------
INP_WAIT_KEY PROC
    MOV AH, 00h
    INT 16h
    RET
INP_WAIT_KEY ENDP

;---------------------------------------------------------------
; INP_CHECK_KEY — Non-blocking key check.
; Out: ZF=1 if no key, ZF=0 if key available (AL=ASCII)
;      If key was available, it IS consumed from buffer (via INT 16h AH=00).
;---------------------------------------------------------------
INP_CHECK_KEY PROC
    MOV AH, 01h
    INT 16h
    JZ  ICK_NONE            ; no key in buffer
    MOV AH, 00h             ; consume the key
    INT 16h
    OR  AL, AL              ; clear ZF (assuming AL != 0; tweak if needed)
ICK_DONE:
    RET
ICK_NONE:
    XOR AX, AX              ; ZF=1
    RET
INP_CHECK_KEY ENDP

;---------------------------------------------------------------
; INP_READ_STRING — Read a string until Enter, with basic editing.
; In:  ES:DI = buffer, CX = max length
; Out: buffer filled, null-terminated; CX = actual length
;---------------------------------------------------------------
INP_READ_STRING PROC
    PUSH AX
    PUSH BX
    PUSH DI

    XOR  BX, BX             ; BX = current length

IRS_LOOP:
    CALL INP_WAIT_KEY
    CMP  AL, 13             ; Enter?
    JE   IRS_DONE
    CMP  AL, 8              ; Backspace?
    JE   IRS_BACKSPACE
    CMP  BX, CX
    JAE  IRS_LOOP           ; buffer full; ignore new chars

    ; --- Convert to uppercase if letter ---
    CMP  AL, 'a'
    JB   IRS_STORE
    CMP  AL, 'z'
    JA   IRS_STORE
    SUB  AL, 32             ; lowercase -> uppercase

IRS_STORE:
    MOV  ES:[DI+BX], AL
    INC  BX
    ; TODO: echo char to screen via GFX_DRAW_TEXT
    JMP  IRS_LOOP

IRS_BACKSPACE:
    OR   BX, BX
    JZ   IRS_LOOP           ; nothing to delete
    DEC  BX
    ; TODO: erase char on screen
    JMP  IRS_LOOP

IRS_DONE:
    MOV  BYTE PTR ES:[DI+BX], 0   ; null terminate
    MOV  CX, BX                   ; return length in CX
    POP  DI
    POP  BX
    POP  AX
    RET
INP_READ_STRING ENDP

END
```

### Design Notes

- **Uppercase conversion in input.** Toddlers might type either case. We force uppercase in the buffer, and the word list is also uppercase. Comparison becomes case-insensitive "for free."
- **Backspace support.** Essential for toddler UX. Implementation is trivial here; the screen echo (visually erasing) is the screen module's job.
- **No timeout.** `INP_READ_STRING` blocks forever on missing Enter. The game loop accepts this because rounds are turn-based.

### Integration Contract
- **Inputs:** For `READ_STRING`: `ES:DI` buffer pointer, `CX` max length.
- **Outputs:** Buffer null-terminated; `CX` actual length.
- **Clobbers:** `AX`, `AH`, `AL`, flags (preserved via push/pop for BX/DI as shown).

---

## 4.2 `GFX.ASM` — Graphics (Mode 13h Sprite Rendering)

### Purpose
All drawing goes through here. Screens tell it *what* to draw and *where*; `GFX.ASM` handles the pixel manipulation.

### Dependencies
None (raw hardware + BIOS).

### Core Concepts

**Mode 13h:**
- Resolution: 320×200
- Colors: 256 (VGA palette)
- Framebuffer: at `A000:0000`, each byte is one pixel's palette index
- To plot a pixel: `ES:[DI] = color` where `DI = y*320 + x`, `ES = A000h`

**Palette:**
- Default VGA palette has good colors for basic use (0=black, 1=blue, 2=green, 4=red, 15=white, etc.)
- Spriter should work within this palette for MVP
- We can set custom palettes later if needed

### Structure

```asm
; GFX.ASM — Mode 13h graphics
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

.CODE
    PUBLIC GFX_INIT, GFX_SHUTDOWN, GFX_CLEAR
    PUBLIC GFX_DRAW_SPRITE, GFX_DRAW_CHAR, GFX_DRAW_STRING

;---------------------------------------------------------------
; GFX_INIT — Switch to Mode 13h (320x200, 256 colors)
;---------------------------------------------------------------
GFX_INIT PROC
    MOV  AX, 0013h
    INT  10h
    ; Set ES = video memory for drawing routines
    MOV  AX, 0A000h
    MOV  ES, AX
    RET
GFX_INIT ENDP

;---------------------------------------------------------------
; GFX_SHUTDOWN — Restore text mode (80x25)
;---------------------------------------------------------------
GFX_SHUTDOWN PROC
    MOV  AX, 0003h
    INT  10h
    RET
GFX_SHUTDOWN ENDP

;---------------------------------------------------------------
; GFX_CLEAR — Fill screen with color
; In: AL = color
;---------------------------------------------------------------
GFX_CLEAR PROC
    PUSH CX
    PUSH DI
    PUSH AX
    MOV  AH, AL           ; duplicate for word fill
    MOV  CX, 32000        ; 320*200 / 2 = 32000 words
    XOR  DI, DI
    CLD
    REP  STOSW
    POP  AX
    POP  DI
    POP  CX
    RET
GFX_CLEAR ENDP

;---------------------------------------------------------------
; GFX_DRAW_SPRITE — Draw a 32x32 sprite at (x, y)
; In: DS:SI = sprite data (1024 bytes), BX = x, DX = y
; Color 0 in sprite is treated as transparent.
;---------------------------------------------------------------
GFX_DRAW_SPRITE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI

    ; DI = y*320 + x
    MOV  AX, DX
    MOV  CX, 320
    MUL  CX               ; DX:AX = y*320
    ADD  AX, BX           ; AX = y*320 + x
    MOV  DI, AX

    MOV  CX, 32           ; row counter

GDS_ROW:
    PUSH CX
    MOV  CX, 32           ; column counter
    PUSH DI

GDS_COL:
    LODSB                 ; AL = [DS:SI++], 1 pixel from sprite
    OR   AL, AL
    JZ   GDS_SKIP         ; transparent pixel
    MOV  ES:[DI], AL
GDS_SKIP:
    INC  DI
    LOOP GDS_COL

    POP  DI
    ADD  DI, 320          ; next row
    POP  CX
    LOOP GDS_ROW

    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
GFX_DRAW_SPRITE ENDP

;---------------------------------------------------------------
; GFX_DRAW_CHAR — Draw one ASCII char at (x, y) in color AL
; Uses BIOS 8x8 font at INT 1Fh vector (or supply our own bitmap font).
; Simplest implementation: use INT 10h, AH=09 (write char) in text mode.
; But Mode 13h needs manual rendering.
; For MVP: include a hard-coded 8x8 font bitmap in DATA.ASM or GFX.ASM.
; In: AL = char, BL = color, CX = x, DX = y
;---------------------------------------------------------------
GFX_DRAW_CHAR PROC
    ; Implementation note: easiest approach is to embed an 8x8 font table.
    ; For MVP we can use VGA ROM font at INT 1Fh (for chars 0x80-0xFF)
    ; or INT 43h for full ROM font pointer.
    ; Alternative: find a public-domain 8x8 bitmap font online (~2KB data).
    ; -- Details filled in by Dev 2 during implementation --
    RET
GFX_DRAW_CHAR ENDP

;---------------------------------------------------------------
; GFX_DRAW_STRING — Draw null-terminated string
; In: DS:SI = string, BL = color, CX = x, DX = y
;---------------------------------------------------------------
GFX_DRAW_STRING PROC
    PUSH SI
    PUSH CX
GDS_STR_LOOP:
    LODSB
    OR   AL, AL
    JZ   GDS_STR_DONE
    CALL GFX_DRAW_CHAR
    ADD  CX, 8            ; advance x by 8 pixels
    JMP  GDS_STR_LOOP
GDS_STR_DONE:
    POP  CX
    POP  SI
    RET
GFX_DRAW_STRING ENDP

END
```

### Design Notes

- **Transparent color.** Index 0 (black) is treated as transparent in sprites. This means backgrounds show through. For apple drawn on white bg, just leave "non-apple" pixels as 0 in the sprite data.
- **Font rendering is non-trivial in Mode 13h.** Options:
  1. **Embed a public-domain 8x8 bitmap font** (~2KB of data) and render char-by-char. Cleanest.
  2. **Temporarily switch to text mode for text, Mode 13h for sprites.** Ugly, causes flicker.
  3. **Use ROM BIOS font** at the vector in `INT 1Fh` (chars 0x80-0xFF) and `INT 43h` (all chars). Requires a bit of setup but no extra data.
  - **Recommendation:** Option 1. Dev 2 grabs a font bitmap and drops it in. It's what retro games did.
- **Sprite format.** Row-major, 32×32 bytes per sprite. Spriter tool of choice is any pixel editor that can export raw bytes (e.g., GrafX2, Aseprite + script, or even GIMP with indexed PNG + custom exporter).
- **Pro-tier optimization (skip initially):** Use `REP MOVSB` in the inner sprite loop for non-transparent runs. But the `OR AL, AL` / `JZ` approach is plenty fast for 32×32 sprites.

### Integration Contract
- **Inputs:** Varies per routine (documented above).
- **Outputs:** Modifies video memory at `A000h`.
- **Clobbers:** Preserves registers via push/pop.
- **Requires:** `ES = A000h` (set by `GFX_INIT`). If another routine changes `ES`, must restore.

---

## 4.3 `AUDIO.ASM` — PC Speaker Sound Cues

### Purpose
Play distinguishable tone patterns as audio cues for each word. Not real speech — our bar is "different for each word, recognizable as 'the apple sound.'"

### Dependencies
None (direct hardware port I/O).

### Core Concepts

**PC Speaker via ports 42h, 43h, 61h:**
- Port `43h` is the PIT (Programmable Interval Timer) control register.
- Port `42h` is PIT channel 2 data (connected to speaker).
- Port `61h` bits 0-1 enable/disable the speaker.
- To play a frequency `F`: write `1193180 / F` as two bytes (low, high) to port `42h`, then set bits 0-1 of port `61h`.
- To silence: clear bits 0-1 of port `61h`.

### Structure

```asm
; AUDIO.ASM — PC speaker tone generation
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

.CODE
    PUBLIC SND_PLAY_TONE, SND_SILENCE, SND_PLAY_PATTERN

;---------------------------------------------------------------
; SND_PLAY_TONE — Start playing a continuous tone.
; In: BX = frequency in Hz (e.g., 440 = A)
;---------------------------------------------------------------
SND_PLAY_TONE PROC
    PUSH AX
    PUSH BX
    PUSH DX

    ; Compute divisor = 1193180 / frequency
    MOV  DX, 12h          ; 1193180 = 0012_34DCh
    MOV  AX, 34DCh
    DIV  BX               ; AX = divisor

    ; Program PIT channel 2 (control register)
    PUSH AX
    MOV  AL, 0B6h         ; channel 2, both bytes, mode 3 (square wave)
    OUT  43h, AL
    POP  AX
    OUT  42h, AL          ; low byte
    MOV  AL, AH
    OUT  42h, AL          ; high byte

    ; Enable speaker (bits 0-1 of port 61h)
    IN   AL, 61h
    OR   AL, 03h
    OUT  61h, AL

    POP  DX
    POP  BX
    POP  AX
    RET
SND_PLAY_TONE ENDP

;---------------------------------------------------------------
; SND_SILENCE — Stop the speaker.
;---------------------------------------------------------------
SND_SILENCE PROC
    PUSH AX
    IN   AL, 61h
    AND  AL, 0FCh         ; clear bits 0-1
    OUT  61h, AL
    POP  AX
    RET
SND_SILENCE ENDP

;---------------------------------------------------------------
; SND_DELAY — Busy-wait for CX milliseconds.
; Uses BIOS tick counter (~55ms resolution, so we round up).
; For finer timing: use INT 15h AH=86h (microsecond delay, safer).
;---------------------------------------------------------------
SND_DELAY PROC
    PUSH AX
    PUSH CX
    PUSH DX
    ; INT 15h, AH=86h: CX:DX = microseconds to wait
    ; We get milliseconds in CX, convert to microseconds.
    MOV  AX, CX
    MOV  DX, 1000
    MUL  DX               ; DX:AX = CX * 1000 = microseconds
    MOV  CX, DX
    MOV  DX, AX
    MOV  AH, 86h
    INT  15h
    POP  DX
    POP  CX
    POP  AX
    RET
SND_DELAY ENDP

;---------------------------------------------------------------
; SND_PLAY_PATTERN — Play a pattern of (freq, duration_ms) pairs.
; In: DS:SI = pattern data. Terminated by freq=0.
;---------------------------------------------------------------
SND_PLAY_PATTERN PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

SPP_LOOP:
    MOV  BX, [SI]          ; frequency
    OR   BX, BX
    JZ   SPP_DONE
    ADD  SI, 2
    MOV  CX, [SI]          ; duration
    ADD  SI, 2

    CALL SND_PLAY_TONE
    CALL SND_DELAY
    CALL SND_SILENCE

    ; Small gap between tones
    MOV  CX, 30
    CALL SND_DELAY

    JMP  SPP_LOOP

SPP_DONE:
    CALL SND_SILENCE
    POP  SI
    POP  CX
    POP  BX
    POP  AX
    RET
SND_PLAY_PATTERN ENDP

END
```

### Design Notes

- **Why `INT 15h AH=86h` for timing?** More accurate than a BIOS tick busy-loop (which has ~55ms resolution). Especially matters for short tones.
- **Patterns are data, not code.** `DATA.ASM` holds the frequency/duration arrays. `AUDIO.ASM` just plays them. So adding a new sound = adding data.
- **Gap between tones.** Without the 30ms silence between notes, consecutive tones bleed into each other and sound like one garbled noise.
- **DOSBox audio.** PC speaker emulation works fine in DOSBox. Make sure `pcspeaker=true` in `dosbox.conf`.

### Integration Contract
- **Inputs:** For `PLAY_PATTERN`: `DS:SI` pattern pointer. For `PLAY_TONE`: `BX` = freq.
- **Outputs:** Speaker makes sound.
- **Blocks:** `PLAY_PATTERN` blocks for the full pattern duration. Fine for MVP; the round flow tolerates it.

---

## 4.4 `FILEIO.ASM` — Leaderboard Persistence

### Purpose
Load and save the top-5 leaderboard to `SCORES.DAT`. Handles "file doesn't exist yet" as a normal first-run case.

### Dependencies
- `SHARED.INC` (constants)
- Uses external data variables (declared in `MAIN.ASM` or here).

### Core Interrupts
- `INT 21h, AH=3Dh` — Open file (AL=0 read, 1 write, 2 r/w)
- `INT 21h, AH=3Ch` — Create/truncate file
- `INT 21h, AH=3Fh` — Read
- `INT 21h, AH=40h` — Write
- `INT 21h, AH=3Eh` — Close

### File Format

Fixed-width binary record, 5 records max:

```
Record layout (8 bytes each):
  Offset 0-2:  3-byte name (ASCII, e.g. 'AAA')
  Offset 3-4:  16-bit score (little-endian word)
  Offset 5:    difficulty byte (0=Easy, 1=Med, 2=Hard)
  Offset 6-7:  2-byte padding (reserved, zeroed)

Total file size: 5 × 8 = 40 bytes fixed.
```

Display format on leaderboard: `AAA | 240pts | HARD`

Fixed-width simplifies read/write — we always handle exactly 40 bytes.

### Structure

```asm
; FILEIO.ASM — Leaderboard file I/O
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    FILENAME      DB  'SCORES.DAT',0

    ; Leaderboard in memory: 5 records × 8 bytes = 40 bytes
    PUBLIC LEADERBOARD
LEADERBOARD   DB  40 DUP(0)
    LEADERBOARD_BYTES      EQU 40
    LEADERBOARD_ENTRY_SIZE EQU 8
    LEADERBOARD_MAX_ENTRIES EQU 5
    ; Record offsets (use as: LEA BX, LEADERBOARD; MOV AL, [BX+LB_DIFF])
    LB_NAME  EQU 0   ; 3 bytes
    LB_SCORE EQU 3   ; 2 bytes (word)
    LB_DIFF  EQU 5   ; 1 byte (0=E,1=M,2=H)
    LB_PAD   EQU 6   ; 2 bytes
    PUBLIC LEADERBOARD_BYTES, LEADERBOARD_ENTRY_SIZE, LEADERBOARD_MAX_ENTRIES

    FILE_HANDLE   DW  0

.CODE
    PUBLIC FILE_LOAD_SCORES, FILE_SAVE_SCORES, FILE_INSERT_SCORE

;---------------------------------------------------------------
; FILE_LOAD_SCORES — Load leaderboard from SCORES.DAT.
; If file doesn't exist, leaves LEADERBOARD as zeros.
;---------------------------------------------------------------
FILE_LOAD_SCORES PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 3Dh
    MOV  AL, 0
    LEA  DX, FILENAME
    INT  21h
    JC   FLS_NOFILE
    MOV  FILE_HANDLE, AX

    MOV  AH, 3Fh
    MOV  BX, FILE_HANDLE
    MOV  CX, LEADERBOARD_BYTES    ; 40 bytes
    LEA  DX, LEADERBOARD
    INT  21h

    MOV  AH, 3Eh
    MOV  BX, FILE_HANDLE
    INT  21h

FLS_NOFILE:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
FILE_LOAD_SCORES ENDP

;---------------------------------------------------------------
; FILE_SAVE_SCORES — Write current leaderboard to SCORES.DAT.
;---------------------------------------------------------------
FILE_SAVE_SCORES PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 3Ch
    XOR  CX, CX
    LEA  DX, FILENAME
    INT  21h
    JC   FSS_DONE
    MOV  FILE_HANDLE, AX

    MOV  AH, 40h
    MOV  BX, FILE_HANDLE
    MOV  CX, LEADERBOARD_BYTES    ; 40 bytes
    LEA  DX, LEADERBOARD
    INT  21h

    MOV  AH, 3Eh
    MOV  BX, FILE_HANDLE
    INT  21h

FSS_DONE:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
FILE_SAVE_SCORES ENDP

;---------------------------------------------------------------
; FILE_INSERT_SCORE — Insert (name, score, difficulty) into top 5.
; In: DS:SI = 3-char name, BX = score, AL = difficulty byte
;---------------------------------------------------------------
FILE_INSERT_SCORE PROC
    ; -- Algorithm --
    ; 1. Find insertion index: first slot where existing score < new score.
    ; 2. If no slot qualifies, return.
    ; 3. Shift slots [index..3] down one → [index+1..4].
    ; 4. Write name (3B), score (2B), difficulty (1B), pad (2B) at slot [index].
    ; Implementation left for Dev 3 during integration.
    ; Note: each entry is now 8 bytes (was 25). Update your loop stride.
    RET
FILE_INSERT_SCORE ENDP

END
```

### Design Notes

- **Record size changed: 25 → 8 bytes.** Difficulty byte added at offset 5. Total file: 40 bytes. The smaller size is better — less I/O, easier to inspect in a hex editor.
- **`FILE_INSERT_SCORE` now takes an extra parameter:** `AL = difficulty byte`. Dev 3 must update their implementation to write this into the record at `LB_DIFF` offset.
- **First-run behavior unchanged.** `SCORES.DAT` missing → `LEADERBOARD` stays zero-filled → display shows empty slots. Graceful.
- **Binary format, not text.** Fixed record size, debuggable with a hex viewer. Difficulty `0x00`, `0x01`, `0x02` maps to Easy/Med/Hard.
- **Leaderboard display:** `SCR_END.ASM` reads `LB_DIFF` from each entry and maps to `STR_EASY`/`STR_MED`/`STR_HARD` for display.

### Integration Contract
- **Load:** Called once at program startup.
- **Save:** Called once at `SCR_END_RUN` after inserting the player's score (if it qualifies).
- **In-memory format:** Same as file format (125-byte buffer).

---

# Chapter 5 — Screen Modules

## 5.1 `SCR_INTRO.ASM` — Title + Name Entry + Instructions

### Purpose
The "onboarding" sequence: welcome screen, get the player's 3-char name, select difficulty, then explain the rules.

### Screens Owned
1. **`SCR_TITLE_RUN`** — show title + "press any key"
2. **`SCR_NAME_RUN`** — prompt for 3 initials, arcade-style
3. **`SCR_DIFF_RUN`** — difficulty selection (1=Easy, 2=Medium, 3=Hard) ← NEW
4. **`SCR_INSTR_RUN`** — explain gameplay

### Dependencies
- `GFX.ASM` (draw text/sprite)
- `INPUT.ASM` (read keys)
- `DATA.ASM` (title string, instructions string, difficulty strings)
- External: `CURRENT_STATE`, `PLAYER_NAME`, `DIFFICULTY`

### Structure

```asm
; SCR_INTRO.ASM — Intro flow screens
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE, PLAYER_NAME:BYTE, DIFFICULTY:BYTE
    EXTRN STR_TITLE:BYTE, STR_INSTR:BYTE
    EXTRN STR_DIFF_PROMPT:BYTE, STR_EASY:BYTE, STR_MED:BYTE, STR_HARD:BYTE

    PROMPT_NAME  DB  'ENTER YOUR INITIALS:',0
    PROMPT_KEY   DB  'PRESS ANY KEY',0

.CODE
    EXTRN GFX_CLEAR:PROC, GFX_DRAW_STRING:PROC
    EXTRN INP_WAIT_KEY:PROC

    PUBLIC SCR_TITLE_RUN, SCR_NAME_RUN, SCR_DIFF_RUN, SCR_INSTR_RUN

;---------------------------------------------------------------
; SCR_TITLE_RUN — Title screen. Any key → name entry.
;---------------------------------------------------------------
SCR_TITLE_RUN PROC
    MOV  AL, 1
    CALL GFX_CLEAR

    LEA  SI, STR_TITLE
    MOV  BL, 15
    MOV  CX, 100
    MOV  DX, 80
    CALL GFX_DRAW_STRING

    LEA  SI, PROMPT_KEY
    MOV  CX, 100
    MOV  DX, 120
    CALL GFX_DRAW_STRING

    CALL INP_WAIT_KEY

    MOV  CURRENT_STATE, STATE_NAME
    RET
SCR_TITLE_RUN ENDP

;---------------------------------------------------------------
; SCR_NAME_RUN — Read 3 initials → difficulty select.
;---------------------------------------------------------------
SCR_NAME_RUN PROC
    MOV  AL, 1
    CALL GFX_CLEAR

    LEA  SI, PROMPT_NAME
    MOV  BL, 15
    MOV  CX, 80
    MOV  DX, 90
    CALL GFX_DRAW_STRING

    MOV  CX, 3
    XOR  BX, BX
SNR_LOOP:
    CALL INP_WAIT_KEY
    CMP  AL, 'a'
    JB   SNR_STORE
    CMP  AL, 'z'
    JA   SNR_STORE
    SUB  AL, 32
SNR_STORE:
    LEA  DI, PLAYER_NAME
    MOV  [DI+BX], AL
    INC  BX
    LOOP SNR_LOOP

    MOV  CURRENT_STATE, STATE_DIFF    ; ← changed: was STATE_INSTR
    RET
SCR_NAME_RUN ENDP

;---------------------------------------------------------------
; SCR_DIFF_RUN — Difficulty select screen.          ← NEW
; Press 1 = Easy, 2 = Medium, 3 = Hard.
; Sets DIFFICULTY byte, transitions to STATE_INSTR.
;---------------------------------------------------------------
SCR_DIFF_RUN PROC
    MOV  AL, 0               ; black background
    CALL GFX_CLEAR

    LEA  SI, STR_DIFF_PROMPT
    MOV  BL, 15              ; white
    MOV  CX, 90
    MOV  DX, 60
    CALL GFX_DRAW_STRING

    LEA  SI, STR_EASY
    MOV  CX, 100
    MOV  DX, 90
    CALL GFX_DRAW_STRING

    LEA  SI, STR_MED
    MOV  CX, 100
    MOV  DX, 110
    CALL GFX_DRAW_STRING

    LEA  SI, STR_HARD
    MOV  CX, 100
    MOV  DX, 130
    CALL GFX_DRAW_STRING

SDR_WAIT:
    CALL INP_WAIT_KEY
    CMP  AL, '1'
    JE   SDR_EASY
    CMP  AL, '2'
    JE   SDR_MED
    CMP  AL, '3'
    JE   SDR_HARD
    JMP  SDR_WAIT            ; ignore other keys

SDR_EASY:
    MOV  DIFFICULTY, DIFF_EASY
    JMP  SDR_DONE
SDR_MED:
    MOV  DIFFICULTY, DIFF_MED
    JMP  SDR_DONE
SDR_HARD:
    MOV  DIFFICULTY, DIFF_HARD
SDR_DONE:
    MOV  CURRENT_STATE, STATE_INSTR
    RET
SCR_DIFF_RUN ENDP

;---------------------------------------------------------------
; SCR_INSTR_RUN — Show instructions. Any key → round.
;---------------------------------------------------------------
SCR_INSTR_RUN PROC
    MOV  AL, 1
    CALL GFX_CLEAR

    LEA  SI, STR_INSTR
    MOV  BL, 15
    MOV  CX, 20
    MOV  DX, 90
    CALL GFX_DRAW_STRING

    LEA  SI, PROMPT_KEY
    MOV  CX, 100
    MOV  DX, 150
    CALL GFX_DRAW_STRING

    CALL INP_WAIT_KEY

    MOV  CURRENT_STATE, STATE_ROUND
    RET
SCR_INSTR_RUN ENDP

END
```

### Design Notes

- **`SCR_DIFF_RUN` only accepts '1', '2', '3'.** Any other key loops back to wait. No default — player must make an explicit choice.
- **`DIFFICULTY` is set once and never changes during a session.** The round loop reads it to pick the correct word array.
- **Instruction screen comes after difficulty.** This lets us potentially customize the instructions display per difficulty in a polish pass (e.g., "HARD MODE: You have 3 hearts and LONG words!").

### Integration Contract
- **Inputs:** Reads `STR_TITLE`, `STR_INSTR`, `STR_DIFF_PROMPT`, `STR_EASY`, `STR_MED`, `STR_HARD`.
- **Outputs:** Writes `PLAYER_NAME`, `DIFFICULTY`, updates `CURRENT_STATE`.

---

## 5.2 `SCR_GAME.ASM` — Main Gameplay Screen

### Purpose
The heart of the game. Picks a word, shows the sprite, plays the sound, reads spelling input, judges, updates score/hearts, transitions.

### Screens Owned
1. **`SCR_ROUND_RUN`** — show sprite, play sound, get input, transition to JUDGE
2. **`SCR_JUDGE_RUN`** — show right/wrong feedback, update score/hearts, transition back to ROUND or to END

### Dependencies
- `GFX.ASM`, `AUDIO.ASM`, `INPUT.ASM`, `DATA.ASM`
- External globals: `CURRENT_STATE`, `CURRENT_WORD`, `SCORE`, `HEARTS`, `TIMER_START`, `INPUT_BUFFER`

### Structure

```asm
; SCR_GAME.ASM — Gameplay screens
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE, CURRENT_WORD:BYTE, DIFFICULTY:BYTE
    EXTRN SCORE:WORD, HEARTS:BYTE
    EXTRN TIMER_START:WORD, INPUT_BUFFER:BYTE
    EXTRN TIER_TABLE:WORD, SPRITE_TABLE:BYTE, SOUND_TABLE:WORD
    EXTRN WORD_RECORD_SIZE:ABS, WORDS_PER_TIER:ABS, SPRITE_SIZE:ABS

    STR_RIGHT   DB  'YES! GREAT JOB!',0
    STR_WRONG   DB  'OOPS! TRY NEXT ONE.',0
    STR_REPLAY  DB  'PRESS R TO HEAR AGAIN',0
    STR_SCORE   DB  'SCORE: ',0
    STR_HEARTS  DB  'HEARTS: ',0

    JUDGE_FLAG  DB  0    ; 0 = wrong, 1 = right

.CODE
    EXTRN GFX_CLEAR:PROC, GFX_DRAW_SPRITE:PROC
    EXTRN GFX_DRAW_STRING:PROC
    EXTRN INP_WAIT_KEY:PROC, INP_READ_STRING:PROC
    EXTRN SND_PLAY_PATTERN:PROC

    PUBLIC SCR_ROUND_RUN, SCR_JUDGE_RUN

;---------------------------------------------------------------
; SCR_ROUND_RUN — Play one round of the game.
;---------------------------------------------------------------
SCR_ROUND_RUN PROC
    MOV  AL, 1
    CALL GFX_CLEAR

    ; --- Resolve word address from tier + index ---
    ; TIER_TABLE[DIFFICULTY] → base address of current tier
    MOV  AL, DIFFICULTY
    MOV  AH, 0
    SHL  AX, 1                ; AX = DIFFICULTY * 2 (word-pointer offset)
    LEA  BX, TIER_TABLE
    ADD  BX, AX
    MOV  SI, [BX]             ; SI = base address of selected tier array

    ; Add (CURRENT_WORD * WORD_RECORD_SIZE) to reach the correct word
    MOV  AL, CURRENT_WORD
    MOV  AH, 0
    MOV  CX, WORD_RECORD_SIZE
    MUL  CX                   ; AX = index * 16
    ADD  SI, AX               ; DS:SI → current word string

    ; --- Resolve global sprite index = (DIFFICULTY * 10) + CURRENT_WORD ---
    MOV  AL, DIFFICULTY
    MOV  AH, 0
    MOV  CX, WORDS_PER_TIER   ; 10
    MUL  CX                   ; AX = DIFFICULTY * 10
    MOV  CL, CURRENT_WORD
    MOV  CH, 0
    ADD  AX, CX               ; AX = global sprite index
    MOV  CX, SPRITE_SIZE      ; 1024
    MUL  CX                   ; DX:AX = index * 1024
    LEA  DI, SPRITE_TABLE
    ADD  DI, AX               ; DS:DI → correct sprite data
    PUSH SI
    MOV  SI, DI               ; sprite routine expects DS:SI
    MOV  BX, 144
    MOV  DX, 50
    CALL GFX_DRAW_SPRITE
    POP  SI

    ; --- Resolve sound pointer: same global index, but in SOUND_TABLE ---
    MOV  AL, DIFFICULTY
    MOV  AH, 0
    MOV  CX, WORDS_PER_TIER
    MUL  CX
    MOV  CL, CURRENT_WORD
    MOV  CH, 0
    ADD  AX, CX               ; AX = global sound index
    SHL  AX, 1                ; × 2 (each pointer is a word)
    LEA  BX, SOUND_TABLE
    ADD  BX, AX
    MOV  SI, [BX]             ; SI → sound pattern data
    CALL SND_PLAY_PATTERN

    ; --- Record timer start ---
    MOV  AH, 0
    INT  1Ah
    MOV  TIMER_START, DX

    ; --- Prompt and read spelling ---
    LEA  SI, STR_REPLAY
    MOV  BL, 15
    MOV  CX, 50
    MOV  DX, 140
    CALL GFX_DRAW_STRING

    PUSH DS
    POP  ES
    LEA  DI, INPUT_BUFFER
    MOV  CX, 16
    CALL INP_READ_STRING

    ; --- Compare input to current word ---
    ; SI still points to the correct word string (push/pop above preserved it)
    LEA  DI, INPUT_BUFFER
    CALL STR_COMPARE

    JE   SRR_RIGHT
    MOV  JUDGE_FLAG, 0
    JMP  SRR_DONE
SRR_RIGHT:
    MOV  JUDGE_FLAG, 1
SRR_DONE:
    MOV  CURRENT_STATE, STATE_JUDGE
    RET
SCR_ROUND_RUN ENDP

;---------------------------------------------------------------
; STR_COMPARE — Local helper: compare null-terminated strings.
; In: DS:SI = string A, DS:DI = string B
; Out: ZF set if equal
;---------------------------------------------------------------
STR_COMPARE PROC
    PUSH AX
    PUSH SI
    PUSH DI
SC_LOOP:
    MOV  AL, [SI]
    MOV  AH, [DI]
    CMP  AL, AH
    JNE  SC_DONE
    OR   AL, AL            ; both zero? end of both strings = match
    JZ   SC_DONE
    INC  SI
    INC  DI
    JMP  SC_LOOP
SC_DONE:
    POP  DI
    POP  SI
    POP  AX
    RET
STR_COMPARE ENDP

;---------------------------------------------------------------
; SCR_JUDGE_RUN — Process judgment, update score/hearts, transition.
;---------------------------------------------------------------
SCR_JUDGE_RUN PROC
    CMP  JUDGE_FLAG, 1
    JE   SJR_CORRECT

    ; --- Wrong answer ---
    DEC  HEARTS
    LEA  SI, STR_WRONG
    JMP  SJR_SHOW

SJR_CORRECT:
    ; --- Correct: compute score delta based on elapsed time ---
    MOV  AH, 0
    INT  1Ah
    MOV  AX, DX
    SUB  AX, TIMER_START   ; AX = ticks elapsed
    ; Score: base 100 minus (ticks * 2), min 10
    MOV  BX, 100
    SHL  AX, 1
    SUB  BX, AX
    CMP  BX, 10
    JGE  SJR_ADD
    MOV  BX, 10
SJR_ADD:
    ADD  SCORE, BX
    LEA  SI, STR_RIGHT

SJR_SHOW:
    MOV  AL, 1
    CALL GFX_CLEAR
    MOV  BL, 15
    MOV  CX, 80
    MOV  DX, 90
    CALL GFX_DRAW_STRING

    CALL INP_WAIT_KEY

    ; Advance word
    INC  CURRENT_WORD

    ; Check end conditions
    MOV  AL, HEARTS
    OR   AL, AL
    JZ   SJR_END           ; hearts = 0

    MOV  AL, CURRENT_WORD
    CMP  AL, WORDS_PER_TIER ; ← uses WORDS_PER_TIER (10), not old WORD_COUNT
    JAE  SJR_END           ; all words in tier done

    ; Continue
    MOV  CURRENT_STATE, STATE_ROUND
    RET

SJR_END:
    MOV  CURRENT_STATE, STATE_END
    RET
SCR_JUDGE_RUN ENDP

END
```

### Design Notes

- **Scoring formula.** Base 100, subtract `2 × ticks_elapsed`, floor at 10. A tick is ~55ms, so answering in 1 second (~18 ticks) gives ~64 points; answering in 5 seconds gives 10. Tunable.
- **Replay button ('R').** Not yet implemented in this sketch. Implementation option: check for 'R' inside `INP_READ_STRING` (special-case it) or poll before/after input read. Clean way: add an `INP_READ_STRING_WITH_CALLBACK` variant. MVP version: drop 'R' replay, just play sound once; polish task to add it.
- **String compare is local.** Each screen can have its own helper procs. We didn't bother making `STR_COMPARE` part of `INPUT.ASM` because no one else needs it yet. If a second screen wants it, refactor.

### Integration Contract
- **Inputs:** Reads `CURRENT_WORD`, `WORD_LIST`, `SPRITE_TABLE`, `SOUND_TABLE`.
- **Outputs:** Updates `SCORE`, `HEARTS`, `CURRENT_WORD`, `CURRENT_STATE`, `JUDGE_FLAG`, `INPUT_BUFFER`, `TIMER_START`.

---

## 5.3 `SCR_END.ASM` — Score + Leaderboard + Game Over

### Purpose
Show the final score, insert into leaderboard if it qualifies, display the board, then wait for key and quit.

### Screens Owned
1. **`SCR_END_RUN`** — final score + leaderboard + "press any key to quit"

### Dependencies
- `GFX.ASM`, `INPUT.ASM`, `FILEIO.ASM`
- External globals: `CURRENT_STATE`, `PLAYER_NAME`, `SCORE`, `HEARTS`, `LEADERBOARD`

### Structure

```asm
; SCR_END.ASM — End screen
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE, PLAYER_NAME:BYTE, DIFFICULTY:BYTE
    EXTRN SCORE:WORD, HEARTS:BYTE
    EXTRN LEADERBOARD:BYTE
    EXTRN STR_GAMEOVER:BYTE, STR_WIN:BYTE
    EXTRN STR_EASY:BYTE, STR_MED:BYTE, STR_HARD:BYTE

    STR_FINAL    DB  'FINAL SCORE: ',0
    STR_LEADER   DB  'TOP 5 PLAYERS',0
    STR_SEP      DB  ' | ',0

.CODE
    EXTRN GFX_CLEAR:PROC, GFX_DRAW_STRING:PROC
    EXTRN INP_WAIT_KEY:PROC
    EXTRN FILE_INSERT_SCORE:PROC, FILE_SAVE_SCORES:PROC

    PUBLIC SCR_END_RUN

SCR_END_RUN PROC
    MOV  AL, 0            ; black background
    CALL GFX_CLEAR

    ; --- Title: game over vs win ---
    MOV  AL, HEARTS
    OR   AL, AL
    JZ   SER_LOSE
    LEA  SI, STR_WIN
    JMP  SER_DRAW_TITLE
SER_LOSE:
    LEA  SI, STR_GAMEOVER
SER_DRAW_TITLE:
    MOV  BL, 15
    MOV  CX, 110
    MOV  DX, 30
    CALL GFX_DRAW_STRING

    ; --- Show final score ---
    LEA  SI, STR_FINAL
    MOV  CX, 80
    MOV  DX, 60
    CALL GFX_DRAW_STRING
    ; TODO: convert SCORE (word) to decimal ASCII and draw after STR_FINAL
    ;       (see "number-to-string" helper — Dev 1 task)

    ; --- Insert this run into leaderboard & save ---
    ; FILE_INSERT_SCORE now takes: DS:SI = name, BX = score, AL = difficulty
    LEA  SI, PLAYER_NAME
    MOV  BX, SCORE
    MOV  AL, DIFFICULTY      ; ← NEW: pass difficulty byte
    CALL FILE_INSERT_SCORE
    CALL FILE_SAVE_SCORES

    ; --- Display leaderboard (5 entries) ---
    LEA  SI, STR_LEADER
    MOV  CX, 110
    MOV  DX, 90
    CALL GFX_DRAW_STRING

    ; Loop: for each entry, draw "NAME | score | DIFF"
    ; Pseudocode (Dev 1 implements during integration):
    ;   BX = LEADERBOARD base
    ;   DX = 110 (starting y position)
    ;   for I = 0 to 4:
    ;     if entry[I].score == 0: skip (empty slot)
    ;     draw entry[I].name (3 chars)
    ;     draw " | "
    ;     draw entry[I].score as decimal
    ;     draw " | "
    ;     map entry[I].difficulty → STR_EASY/STR_MED/STR_HARD and draw
    ;     DX += 16 (next line)

    CALL INP_WAIT_KEY

    MOV  CURRENT_STATE, STATE_QUIT
    RET
SCR_END_RUN ENDP

END
```

### Design Notes

- **Win vs lose.** Hearts > 0 after loop = WIN (completed all words in tier). Hearts = 0 = GAME OVER.
- **Number-to-ASCII conversion.** Converting `SCORE` (a 16-bit int) to decimal ASCII needs a small helper (~15 lines). Standard algorithm: divide by 10 repeatedly, collect remainders, reverse. Dev 1's task.
- **Leaderboard rendering.** Loop 5 entries. For each: draw 3-char name, `" | "`, score as decimal, `" | "`, difficulty string. Skip entries where score is 0 (empty slot). Format: `AAA | 240 | HARD`.
- **Difficulty display.** Map `LB_DIFF` byte (0/1/2) to `STR_EASY`/`STR_MED`/`STR_HARD` with a 3-way `CMP`/`JE` chain before calling `GFX_DRAW_STRING`.

### Integration Contract
- **Inputs:** Reads `SCORE`, `HEARTS`, `PLAYER_NAME`, `DIFFICULTY`, `LEADERBOARD`.
- **Outputs:** Modifies leaderboard (via `FILE_INSERT_SCORE`), writes file, sets `CURRENT_STATE = STATE_QUIT`.

---

# Chapter 6 — Integration & Testing

## 6.1 Module Integration Contracts

A compact reference for **what each module promises** and **what it requires**.

| Module | Promises (outputs) | Requires (inputs) | Sets |
|---|---|---|---|
| `GAME_TICK` (STATE) | Runs one state's screen | `CURRENT_STATE` valid | — |
| `GFX_INIT` | Mode 13h active, `ES=A000h` | — | Video mode |
| `GFX_DRAW_SPRITE` | 32×32 sprite drawn | `DS:SI`=sprite, `BX,DX`=pos | Video memory |
| `SND_PLAY_PATTERN` | Pattern played to completion | `DS:SI`=pattern | Speaker, time |
| `INP_READ_STRING` | Null-term'd uppercase string | `ES:DI`=buf, `CX`=max | Buffer, `CX`=len |
| `FILE_LOAD_SCORES` | Leaderboard populated | `SCORES.DAT` (optional) | `LEADERBOARD` |
| `FILE_SAVE_SCORES` | Leaderboard persisted | `LEADERBOARD` valid | `SCORES.DAT` |
| `FILE_INSERT_SCORE` | Entry inserted if qualifies | `DS:SI`=name, `BX`=score, `AL`=difficulty | `LEADERBOARD` sorted |
| `SCR_DIFF_RUN` | Difficulty selected | `DIFF_*` strings in DATA | `DIFFICULTY`, state |
| `SCR_ROUND_RUN` | Round played | `CURRENT_WORD`, `DIFFICULTY` valid | `JUDGE_FLAG`, state |
| `SCR_JUDGE_RUN` | Score/hearts updated | `JUDGE_FLAG`, `TIMER_START` | `SCORE`, `HEARTS`, `CURRENT_WORD`, state |

## 6.2 Testing Strategy

**You cannot unit-test assembly cleanly.** Testing is a combination of:

### Per-Module Smoke Tests
Write a tiny test `MAIN.ASM` that calls only one module's procedures. E.g., while developing `GFX.ASM`, your test main does: `GFX_INIT`; draw a sprite; wait for key; `GFX_SHUTDOWN`. Verify visually.

Keep these tests in a `tests/` folder. You'll thank yourself when integrating.

### Integration Checkpoints

| Day | Checkpoint | Demo |
|---|---|---|
| 1 | Hello world builds & runs | `.EXE` prints "HELLO" and exits |
| 2 | Graphics module works standalone | Test main draws 1 sprite from each tier, exits |
| 3 | Audio module works standalone | Test main plays one pattern, exits |
| 4 | Input + file I/O work standalone | Read name, save to file with difficulty byte, relaunch, read file |
| 5 | **FULL INTEGRATION:** Title → Name → Diff → Instr → Round → End | Game playable end-to-end, even with bugs |
| 6 | All bugs found day 5 fixed | Full game plays without crashes across all 3 difficulty modes |
| 7 | Polish + demo prep | — |

### Common Bugs to Watch For

- **Forgetting to set `DS` in a new module.** TASM won't warn; you'll read garbage. Always `MOV AX, @DATA / MOV DS, AX` at entry.
- **Clobbering registers across calls.** If `SCR_ROUND` expects `DIFFICULTY` in a register and a subroutine clobbers it, the wrong tier loads. **Always push/pop registers you didn't declare as "output."**
- **`ES` pointing at the wrong segment.** Sprite routines need `ES=A000h`. File routines need `DS:DX` valid. Keep track.
- **Off-by-one in sprite size calcs.** 32×32 = 1024 bytes. Global sprite index = `DIFFICULTY*10 + CURRENT_WORD`. Don't confuse tier-local index with global index.
- **Signed vs unsigned comparisons.** `JG/JL` are signed; `JA/JB` are unsigned. Use unsigned for sizes/counts; signed for score deltas.
- **`TIER_TABLE` pointer resolution.** If `DIFFICULTY=2` and you forget to multiply by 2 before indexing `TIER_TABLE`, you'll get the wrong tier's base address. The `SHL AX, 1` in `SCR_ROUND_RUN` is critical.

## 6.3 Known Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Font rendering in Mode 13h takes longer than expected | High | Medium | Use a ready-made public-domain 8x8 font bitmap. Don't write glyphs from scratch. |
| **Spriter overwhelmed by 30-sprite workload** | **High** | **High** | **Tell them today. Reduce to 6-8 per tier (18-24 total) if needed. Also confirm format Day 1: 32×32, indexed, VGA palette, raw byte export, ordered Easy/Med/Hard.** |
| Audio doesn't play in DOSBox | Low | High | Check `dosbox.conf` has `pcspeaker=true`. Test Day 2. |
| Teammate flakes | Medium | Medium | Tasks assigned smallest → hardest. If Dev 3 drops, Dev 1 picks up their ~6 hours. |
| Scope creep (adding features) | **Very High** | **Very High** | **Strictly ship MVP first. Every "wouldn't it be cool if" goes into a `POLISH_IDEAS.txt` file. Only implement after Day 5.** |
| Integration day (Day 5) reveals misaligned contracts | High | Medium | Standups on Days 2 and 4 — each dev demos what they have. Catch mismatches early. |
| `TIER_TABLE` index math is wrong | Medium | Medium | Always verify with a standalone test: load tier 0/1/2 and print the first word before integrating. |
| Data segment exceeds 64KB | Low | Critical | Current estimate is ~33KB. Do not add more assets without recalculating. Sprite size is the main variable. |
| File I/O doesn't persist between DOSBox sessions | Low | High | Check DOSBox mount is writable. Test Day 4. |

---

# Appendices

## A. TASM Cheatsheet

### File Skeleton
```asm
.MODEL SMALL
.STACK 1024           ; only in MAIN
.DATA
    ; data goes here
.CODE
    ; code goes here
END                   ; END label only in MAIN
```

### Common Directives
| Directive | Meaning |
|---|---|
| `DB` | Define byte (8-bit) |
| `DW` | Define word (16-bit) |
| `DUP(0)` | Duplicate (for arrays) — `10 DUP(0)` = 10 zero bytes |
| `EQU` | Compile-time constant — `MAX_HEARTS EQU 3` |
| `PROC` / `ENDP` | Begin/end a procedure |
| `PUBLIC` | Export a symbol |
| `EXTRN` | Import a symbol from another module |
| `OFFSET` | Address of a label in its segment |
| `LEA` | Load effective address (runtime OFFSET) |

### Register Quick Reference
| Register | Common Use |
|---|---|
| `AX`/`AH`/`AL` | Accumulator; INT return values; arithmetic |
| `BX`/`BH`/`BL` | Base pointer; general purpose |
| `CX`/`CH`/`CL` | Counter (for `LOOP`, `REP`); general purpose |
| `DX`/`DH`/`DL` | Data; I/O port number; `DX:AX` for 32-bit math |
| `SI` | Source index (for `LODS`, `MOVS`) |
| `DI` | Destination index (for `STOS`, `MOVS`) |
| `BP` | Base pointer (stack frames) |
| `SP` | Stack pointer |
| `CS` | Code segment |
| `DS` | Data segment (set to @DATA at startup) |
| `ES` | Extra segment (often `A000h` for video) |
| `SS` | Stack segment |

## A.1 TASM 4.1 Quirks — Dos & Don'ts

The toolchain is **TASM 4.1** specifically — not 5.x, not MASM, not NASM. A few
4.1-specific gotchas have already cost real time on this project. Internalize these
before writing data-heavy modules. (LLM users: the same content is in
`.claude/skills/tasm-conventions/SKILL.md` and auto-loads on assembly tasks.)

### Parser limits (confirmed in this project)

- **DON'T** put more than ~15 comma-separated values on a single `DB`/`DW` line.
  TASM 4.1's parser state degrades after a critical mass of long-operand directives
  in the same module — symptoms surface later in the file as "Undefined symbol: DW"
  or "CS unreachable from current segment". `sprite_export.py` chunks at 8 values
  per line for this reason; preserve that when regenerating sprite data.
- **DO** keep each `.DATA` segment well below the 64K theoretical max. Past ~30K of
  initialized constants, split into a second `.ASM` module and link them.
- **DON'T** pack multiple `DW OFFSET <label>` entries on one line in a jump/dispatch
  table — one per line. SOUND_TABLE hit "CS unreachable" errors yesterday from this.

### Build invocation

- **DO** use `/isrc` (joined, no space) — `tasm /zi /isrc src\FOO.ASM, build\FOO.OBJ`.
- **DON'T** assume `tasm /isrc src\FOO.ASM, build\FOO.OBJ` reliably writes the .OBJ
  to a nested `build\` directory. TASM 4.1's output-path handling is fragile.
  `BUILD.BAT`'s `:TEST_DT` target uses a `copy`+`del` workaround — copy that pattern
  for any new target that hits "Error writing object file".
- **DO** keep multi-pass mode (`/m5`, the default). Forward `OFFSET`/`SEG` references
  in tables only resolve under multi-pass.

### CPU and instruction set

- **DON'T** use `.586`, `.686`, MMX/SSE mnemonics, or any 32-bit register. The target
  CPU is 8086 in DOSBox real mode; later instructions are invalid regardless of what
  TASM 4.1 might parse. The `.claude/scripts/check_asm_write.py` PreToolUse hook
  blocks these on save.
- **DON'T** use ideal-mode-only syntax. This project uses MASM-mode syntax exclusively.

### When debugging a strange error

- **DO** check `.claude/bugs/BUG-2026-05-09-TASM4-parse-limit.md` first if you see
  "Undefined symbol: DW" or "CS unreachable" — it's almost certainly the parser-state
  quirk, not a real syntax error.
- **DON'T** propose "upgrade to TASM 5.0" as a fix. The project is fixed on 4.1.

## B. Interrupt Quick Reference

### INT 21h — DOS Services
| AH | Function |
|---|---|
| 01h | Read char from stdin (echoed) |
| 02h | Write char to stdout |
| 09h | Write $-terminated string to stdout |
| 0Ah | Buffered input |
| 3Ch | Create/truncate file (CX=attr, DS:DX=name) |
| 3Dh | Open file (AL=mode, DS:DX=name) |
| 3Eh | Close file (BX=handle) |
| 3Fh | Read file (BX=handle, CX=bytes, DS:DX=buffer) |
| 40h | Write file (BX=handle, CX=bytes, DS:DX=buffer) |
| 4Ch | Terminate program (AL=exit code) |

### INT 10h — BIOS Video
| AH | Function |
|---|---|
| 00h | Set video mode (AL=mode; 13h=VGA, 03h=text) |
| 0Ch | Write pixel (AL=color, CX=x, DX=y) — slow, don't use in loops |
| 13h | Write string |

### INT 16h — BIOS Keyboard
| AH | Function |
|---|---|
| 00h | Read key (blocks). AH=scan, AL=ASCII |
| 01h | Check buffer (non-block). ZF=1 if empty |

### INT 1Ah — BIOS Time
| AH | Function |
|---|---|
| 00h | Get tick count. CX:DX = ticks since midnight (18.2/sec) |

### INT 15h — BIOS Misc
| AH | Function |
|---|---|
| 86h | Microsecond wait (CX:DX = microseconds) |

### PC Speaker Ports (not interrupts)
| Port | Use |
|---|---|
| 42h | PIT channel 2 data (speaker freq) |
| 43h | PIT control register |
| 61h | System port (bits 0-1 = speaker enable) |

## C. Glossary

| Term | Meaning |
|---|---|
| **Real mode** | 8086 native mode; no memory protection; 20-bit addressing |
| **Segment:offset** | Address format; physical = segment × 16 + offset |
| **Interrupt** | Software-triggered call into BIOS/DOS service |
| **ISR** | Interrupt service routine (the handler) |
| **Mode 13h** | VGA graphics mode, 320×200, 256 colors |
| **Framebuffer** | Memory region whose contents = the screen |
| **PIT** | Programmable Interval Timer (chip used for speaker, scheduling) |
| **BIOS tick** | 18.2 Hz counter at `0040:006C`, used for rough timing |
| **TASM** | Turbo Assembler — Borland's x86 assembler |
| **TLINK** | Turbo Linker — combines `.OBJ` files into `.EXE` |
| **PROC / ENDP** | TASM syntax for defining a callable routine |
| **PUBLIC / EXTRN** | Cross-module symbol export/import |
| **`.MODEL SMALL`** | Memory model: one code seg + one data seg, max 64KB each |
| **Jump table** | Array of code pointers; `JMP [table+index]` dispatches fast |
| **`.DATA` vs `.CODE`** | Segments for mutable/constant data vs executable instructions |

---

# 🛑 Document Status

**Version:** 1.1 — Difficulty modes revision
**Changes from v1.0:** Added 3-tier difficulty system (Easy/Medium/Hard), 10 words per tier (30 total), `STATE_DIFF` screen, `DIFFICULTY` global, `TIER_TABLE` architecture, updated leaderboard record format (8 bytes, includes difficulty byte), updated all affected modules (DATA, MAIN, STATE, SCR_INTRO, SCR_GAME, SCR_END, FILEIO), updated memory map, risks, and integration contracts.
**Ready for:** Implementation Day 1
**Pending:** Study Guide update (Task 2 revision) — see `STUDY_GUIDE.md`

**Update this doc when:**
- A module's procedure signature changes
- A new screen or state is added
- Memory layout changes
- Team assignments shift
