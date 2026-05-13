# 🎮 Spelling Game — MVP Implementation Document

> **Project:** Educational Spelling Game for Toddlers
> **Platform:** Intel 8086 (16-bit Real Mode) via DOSBox
> **Toolchain:** TASM 5.0 + TLINK
> **Team:** 3 devs + 1 spriter
> **Timeline:** 1-week sprint → realistically ~2 weeks given v1.2 scope (3-week deadline buffer)
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
  - 4.2 `GFX.ASM` — Graphics (Mode 13h, Backgrounds, Sprite Rendering)
  - 4.3 `AUDIO.ASM` — PC Speaker Sound Cues
  - 4.4 `FILEIO.ASM` — Leaderboard Persistence
- **Chapter 5 — Screen Modules** *(technical)*
  - 5.1 `SCR_INTRO.ASM` — Title + Mode + Name Entry + Difficulty + Instructions
  - 5.2 `SCR_GAME.ASM` — Main Gameplay Screen (1P + 2P)
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

| Decision                           | Choice                                                                                       | Rationale                                                                                |
| ---------------------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Code organization**              | Multiple `.ASM` files linked into one `.EXE`                                                 | Enables parallel dev work; isolates bugs; mandatory for 3-dev team                       |
| **Memory model**                   | `.MODEL SMALL`                                                                               | One 64KB code segment, one 64KB data segment — more than enough                          |
| **Graphics mode**                  | VGA Mode 13h (320×200, 256 colors)                                                           | Industry-standard 8086 graphics mode; simple linear framebuffer at `A000h`               |
| **Screen backgrounds** *(v1.2)*    | **Disk-loaded full-screen `.BIN` images, blitted to `A000h`**                                | 64,000 bytes each — too big for `.MODEL SMALL` data segment. Disk load is the only path. |
| **Audio approach**                 | **PC Speaker beeps/tones**                                                                   | Senior project used the same — confirmed-passing bar. Sound Blaster DAC is scope creep.  |
| **Difficulty modes**               | **3 tiers: Easy / Medium / Hard** (word-length based)                                        | Required by prof                                                                         |
| **Object count**                   | **10 words per tier = 30 total** (Easy: short, Medium: mid, Hard: long)                      | Prof required more words; word-length tiers are the difficulty axis                      |
| **Word list architecture**         | **Option A: 3 separate arrays** (`EASY_WORDS`, `MED_WORDS`, `HARD_WORDS`)                    | Simpler pointer math than flat-list-with-tags; no searching needed                       |
| **Player modes** *(v1.2)*          | **1P (solo) and 2P (hot-seat versus)**                                                       | Prof addition; same keyboard, alternating answers, joint judgment                        |
| **2P round structure** *(v1.2)*    | Same word for both players, P1 answers then P2 answers, judge both, advance                  | Cleanest pacing; state machine stays simple (loop inside `SCR_ROUND_RUN`)                |
| **2P fairness** *(v1.2)*           | **Accepted asymmetry — P2 sees P1's typing.** Toddler game; sound cue is the real challenge. | Documented limitation. Don't engineer around it for MVP.                                 |
| **Name input length**              | 3 characters (arcade-style)                                                                  | Matches spec                                                                             |
| **Starting hearts**                | 3 per player                                                                                 | Standard game feel                                                                       |
| **Leaderboard size**               | Top 5 entries, stored in `SCORES.DAT`                                                        | Prof wants difficulty on leaderboard                                                     |
| **Leaderboard 2P policy** *(v1.2)* | **One entry per player** (a 2P match writes two independent records)                         | Simpler than match records; reuses 8B format unchanged                                   |
| **Leaderboard record**             | Name (3B) + Score (2B) + Difficulty (1B) + padding (2B) = 8B per entry                       | Stores difficulty for display: `AAA \| 240pts \| HARD`                                   |
| **Character encoding**             | ASCII uppercase only                                                                         | Simpler comparison logic; toddler-friendly                                               |

---

# Chapter 1 — High-Level System Architecture

## 1.1 What the Game Does

The game is a **state-machine driven application** that cycles through distinct screens. At its core, it's a loop that:

1. Shows the player a **picture** of an object (e.g., apple) composited over a designed background.
2. Plays a **sound cue** (an audio pattern recognizable as that object).
3. Waits for the player(s) to **type the spelling**. In 2P mode, P1 answers first, then P2.
4. **Compares** input to the correct answer.
5. Updates **score** (based on speed) or **hearts** (on wrong answer), per player.
6. Repeats with the next object, or ends the game.

Around this core loop, there's an **intro flow** (title → mode select → name entry → difficulty → instructions) and an **end flow** (final score → leaderboard → game over). Between rounds, the game saves high scores to disk so they persist across sessions.

Think of it as **7 screens connected by a state machine**, with 4 reusable I/O services (graphics, audio, keyboard, file) that each screen calls into. Every screen renders a disk-loaded full-screen background as its first paint operation, then composites sprites and text on top.

## 1.2 The Five Subsystems

The codebase is organized into five conceptual layers. Everything we build maps into one of these:

```
┌─────────────────────────────────────────────────────────────┐
│                    GAME LOGIC LAYER                         │
│  (Screens, State Machine, Word List, Score, Hearts,         │
│   Player Indexing for 1P/2P)                                │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   GRAPHICS    │  │    AUDIO      │  │    INPUT      │
│ (Mode 13h     │  │ (PC Speaker   │  │ (Keyboard via │
│  bg load +    │  │  tones)       │  │  INT 16h)     │
│  sprite draw) │  │               │  │               │
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

- **Game Logic Layer** — Knows the *rules* (what's a correct answer, when to lose a heart, whose turn it is). Owns game state. Decides what screen comes next.
- **Graphics Subsystem** — Knows how to put pixels on screen. Now includes *loading full-screen backgrounds from disk* into the framebuffer. Has no idea what an "apple" is; just draws whatever sprite data it's handed.
- **Audio Subsystem** — Knows how to make the speaker beep at a frequency for a duration. Has no idea about spelling.
- **Input Subsystem** — Knows how to read the keyboard. Returns characters; doesn't judge them.
- **File I/O Subsystem** — Knows how to read/write the leaderboard file. Doesn't care about score semantics.

**Why this separation matters:** Each dev can work on their subsystem independently. When you're writing audio, you don't need to know anything about sprites. When you're writing the game loop, you just call `CALL PLAY_APPLE_SOUND` and trust it works.

> 📌 **v1.2 note:** `GFX_LOAD_BG` reads from disk but writes directly to video memory at `A000h`. It uses `INT 21h` internally but is logically a graphics operation, not a file operation, so it lives in `GFX.ASM`. `FILEIO.ASM` remains scoped to the structured leaderboard data only.

## 1.3 Game State Machine

The entire program is one big state machine. At any moment, the game is in exactly **one state**, and transitions to another state based on events (key press, time elapsed, conditions met).

```
       ┌──────────────┐
       │ STATE_TITLE  │  ◄───────── program entry
       └──────┬───────┘
              │  [any key]
              ▼
       ┌──────────────┐
       │ STATE_MODE   │  (1P or 2P)                  ← NEW (v1.2)
       └──────┬───────┘
              │  [1 / 2 key]
              ▼
       ┌──────────────┐
       │  STATE_NAME  │  (loops NUM_PLAYERS times)   ← MODIFIED (v1.2)
       └──────┬───────┘
              │  [ENTER after 3 chars × NUM_PLAYERS]
              ▼
       ┌──────────────┐
       │  STATE_DIFF  │  (select Easy / Medium / Hard, shared by both players)
       └──────┬───────┘
              │  [1 / 2 / 3 key]
              ▼
       ┌──────────────┐
       │ STATE_INSTR  │  (show "type what you hear")
       └──────┬───────┘
              │  [any key]
              ▼
       ┌──────────────┐
       │ STATE_ROUND  │  ◄─── loops for each word; in 2P, both players answer per round
       └──────┬───────┘
              │  [both players' answers submitted]
              ▼
       ┌──────────────┐
       │ STATE_JUDGE  │  (judge both players, update both scores/hearts)
       └──────┬───────┘
              │
     ┌────────┴────────┐
     │                 │
 all hearts > 0     any player hearts = 0
 AND words left?    OR no words left?
     │                 │
     └──► STATE_ROUND  ▼
              ┌──────────────┐
              │  STATE_END   │  (both scores side-by-side, leaderboard)
              └──────┬───────┘
                     │  [any key]
                     ▼
              ┌──────────────┐
              │  STATE_QUIT  │ ──► return to DOS
              └──────────────┘
```

**State constants (v1.2 — renumbered to insert MODE):**

```
STATE_TITLE  = 0
STATE_MODE   = 1     ← NEW
STATE_NAME   = 2     (was 1)
STATE_DIFF   = 3     (was 2)
STATE_INSTR  = 4     (was 3)
STATE_ROUND  = 5     (was 4)
STATE_JUDGE  = 6     (was 5)
STATE_END    = 7     (was 6)
STATE_QUIT   = 8     (was 7)
```

Because all state references in code use the named `EQU` constant, no code changes are needed beyond updating `SHARED.INC`. Just be aware if you're staring at hex dumps.

**Why no STATE_ROUND_P1 / STATE_ROUND_P2?** The two-player turn loop happens *inside* `SCR_ROUND_RUN`, not in the state machine. `SCR_ROUND_RUN` reads `NUM_PLAYERS` and iterates `CURRENT_PLAYER` from 0 to N-1 internally. Same for `SCR_NAME_RUN`. This keeps the state machine flat and identical between 1P and 2P modes.

## 1.4 Data Flow

Where does the data live, and how does it move?

```
┌─────────────────────────────────────────┐
│  DATA SEGMENT (static, known at compile)│
│  ─────────────────────────────────────  │
│  • EASY_WORDS:  "CAT", "DOG", ...  (10) │
│  • MED_WORDS:   "APPLE", "TRAIN",. (10) │
│  • HARD_WORDS:  "ORANGE", "BRIDGE" (10) │
│  • SPRITE_TABLE: 30 sprites × 1KB each  │
│  • SOUND_PATTERNS: one array per word   │
│  • UI strings: "GAME OVER", etc.        │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  RUNTIME STATE (updated as game plays)  │
│  ─────────────────────────────────────  │
│  • CURRENT_STATE   (byte)               │
│  • NUM_PLAYERS     (byte: 1 or 2)       │  ← NEW (v1.2)
│  • CURRENT_PLAYER  (byte: 0 or 1)       │  ← NEW (v1.2)
│  • DIFFICULTY      (byte: 0=E, 1=M, 2=H)│
│  • CURRENT_WORD    (index 0..9)         │
│  • PLAYER_NAMES    (2 × 3 chars = 6B)   │  ← CHANGED (was PLAYER_NAME, 3B)
│  • SCORES          (2 × word = 4B)      │  ← CHANGED (was SCORE, 1 word)
│  • HEARTS_ARR      (2 × byte = 2B)      │  ← CHANGED (was HEARTS, 1 byte)
│  • PLAYER_RESULTS  (2 × byte = 2B)      │  ← NEW (v1.2): right/wrong this round
│  • PLAYER_TIMES    (2 × word = 4B)      │  ← NEW (v1.2): per-player timer for scoring
│  • TIMER_START     (word, BIOS ticks)   │
│  • INPUT_BUFFER    (17 chars, reused per player)│
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  PERSISTENT STORAGE (disk)              │
│  ─────────────────────────────────────  │
│  • SCORES.DAT  — top 5 leaderboard      │
│    Format: 5 × { name(3) + score(2)     │
│                 + difficulty(1) + pad(2)│
│    A 2P match inserts BOTH players      │
│    as independent records (v1.2).       │
│  • TITLE.BIN, MODE.BIN, NAME.BIN,       │  ← NEW (v1.2)
│    DIFF.BIN, INSTR.BIN, ROUND.BIN,      │
│    END.BIN — 64,000 bytes each, raw     │
│    Mode 13h framebuffer dumps           │
└─────────────────────────────────────────┘
```

> 📌 **1P note on player arrays:** In 1P mode, `NUM_PLAYERS=1` and `CURRENT_PLAYER` is always 0. Only `PLAYER_NAMES[0]`, `SCORES[0]`, `HEARTS_ARR[0]` are touched. Slots [1] sit unused. This is the cost of a unified code path — minor and worth it.

## 1.5 Runtime Environment & Memory Map

When the `.EXE` runs under DOSBox, the machine looks like this:

- **CPU:** Emulated 8086, 16-bit registers, real mode (no memory protection).
- **RAM:** 640 KB conventional memory; we use a tiny fraction.
- **Video memory:** `A000:0000` (Mode 13h framebuffer, 64000 bytes = 320×200 pixels × 1 byte each). Backgrounds load directly here.
- **BIOS data area:** `0040:006C` holds a timer that ticks 18.2 times per second — our scoring clock.
- **DOS services:** Accessed via `INT 21h` (file I/O, console I/O, exit).
- **BIOS services:** Accessed via `INT 10h` (video), `INT 16h` (keyboard).

**Our program's memory footprint (approximate):**

| Section                         | Size                             | Contents                                                                            |
| ------------------------------- | -------------------------------- | ----------------------------------------------------------------------------------- |
| Code segment                    | ~7-11 KB                         | All the `.ASM` modules compiled together (+~1KB for v1.2 additions)                 |
| Data segment                    | ~33 KB                           | 30 sprites × 1KB + word lists + strings + variables + player arrays (~20B v1.2 add) |
| Stack segment                   | 1 KB                             | Function call stack                                                                 |
| **Total (in-EXE)**              | **~41-45 KB**                    | Within 64 KB `.MODEL SMALL` limit — comfortable                                     |
| **External `.BIN` backgrounds** | **~7 × 64 KB = ~448 KB on disk** | Not in EXE; streamed to `A000h` on demand                                           |

> ⚠️ **Why backgrounds are NOT in the data segment:** One 320×200 background is 64,000 bytes — almost a full data segment by itself. Even one would crowd out the sprite table. Disk-loading is the only viable path under `.MODEL SMALL`. The 64KB-per-image cost is paid on disk, not in RAM.

> ⚠️ **Data segment warning:** 30 sprites × 1024 bytes = 30,720 bytes. Add word lists (~480 bytes), sound patterns (~1KB), strings, and variables (now including 2P player arrays, ~20B) — total is ~33KB. Well under 64KB. Do **not** increase sprite size to 64×64 without recalculating.

## 1.6 Key Design Decisions (and Why)

- **PC Speaker audio, not Sound Blaster.** Senior project did beeps and passed. Sound Blaster requires DMA programming, IRQ handling, and `.WAV` parsing — easily 3-5 days of work alone. We buy that time back and spend it on polish.
- **Mode 13h graphics, not text mode.** Prof wants real sprites. Mode 13h is the easiest pixel-graphics mode: one byte per pixel, linear layout, no planar headaches.
- **Disk-loaded backgrounds, not embedded.** *(v1.2)* Each full-screen image is 64,000 bytes — physically cannot fit multiple in the `.MODEL SMALL` data segment. `GFX_LOAD_BG` reads a `.BIN` file straight into `A000h` via `INT 21h`. Replaces the old `GFX_CLEAR` pattern at the start of each screen handler.
- **Transparent sprite compositing.** Color 0 in sprite data is treated as transparent — the background pixel shows through. Already the contract in Chapter 4.2; with v1.2 backgrounds, this is what enables sprite-on-background composition with no new logic.
- **30 words across 3 difficulty tiers (10 each).** Prof required more words and difficulty modes. Word length defines difficulty.
- **Option A word list architecture (3 separate arrays).** `DIFFICULTY` byte indexes `TIER_TABLE` to get the base pointer. Zero searching, simple pointer math.
- **Difficulty stored in leaderboard.** Each leaderboard entry includes a `DIFFICULTY` byte for display.
- **Hot-seat 2P, not simultaneous.** *(v1.2)* `INT 16h` gives one keyboard buffer. Simultaneous would mean splitting keys by region or polling timing tricks — not worth it for toddlers. Hot-seat keeps `INP_READ_STRING` unchanged.
- **Same word for both players in 2P.** *(v1.2)* Cleaner pacing, more competitive feel, and one word advance per round (not per turn). Trade-off: P2 watches P1 type — accepted asymmetry; toddler-scale this is fine.
- **Two-player loop *inside* `SCR_ROUND_RUN`, not in state machine.** *(v1.2)* Keeps state machine flat. `SCR_ROUND_RUN` iterates `CURRENT_PLAYER` from 0 to `NUM_PLAYERS-1`. 1P is the same code path with the loop running once.
- **One leaderboard entry per player per 2P match.** *(v1.2)* No file format change needed — existing 8B record works. Both players' final scores get inserted independently; whoever ranked higher in the top 5 just shows up higher.
- **End condition in 2P:** game ends when *either* player hits 0 hearts OR all 10 words are consumed. The other player is robbed of any remaining attempts. Documented limitation; simpler than independent end-tracking.
- **Modular `.ASM` files.** A 3-dev team cannot work in one file without merge pain.
- **State machine pattern.** Easy to debug, easy to extend.
- **Data-driven word list.** Adding a word means adding data, not code.

---

# Chapter 2 — Code Modules & File Structure

## 2.1 File Layout

```
spelling_game/
├── src/
│   ├── MAIN.ASM          ← Entry point + main loop
│   ├── STATE.ASM         ← State dispatcher + transitions
│   ├── DATA.ASM          ← Word list, sprite data, sound data, strings
│   │
│   ├── GFX.ASM           ← Mode 13h primitives + GFX_LOAD_BG  ← v1.2
│   ├── AUDIO.ASM         ← PC speaker tone/pattern playback
│   ├── INPUT.ASM         ← Keyboard read routines
│   ├── FILEIO.ASM        ← Leaderboard file read/write
│   │
│   ├── SCR_INTRO.ASM     ← Title, mode, name, difficulty, instructions
│   ├── SCR_GAME.ASM      ← Round + judge (1P/2P unified)
│   ├── SCR_END.ASM       ← Score + leaderboard + game over
│   │
│   └── SHARED.INC        ← Shared constants, macros, EXTRN decls
│
├── assets/
│   ├── sprites/          ← PNG mockups from spriter (reference only)
│   ├── sprite_bytes.txt  ← Exported raw byte arrays, paste into DATA.ASM
│   └── backgrounds/      ← v1.2: full-screen mockups (reference)
│       ├── TITLE.BIN     ← 64,000 bytes each, raw Mode 13h dump
│       ├── MODE.BIN
│       ├── NAME.BIN
│       ├── DIFF.BIN
│       ├── INSTR.BIN
│       ├── ROUND.BIN
│       └── END.BIN
│
├── build/
│   ├── BUILD.BAT         ← Assemble + link all modules
│   └── CLEAN.BAT         ← Delete .OBJ and .EXE
│
├── bin/
│   ├── SPELL.EXE         ← The shipping executable
│   ├── SCORES.DAT        ← Leaderboard save file (created at runtime)
│   ├── TITLE.BIN         ← v1.2: copied from assets/backgrounds/
│   ├── MODE.BIN          ← must be present at runtime, same dir as EXE
│   ├── NAME.BIN
│   ├── DIFF.BIN
│   ├── INSTR.BIN
│   ├── ROUND.BIN
│   └── END.BIN
│
└── docs/
    ├── SPEC.md                ← This file
    └── STUDY_GUIDE.md         ← Dev learning roadmap
```

> 📌 **Background file naming:** All filenames are DOS 8.3 compliant. They live alongside `SPELL.EXE` and `SCORES.DAT` in `bin/` because `INT 21h` opens them with relative paths from the current working directory.

## 2.2 Module Responsibilities

### Core Engine

| Module      | Owns                                               | Exports                                                                                                  |
| ----------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `MAIN.ASM`  | Program entry, global game loop, all runtime state | (none — it's the top level)                                                                              |
| `STATE.ASM` | `CURRENT_STATE` byte, transition logic             | `GAME_TICK`                                                                                              |
| `DATA.ASM`  | All static game data                               | Labels: `EASY_WORDS`, `MED_WORDS`, `HARD_WORDS`, `TIER_TABLE`, `SPRITE_TABLE`, `SOUND_TABLE`, UI strings |

### I/O Services

| Module       | Owns                                                          | Exports                                                                                                       |
| ------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `GFX.ASM`    | Video mode, drawing primitives, **background loading (v1.2)** | `GFX_INIT`, `GFX_CLEAR`, `GFX_LOAD_BG`, `GFX_DRAW_SPRITE`, `GFX_DRAW_CHAR`, `GFX_DRAW_STRING`, `GFX_SHUTDOWN` |
| `AUDIO.ASM`  | Speaker port control                                          | `SND_PLAY_PATTERN`, `SND_SILENCE`                                                                             |
| `INPUT.ASM`  | Keyboard polling                                              | `INP_WAIT_KEY`, `INP_CHECK_KEY`, `INP_READ_STRING`                                                            |
| `FILEIO.ASM` | Leaderboard disk I/O                                          | `FILE_LOAD_SCORES`, `FILE_SAVE_SCORES`, `FILE_INSERT_SCORE`                                                   |

### Screen Handlers

| Module          | Owns                                          | Exports                                                                                   |
| --------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `SCR_INTRO.ASM` | Title, mode, name, difficulty, instructions   | `SCR_TITLE_RUN`, `SCR_MODE_RUN` *(v1.2)*, `SCR_NAME_RUN`, `SCR_DIFF_RUN`, `SCR_INSTR_RUN` |
| `SCR_GAME.ASM`  | Round logic (with 2P loop), scoring, judgment | `SCR_ROUND_RUN`, `SCR_JUDGE_RUN`                                                          |
| `SCR_END.ASM`   | Score display, leaderboard, 2P winner display | `SCR_END_RUN`                                                                             |

### Shared

| Module       | Contents                                                                                                                                                                                                                                                                                                                                                        |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SHARED.INC` | `EQU` constants (`STATE_TITLE=0`, `STATE_MODE=1`, `STATE_NAME=2`, `STATE_DIFF=3`, `STATE_INSTR=4`, `STATE_ROUND=5`, `STATE_JUDGE=6`, `STATE_END=7`, `STATE_QUIT=8`, `DIFF_EASY=0`, `DIFF_MED=1`, `DIFF_HARD=2`, `MAX_HEARTS=3`, `MAX_PLAYERS=2`, `WORDS_PER_TIER=10`, `WORD_RECORD_SIZE=16`, `SPRITE_SIZE=1024`, `BG_SIZE=64000`), macros, `EXTRN` declarations |

## 2.3 Module Interaction Map

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
         │                ├─► DATA         │
         │                                 │
         └─► (all screens read DATA for strings;
              all screens call GFX_LOAD_BG at entry — v1.2)
```

**Dependency rules:**

- Screen modules depend on service modules and `DATA`.
- Service modules are **independent** of each other.
- `STATE.ASM` calls into screen modules; screens only *update* the state byte.
- `DATA.ASM` is pure data — no code, no calls.
- `GFX.ASM` uses `INT 21h` directly for `GFX_LOAD_BG`; it does NOT call `FILEIO`. *(v1.2)*

## 2.4 Team Workload Assignment

> ⚠️ **v1.2 scope warning:** The original 1-week sprint estimate no longer fits. Backgrounds + 2P add ~3-5 dev-days and significant spriter work. The 3-week deadline buffer absorbs it; communicate the new ETA to the team.

### 🧑‍💻 Dev 1 — Lead (You)

- `MAIN.ASM`, `STATE.ASM`, `SHARED.INC`
- `SCR_INTRO.ASM` (incl. new `SCR_MODE_RUN`, modified `SCR_NAME_RUN` for 2P loop)
- `SCR_GAME.ASM` (incl. 2P round loop + judging both players)
- `SCR_END.ASM` (incl. side-by-side 2P score display + inserting both players)
- Integration, final debugging
- **~22 hours total** (was ~15; +7 for 2P plumbing)

### 🧑‍💻 Dev 2 — Graphics + Input

- `GFX.ASM` (Mode 13h, sprite draw, text draw, **+ `GFX_LOAD_BG` v1.2**)
- Font rendering with transparency (per Chapter 4.2 v1.2 note)
- `INPUT.ASM`
- **~10 hours total** (was ~7; +3 for `GFX_LOAD_BG` and font transparency)

### 🧑‍💻 Dev 3 — Audio + File I/O

- `AUDIO.ASM`
- `FILEIO.ASM` (no v1.2 changes — record format unchanged, just insert both players in 2P from `SCR_END_RUN`)
- **~6 hours total** (unchanged)

### 🎨 Spriter (parallel, off critical path)

- **30 × 32×32 sprites** in 16-color VGA palette (10 Easy + 10 Medium + 10 Hard)
- **7 × full-screen 320×200 backgrounds (v1.2)** — TITLE, MODE, NAME, DIFF, INSTR, ROUND, END
  - ROUND.BIN needs a reserved blank area where the sprite renders (around x=144, y=50) and where text labels go (status bar, prompts)
  - Export each as raw 64,000-byte `.BIN` file
- `DATA.ASM` population
- **~24-28 hours total** (was 15-18; +~10 for backgrounds)
- **TALK TO THEM TODAY.** Backgrounds add a third of their workload.

**Fallback if spriter capacity is genuinely insufficient:**

- Drop to 4 backgrounds (TITLE, ROUND, END, INSTR — reuse ROUND.BIN for JUDGE; reuse INSTR.BIN for MODE/NAME/DIFF)
- Drop sprite count to 6-8 per tier if needed

**If Dev 3 flakes:** Dev 1 absorbs `FILEIO.ASM`. Dev 2 absorbs `AUDIO.ASM`.

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

REM v1.2: copy background .BIN assets to runtime dir
copy assets\backgrounds\*.BIN bin\

echo Build complete: bin\SPELL.EXE
```

**Flags explained:**

- `/zi` on TASM — include debug info (remove for final)
- `/v` on TLINK — verbose link

### Workflow

1. Edit `.ASM` files in your host editor.
2. Switch to DOSBox, `cd` to project folder.
3. Run `BUILD.BAT`.
4. Run `bin\SPELL.EXE`.
5. Iterate.

---

# Chapter 3 — Core Engine Modules

## 3.1 `MAIN.ASM` — Entry Point & Game Loop

### Purpose

The top-level module. Owns program initialization, the main loop, and shutdown. Also declares all mutable runtime state as globals.

### Dependencies

- `STATE.ASM` (calls `GAME_TICK`)
- `GFX.ASM` (calls `GFX_INIT`, `GFX_SHUTDOWN`)
- `FILEIO.ASM` (calls `FILE_LOAD_SCORES`)
- `SHARED.INC`

### Structure (v1.2)

```asm
; MAIN.ASM — Entry point and game loop
.MODEL SMALL
.STACK 1024
.DATA
    INCLUDE SHARED.INC

    ; --- Runtime state (global variables) ---
    CURRENT_STATE   DB  STATE_TITLE
    NUM_PLAYERS     DB  1              ; ← NEW (v1.2): 1 or 2
    CURRENT_PLAYER  DB  0              ; ← NEW (v1.2): 0 or 1
    DIFFICULTY      DB  DIFF_EASY
    CURRENT_WORD    DB  0
    TIMER_START     DW  0

    ; --- Player-indexed arrays (v1.2) ---
    PLAYER_NAMES    DB  '   ', '   '   ; 2 × 3-char names
    SCORES          DW  0, 0           ; 2 × 16-bit score
    HEARTS_ARR      DB  MAX_HEARTS, MAX_HEARTS
    PLAYER_RESULTS  DB  0, 0           ; right/wrong each player this round
    PLAYER_TIMES    DW  0, 0           ; per-player elapsed ticks for scoring

    INPUT_BUFFER    DB  17 DUP(0)      ; shared, used by current player

    PUBLIC CURRENT_STATE, NUM_PLAYERS, CURRENT_PLAYER, DIFFICULTY
    PUBLIC CURRENT_WORD, TIMER_START
    PUBLIC PLAYER_NAMES, SCORES, HEARTS_ARR, PLAYER_RESULTS, PLAYER_TIMES
    PUBLIC INPUT_BUFFER

.CODE
    EXTRN GAME_TICK:PROC
    EXTRN GFX_INIT:PROC, GFX_SHUTDOWN:PROC
    EXTRN FILE_LOAD_SCORES:PROC

MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    CALL GFX_INIT
    CALL FILE_LOAD_SCORES

GAME_LOOP:
    CALL GAME_TICK
    CMP CURRENT_STATE, STATE_QUIT
    JNE GAME_LOOP

    CALL GFX_SHUTDOWN
    MOV AH, 4Ch
    MOV AL, 0
    INT 21h
MAIN ENDP
END MAIN
```

### Design Notes (v1.2 additions)

- **Player arrays are byte/word-indexed by `CURRENT_PLAYER`.** Read pattern:
  
  ```asm
  MOV BL, CURRENT_PLAYER
  MOV BH, 0
  SHL BX, 1                  ; for word array (SCORES, PLAYER_TIMES)
  MOV AX, SCORES[BX]
  ```
  
  For byte array (`HEARTS_ARR`, `PLAYER_RESULTS`): skip the `SHL`.

- **`NUM_PLAYERS` is set once** by `SCR_MODE_RUN` and never changes during a session.

- **`CURRENT_PLAYER` rotates** during round/name entry. Always reset to 0 before the loop.

### Integration Contract

- **Inputs:** None.
- **Outputs:** Sets up `DS`, runs main loop, exits to DOS.
- **Called by:** DOS.
- **Calls:** `GAME_TICK`, `GFX_INIT`, `GFX_SHUTDOWN`, `FILE_LOAD_SCORES`.

---

## 3.2 `STATE.ASM` — Game State Machine

### Purpose

Dispatches the current game state to the correct screen handler.

### Dependencies

- All `SCR_*.ASM` modules
- `SHARED.INC`

### Structure (v1.2)

```asm
; STATE.ASM — State dispatcher
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE

.CODE
    EXTRN SCR_TITLE_RUN:PROC
    EXTRN SCR_MODE_RUN:PROC         ; ← NEW (v1.2)
    EXTRN SCR_NAME_RUN:PROC
    EXTRN SCR_DIFF_RUN:PROC
    EXTRN SCR_INSTR_RUN:PROC
    EXTRN SCR_ROUND_RUN:PROC
    EXTRN SCR_JUDGE_RUN:PROC
    EXTRN SCR_END_RUN:PROC

    PUBLIC GAME_TICK

GAME_TICK PROC
    MOV AL, CURRENT_STATE

    CMP AL, STATE_TITLE
    JE  GT_TITLE
    CMP AL, STATE_MODE              ; ← NEW (v1.2)
    JE  GT_MODE                     ; ← NEW (v1.2)
    CMP AL, STATE_NAME
    JE  GT_NAME
    CMP AL, STATE_DIFF
    JE  GT_DIFF
    CMP AL, STATE_INSTR
    JE  GT_INSTR
    CMP AL, STATE_ROUND
    JE  GT_ROUND
    CMP AL, STATE_JUDGE
    JE  GT_JUDGE
    CMP AL, STATE_END
    JE  GT_END
    RET

GT_TITLE:   CALL SCR_TITLE_RUN
            RET
GT_MODE:    CALL SCR_MODE_RUN       ; ← NEW (v1.2)
            RET
GT_NAME:    CALL SCR_NAME_RUN
            RET
GT_DIFF:    CALL SCR_DIFF_RUN
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

- Screen handlers are responsible for setting the next state.
- Jump-table optimization remains optional; defer until basic dispatch is proven.

### Integration Contract

- **Inputs:** Reads `CURRENT_STATE`.
- **Outputs:** Calls the appropriate screen handler.
- **Called by:** `MAIN.ASM`.
- **Calls:** All `SCR_*_RUN` procedures.

---

## 3.3 `DATA.ASM` — Word List & Assets

### Purpose

The project's "database." All compile-time-constant data.

### Structure (v1.2 strings additions only — word/sprite/sound sections unchanged from v1.1)

```asm
; DATA.ASM — Word list (3 tiers), sprite data, sound patterns, UI strings
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    ; [EASY_WORDS, MED_WORDS, HARD_WORDS, TIER_TABLE, SPRITE_TABLE,
    ;  SOUND_TABLE and all SND_* patterns are unchanged from v1.1
    ;  — refer to v1.1 spec for body. Kept here as reference.]

    ; --- UI strings ---
    PUBLIC STR_TITLE, STR_INSTR, STR_GAMEOVER, STR_WIN
    PUBLIC STR_DIFF_PROMPT, STR_EASY, STR_MED, STR_HARD
    PUBLIC STR_MODE_PROMPT, STR_1P, STR_2P            ; ← NEW (v1.2)
    PUBLIC STR_PLAYER1, STR_PLAYER2, STR_YOUR_TURN    ; ← NEW (v1.2)
    PUBLIC STR_VS, STR_WINNER, STR_TIE                ; ← NEW (v1.2)

STR_TITLE:       DB 'SPELLING FUN!',0
STR_INSTR:       DB 'TYPE WHAT YOU HEAR. PRESS ENTER.',0
STR_GAMEOVER:    DB 'GAME OVER',0
STR_WIN:         DB 'YOU DID IT!',0
STR_DIFF_PROMPT: DB 'CHOOSE DIFFICULTY:',0
STR_EASY:        DB '1. EASY',0
STR_MED:         DB '2. MEDIUM',0
STR_HARD:        DB '3. HARD',0

; --- 2-player UI strings (v1.2) ---
STR_MODE_PROMPT: DB 'CHOOSE MODE:',0
STR_1P:          DB '1. ONE PLAYER',0
STR_2P:          DB '2. TWO PLAYERS',0
STR_PLAYER1:     DB 'PLAYER 1',0
STR_PLAYER2:     DB 'PLAYER 2',0
STR_YOUR_TURN:   DB 'YOUR TURN!',0
STR_VS:          DB ' VS ',0
STR_WINNER:      DB 'WINNER: ',0
STR_TIE:         DB 'ITS A TIE!',0

    ; --- Background filenames (v1.2) ---
    PUBLIC BG_TITLE, BG_MODE, BG_NAME, BG_DIFF, BG_INSTR, BG_ROUND, BG_END
BG_TITLE:  DB 'TITLE.BIN',0
BG_MODE:   DB 'MODE.BIN',0
BG_NAME:   DB 'NAME.BIN',0
BG_DIFF:   DB 'DIFF.BIN',0
BG_INSTR:  DB 'INSTR.BIN',0
BG_ROUND:  DB 'ROUND.BIN',0
BG_END:    DB 'END.BIN',0

END
```

### Design Notes

- All v1.1 word/sprite/sound data is unchanged. Only strings added.
- Background filename strings centralized here so screens just reference labels (`LEA DX, BG_TITLE`).

### Integration Contract

- **Inputs:** None.
- **Outputs:** All labels exported via `PUBLIC`.

---

# Chapter 4 — I/O Modules

## 4.1 `INPUT.ASM` — Keyboard Input

Purpose

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

## 4.2 `GFX.ASM` — Graphics (Mode 13h, Backgrounds, Sprite Rendering)

### Purpose

All drawing goes through here. Screens tell it *what* to draw and *where*; `GFX.ASM` handles the pixel manipulation and **background loading from disk (v1.2)**.

### Dependencies

- Raw hardware + BIOS
- `INT 21h` for `GFX_LOAD_BG` (v1.2)

### Core Concepts

**Mode 13h:**

- Resolution: 320×200
- Colors: 256 (VGA palette)
- Framebuffer: at `A000:0000`, each byte = one pixel's palette index
- To plot a pixel: `ES:[DI] = color` where `DI = y*320 + x`, `ES = A000h`

**Backgrounds (v1.2):**

- Each background `.BIN` file is exactly 64,000 bytes, raw palette indices, row-major, top-left origin
- `GFX_LOAD_BG` opens the file, reads all 64,000 bytes directly to `A000:0000`, closes the file
- Sprites and text composite on top using existing transparency (color 0 = transparent)

### Structure (v1.2 — `GFX_LOAD_BG` added; other procs unchanged)

```asm
; GFX.ASM — Mode 13h graphics + background loading
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    BG_HANDLE  DW 0          ; ← NEW (v1.2): file handle for background loads

.CODE
    PUBLIC GFX_INIT, GFX_SHUTDOWN, GFX_CLEAR
    PUBLIC GFX_LOAD_BG                            ; ← NEW (v1.2)
    PUBLIC GFX_DRAW_SPRITE, GFX_DRAW_CHAR, GFX_DRAW_STRING

; [GFX_INIT, GFX_SHUTDOWN, GFX_CLEAR, GFX_DRAW_SPRITE unchanged from v1.1]

;---------------------------------------------------------------
; GFX_LOAD_BG — Load a 64,000-byte raw image into video memory.   ← NEW (v1.2)
; In:  DS:DX = pointer to null-terminated filename (e.g., 'TITLE.BIN',0)
; Out: framebuffer at A000h filled with image
; Preserves: AX, BX, CX, DX, SI, DI, ES
; Clobbers:  flags
; Side effect: sets ES = A000h on return (consistent with GFX_INIT)
;---------------------------------------------------------------
GFX_LOAD_BG PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    ; --- Open file for reading ---
    MOV  AH, 3Dh
    MOV  AL, 0                ; read-only
    INT  21h
    JC   GLB_ERROR
    MOV  BG_HANDLE, AX

    ; --- Read 64,000 bytes directly into video memory at A000:0000 ---
    MOV  AX, 0A000h
    MOV  ES, AX
    XOR  DI, DI               ; ES:DI = A000:0000

    MOV  AH, 3Fh
    MOV  BX, BG_HANDLE
    MOV  CX, BG_SIZE          ; 64000 (defined in SHARED.INC)
    PUSH DS
    PUSH ES
    POP  DS                   ; DOS read expects buffer in DS:DX
    MOV  DX, DI               ; DX = 0 (offset in A000:0000)
    INT  21h
    POP  DS

    ; --- Close file ---
    MOV  AH, 3Eh
    MOV  BX, BG_HANDLE
    INT  21h

GLB_ERROR:
    ; If file missing or read failed, framebuffer is left as-is.
    ; Caller should not assume background loaded on error.
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
GFX_LOAD_BG ENDP

; [GFX_DRAW_CHAR, GFX_DRAW_STRING unchanged from v1.1 except for transparency note below]
END
```

### Design Notes

- **`GFX_LOAD_BG` replaces `GFX_CLEAR` at the top of each screen handler.** Old pattern:
  
  ```asm
  MOV  AL, 1
  CALL GFX_CLEAR
  ```
  
  New pattern:
  
  ```asm
  LEA  DX, BG_TITLE
  CALL GFX_LOAD_BG
  ```

- **Error handling is silent.** If a `.BIN` file is missing, the framebuffer is left as-is. The first screen to fail will look like garbage, which is the right diagnostic signal — fail loud at runtime, not silent.

- **`DS:DX` for the filename, output to `ES:DI`.** The procedure handles segment register juggling internally. Caller doesn't need to set up segments beyond `DS=@DATA`.

- **`ES` is left as `A000h` on return.** This matches the post-`GFX_INIT` contract; subsequent sprite draws Just Work.

- **🔥 Font rendering must use sprite-style transparency (v1.2 critical).** When Dev 2 implements `GFX_DRAW_CHAR`, the inner loop must skip "off" pixels in the glyph bitmap rather than drawing them as black. Otherwise every text label punches a black rectangle through the background. Same `OR AL, AL / JZ skip` pattern as `GFX_DRAW_SPRITE`. **This is the #1 v1.2 implementation gotcha.**

- **`BG_SIZE` constant.** Defined in `SHARED.INC` as `BG_SIZE EQU 64000`. Use the constant; never hardcode 64000.

### Integration Contract (v1.2 additions)

- **`GFX_LOAD_BG`:**
  - **In:** `DS:DX` = filename
  - **Out:** Framebuffer at `A000h` filled; `ES=A000h` on return
  - **Preserves:** `AX, BX, CX, DX, SI, DI, ES`
  - **Clobbers:** flags
  - **Calls:** `INT 21h` (3Dh open, 3Fh read, 3Eh close)

---

## 4.3 `AUDIO.ASM` — PC Speaker Sound Cues

Purpose

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

Load and save the top-5 leaderboard to `SCORES.DAT`.

### v1.2 Changes

**Record format is unchanged.** The 8-byte record (Name 3B + Score 2B + Difficulty 1B + Pad 2B) remains the storage unit. **A 2-player match results in TWO calls to `FILE_INSERT_SCORE`** — once for each player. Each player competes for the same top-5 list independently. No mode flag needed on the record.

### Dependencies

- `SHARED.INC`
- `INT 21h` services

### File Format

Fixed-width binary record, 5 records max. Same as v1.1:

```
Record layout (8 bytes each):
  Offset 0-2:  3-byte name (ASCII, e.g. 'AAA')
  Offset 3-4:  16-bit score (little-endian word)
  Offset 5:    difficulty byte (0=Easy, 1=Med, 2=Hard)
  Offset 6-7:  2-byte padding (reserved, zeroed)

Total file size: 5 × 8 = 40 bytes fixed.
```

### Structure

Unchanged from v1.1. `FILE_INSERT_SCORE` still takes `(DS:SI=name, BX=score, AL=difficulty)` — `SCR_END_RUN` just calls it twice in 2P mode.

```asm
; In SCR_END_RUN (v1.2 — pseudocode for 2P leaderboard write):
;
;   ; Insert player 1
;   LEA  SI, PLAYER_NAMES          ; PLAYER_NAMES[0]
;   MOV  BX, SCORES                ; SCORES[0]
;   MOV  AL, DIFFICULTY
;   CALL FILE_INSERT_SCORE
;
;   ; Insert player 2 if 2P
;   CMP  NUM_PLAYERS, 2
;   JNE  SAVE_NOW
;   LEA  SI, PLAYER_NAMES+3        ; PLAYER_NAMES[1]
;   MOV  BX, SCORES+2              ; SCORES[1]
;   MOV  AL, DIFFICULTY
;   CALL FILE_INSERT_SCORE
;
;   SAVE_NOW:
;   CALL FILE_SAVE_SCORES
```

### Design Notes

- **Insertion order matters when scores tie:** insert P1 first, then P2. P1 takes precedence in tie-breaking under the current algorithm (first slot where existing < new). Document this in the help text if anyone asks.
- **No format version bump needed.** v1.1 `.DAT` files remain compatible. If you wipe `SCORES.DAT` between v1.1 and v1.2 testing, do so manually.

### Integration Contract

Unchanged from v1.1.

---

# Chapter 5 — Screen Modules

## 5.1 `SCR_INTRO.ASM` — Title + Mode + Name + Difficulty + Instructions

### Purpose

The "onboarding" sequence: title → **mode select (v1.2)** → name entry (loops in 2P) → difficulty → instructions.

### Screens Owned

1. **`SCR_TITLE_RUN`** — show title + "press any key"
2. **`SCR_MODE_RUN`** *(v1.2)* — 1P vs 2P selection
3. **`SCR_NAME_RUN`** — read 3 initials per player (loops `NUM_PLAYERS` times)
4. **`SCR_DIFF_RUN`** — Easy / Medium / Hard
5. **`SCR_INSTR_RUN`** — explain gameplay

### Dependencies

- `GFX.ASM` (`GFX_LOAD_BG`, `GFX_DRAW_STRING`)
- `INPUT.ASM`
- `DATA.ASM`
- External: `CURRENT_STATE`, `NUM_PLAYERS`, `CURRENT_PLAYER`, `PLAYER_NAMES`, `DIFFICULTY`

### Structure (v1.2 — key procs shown; others updated analogously)

```asm
; SCR_INTRO.ASM — Intro flow screens
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE
    EXTRN NUM_PLAYERS:BYTE, CURRENT_PLAYER:BYTE        ; ← NEW (v1.2)
    EXTRN PLAYER_NAMES:BYTE, DIFFICULTY:BYTE
    EXTRN STR_TITLE:BYTE, STR_INSTR:BYTE
    EXTRN STR_MODE_PROMPT:BYTE, STR_1P:BYTE, STR_2P:BYTE  ; ← NEW (v1.2)
    EXTRN STR_DIFF_PROMPT:BYTE, STR_EASY:BYTE, STR_MED:BYTE, STR_HARD:BYTE
    EXTRN STR_PLAYER1:BYTE, STR_PLAYER2:BYTE           ; ← NEW (v1.2)
    EXTRN BG_TITLE:BYTE, BG_MODE:BYTE, BG_NAME:BYTE    ; ← NEW (v1.2)
    EXTRN BG_DIFF:BYTE, BG_INSTR:BYTE

    PROMPT_NAME  DB  'ENTER INITIALS:',0
    PROMPT_KEY   DB  'PRESS ANY KEY',0

.CODE
    EXTRN GFX_LOAD_BG:PROC                              ; ← NEW (v1.2)
    EXTRN GFX_DRAW_STRING:PROC
    EXTRN INP_WAIT_KEY:PROC

    PUBLIC SCR_TITLE_RUN, SCR_MODE_RUN, SCR_NAME_RUN
    PUBLIC SCR_DIFF_RUN, SCR_INSTR_RUN

;---------------------------------------------------------------
; SCR_TITLE_RUN — Title screen. Any key → MODE select.
;---------------------------------------------------------------
SCR_TITLE_RUN PROC
    LEA  DX, BG_TITLE                  ; ← v1.2 (was GFX_CLEAR)
    CALL GFX_LOAD_BG

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

    MOV  CURRENT_STATE, STATE_MODE     ; ← v1.2 (was STATE_NAME)
    RET
SCR_TITLE_RUN ENDP

;---------------------------------------------------------------
; SCR_MODE_RUN — 1P or 2P select. Sets NUM_PLAYERS.   ← NEW (v1.2)
;---------------------------------------------------------------
SCR_MODE_RUN PROC
    LEA  DX, BG_MODE
    CALL GFX_LOAD_BG

    LEA  SI, STR_MODE_PROMPT
    MOV  BL, 15
    MOV  CX, 90
    MOV  DX, 70
    CALL GFX_DRAW_STRING

    LEA  SI, STR_1P
    MOV  CX, 100
    MOV  DX, 100
    CALL GFX_DRAW_STRING

    LEA  SI, STR_2P
    MOV  CX, 100
    MOV  DX, 120
    CALL GFX_DRAW_STRING

SMR_WAIT:
    CALL INP_WAIT_KEY
    CMP  AL, '1'
    JE   SMR_1P
    CMP  AL, '2'
    JE   SMR_2P
    JMP  SMR_WAIT

SMR_1P:
    MOV  NUM_PLAYERS, 1
    JMP  SMR_DONE
SMR_2P:
    MOV  NUM_PLAYERS, 2
SMR_DONE:
    MOV  CURRENT_PLAYER, 0             ; reset for name-entry loop
    MOV  CURRENT_STATE, STATE_NAME
    RET
SCR_MODE_RUN ENDP

;---------------------------------------------------------------
; SCR_NAME_RUN — Read 3 initials for ONE player, then loop or advance.
; Called once per call from STATE.ASM. Internally tracks CURRENT_PLAYER.
; (v1.2: loops NUM_PLAYERS times by re-entering itself via state machine)
;---------------------------------------------------------------
SCR_NAME_RUN PROC
    LEA  DX, BG_NAME
    CALL GFX_LOAD_BG

    ; --- "PLAYER N" header ---
    MOV  AL, CURRENT_PLAYER
    OR   AL, AL
    JNZ  SNR_P2
    LEA  SI, STR_PLAYER1
    JMP  SNR_HDR
SNR_P2:
    LEA  SI, STR_PLAYER2
SNR_HDR:
    MOV  BL, 15
    MOV  CX, 130
    MOV  DX, 60
    CALL GFX_DRAW_STRING

    LEA  SI, PROMPT_NAME
    MOV  CX, 80
    MOV  DX, 90
    CALL GFX_DRAW_STRING

    ; --- Compute destination: PLAYER_NAMES + CURRENT_PLAYER*3 ---
    MOV  AL, CURRENT_PLAYER
    MOV  AH, 0
    MOV  CX, 3
    MUL  CX                       ; AX = CURRENT_PLAYER * 3
    LEA  DI, PLAYER_NAMES
    ADD  DI, AX                   ; DS:DI = name slot for this player

    ; --- Read 3 uppercase chars ---
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
    MOV  [DI+BX], AL
    INC  BX
    LOOP SNR_LOOP

    ; --- Advance CURRENT_PLAYER; if more players, stay in STATE_NAME ---
    INC  CURRENT_PLAYER
    MOV  AL, CURRENT_PLAYER
    CMP  AL, NUM_PLAYERS
    JB   SNR_KEEP                 ; another player still needs to enter

    ; All players done — reset CURRENT_PLAYER and advance
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_DIFF
    RET

SNR_KEEP:
    ; Stay in STATE_NAME; STATE.ASM will call us again with new CURRENT_PLAYER
    RET
SCR_NAME_RUN ENDP

;---------------------------------------------------------------
; SCR_DIFF_RUN — Difficulty select.
;---------------------------------------------------------------
SCR_DIFF_RUN PROC
    LEA  DX, BG_DIFF                   ; ← v1.2 (was GFX_CLEAR)
    CALL GFX_LOAD_BG
    ; ... rest unchanged from v1.1 ...
    MOV  CURRENT_STATE, STATE_INSTR
    RET
SCR_DIFF_RUN ENDP

;---------------------------------------------------------------
; SCR_INSTR_RUN — Show instructions.
;---------------------------------------------------------------
SCR_INSTR_RUN PROC
    LEA  DX, BG_INSTR                  ; ← v1.2 (was GFX_CLEAR)
    CALL GFX_LOAD_BG
    ; ... rest unchanged from v1.1 ...
    MOV  CURRENT_STATE, STATE_ROUND
    RET
SCR_INSTR_RUN ENDP

END
```

### Design Notes

- **`SCR_NAME_RUN` is re-entrant via state machine.** It runs once per player. After the first player's name is entered, `CURRENT_PLAYER` is incremented but `CURRENT_STATE` stays at `STATE_NAME`, so `GAME_TICK` calls `SCR_NAME_RUN` again on the next iteration. Cleaner than a loop inside the proc, and the screen redraw between players gives a natural visual transition.
- **Mode select only accepts '1' or '2'.** Loops on other keys. No default.
- **`NUM_PLAYERS` and `DIFFICULTY` are set once per session.** Don't allow re-entry without a full restart.
- **`CURRENT_PLAYER` is reset to 0 at the end of name entry** so it's ready for the round loop.

### Integration Contract

- **Inputs:** Reads `STR_TITLE`, `STR_MODE_PROMPT`, etc., and all `BG_*` filename strings.
- **Outputs:** Writes `PLAYER_NAMES`, `NUM_PLAYERS`, `CURRENT_PLAYER`, `DIFFICULTY`, updates `CURRENT_STATE`.

---

## 5.2 `SCR_GAME.ASM` — Main Gameplay Screen (1P + 2P)

### Purpose

The heart of the game. Pick a word, show the sprite + sound, **collect answers from all `NUM_PLAYERS` players in sequence**, judge them together, update score/hearts, transition.

### Screens Owned

1. **`SCR_ROUND_RUN`** — show sprite + play sound + loop through all players' answers
2. **`SCR_JUDGE_RUN`** — judge each player's stored answer, update score/hearts, transition

### Dependencies

- `GFX.ASM`, `AUDIO.ASM`, `INPUT.ASM`, `DATA.ASM`
- External globals: `CURRENT_STATE`, `NUM_PLAYERS`, `CURRENT_PLAYER`, `CURRENT_WORD`, `DIFFICULTY`, `SCORES`, `HEARTS_ARR`, `PLAYER_RESULTS`, `PLAYER_TIMES`, `INPUT_BUFFER`

### Structure (v1.2)

```asm
; SCR_GAME.ASM — Gameplay screens
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE
    EXTRN NUM_PLAYERS:BYTE, CURRENT_PLAYER:BYTE          ; ← NEW (v1.2)
    EXTRN CURRENT_WORD:BYTE, DIFFICULTY:BYTE
    EXTRN SCORES:WORD, HEARTS_ARR:BYTE                   ; ← arrays now
    EXTRN PLAYER_RESULTS:BYTE, PLAYER_TIMES:WORD         ; ← NEW (v1.2)
    EXTRN TIMER_START:WORD, INPUT_BUFFER:BYTE
    EXTRN TIER_TABLE:WORD, SPRITE_TABLE:BYTE, SOUND_TABLE:WORD
    EXTRN WORD_RECORD_SIZE:ABS, WORDS_PER_TIER:ABS, SPRITE_SIZE:ABS
    EXTRN STR_PLAYER1:BYTE, STR_PLAYER2:BYTE, STR_YOUR_TURN:BYTE
    EXTRN BG_ROUND:BYTE

    STR_RIGHT   DB  'YES! GREAT JOB!',0
    STR_WRONG   DB  'OOPS! TRY NEXT ONE.',0

.CODE
    EXTRN GFX_LOAD_BG:PROC, GFX_DRAW_SPRITE:PROC, GFX_DRAW_STRING:PROC
    EXTRN INP_WAIT_KEY:PROC, INP_READ_STRING:PROC
    EXTRN SND_PLAY_PATTERN:PROC

    PUBLIC SCR_ROUND_RUN, SCR_JUDGE_RUN

;---------------------------------------------------------------
; SCR_ROUND_RUN — Play one round; loop through all NUM_PLAYERS.
;---------------------------------------------------------------
SCR_ROUND_RUN PROC
    LEA  DX, BG_ROUND               ; ← v1.2
    CALL GFX_LOAD_BG

    ; --- Resolve sprite for current word (sprite + sound logic
    ;     unchanged from v1.1; see that section for tier-base math) ---
    ; [Resolve SI = word string addr]
    ; [Resolve sprite addr, draw at (144, 50)]
    ; [Resolve sound pointer, call SND_PLAY_PATTERN]

    ; --- LOOP: for each player, collect their answer ---
    MOV  CURRENT_PLAYER, 0
SRR_PLAYER_LOOP:
    ; "PLAYER N — YOUR TURN!" banner
    MOV  AL, CURRENT_PLAYER
    OR   AL, AL
    JNZ  SRR_P2_BANNER
    LEA  SI, STR_PLAYER1
    JMP  SRR_BANNER_DONE
SRR_P2_BANNER:
    LEA  SI, STR_PLAYER2
SRR_BANNER_DONE:
    MOV  BL, 15
    MOV  CX, 130
    MOV  DX, 140
    CALL GFX_DRAW_STRING

    LEA  SI, STR_YOUR_TURN
    MOV  CX, 130
    MOV  DX, 155
    CALL GFX_DRAW_STRING

    ; --- Record timer start for this player ---
    MOV  AH, 0
    INT  1Ah
    ; PLAYER_TIMES[CURRENT_PLAYER] = DX
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    SHL  BX, 1
    MOV  PLAYER_TIMES[BX], DX

    ; --- Clear INPUT_BUFFER and read string ---
    PUSH DS
    POP  ES
    LEA  DI, INPUT_BUFFER
    MOV  CX, 16
    CALL INP_READ_STRING

    ; --- Compare INPUT_BUFFER to current word (string addr in SI from earlier;
    ;     must have been preserved — push/pop around inner work) ---
    ; CALL STR_COMPARE  (sets ZF on match)
    JE   SRR_RIGHT
    ; Wrong: PLAYER_RESULTS[CURRENT_PLAYER] = 0
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    MOV  PLAYER_RESULTS[BX], 0
    JMP  SRR_NEXT
SRR_RIGHT:
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    MOV  PLAYER_RESULTS[BX], 1
    ; --- Compute elapsed ticks now and store back to PLAYER_TIMES ---
    MOV  AH, 0
    INT  1Ah
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    SHL  BX, 1
    MOV  AX, DX
    SUB  AX, PLAYER_TIMES[BX]      ; AX = elapsed ticks
    MOV  PLAYER_TIMES[BX], AX

SRR_NEXT:
    INC  CURRENT_PLAYER
    MOV  AL, CURRENT_PLAYER
    CMP  AL, NUM_PLAYERS
    JB   SRR_PLAYER_LOOP

    ; All players answered — transition to JUDGE
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_JUDGE
    RET
SCR_ROUND_RUN ENDP

;---------------------------------------------------------------
; SCR_JUDGE_RUN — Process both players' results, update scores/hearts.
;---------------------------------------------------------------
SCR_JUDGE_RUN PROC
    LEA  DX, BG_ROUND               ; reuse round bg or have JUDGE.BIN
    CALL GFX_LOAD_BG

    ; --- Iterate over each player and apply their result ---
    MOV  CURRENT_PLAYER, 0
SJR_LOOP:
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    CMP  PLAYER_RESULTS[BX], 1
    JNE  SJR_WRONG

    ; --- Correct: compute score delta ---
    SHL  BX, 1                     ; word-index for PLAYER_TIMES, SCORES
    MOV  AX, PLAYER_TIMES[BX]      ; AX = elapsed ticks for this player
    ; Score: base 100 - (ticks * 2), min 10
    MOV  CX, 100
    SHL  AX, 1
    SUB  CX, AX
    CMP  CX, 10
    JGE  SJR_ADD
    MOV  CX, 10
SJR_ADD:
    ADD  SCORES[BX], CX
    JMP  SJR_DRAW_RESULT

SJR_WRONG:
    ; HEARTS_ARR[CURRENT_PLAYER] -= 1
    DEC  HEARTS_ARR[BX]

SJR_DRAW_RESULT:
    ; TODO: draw "PLAYER N: YES/OOPS" feedback per player
    INC  CURRENT_PLAYER
    MOV  AL, CURRENT_PLAYER
    CMP  AL, NUM_PLAYERS
    JB   SJR_LOOP

    ; --- Wait for keypress before advancing ---
    CALL INP_WAIT_KEY

    ; --- Advance word ---
    INC  CURRENT_WORD

    ; --- End conditions ---
    ; (a) any player at 0 hearts?
    CMP  HEARTS_ARR, 0
    JE   SJR_END
    MOV  AL, NUM_PLAYERS
    CMP  AL, 2
    JB   SJR_CHECK_WORDS           ; 1P — only check slot [0]
    CMP  HEARTS_ARR+1, 0
    JE   SJR_END
SJR_CHECK_WORDS:
    ; (b) all words in tier consumed?
    MOV  AL, CURRENT_WORD
    CMP  AL, WORDS_PER_TIER
    JAE  SJR_END

    ; Continue
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_ROUND
    RET

SJR_END:
    MOV  CURRENT_STATE, STATE_END
    RET
SCR_JUDGE_RUN ENDP

END
```

### Design Notes

- **One word per round, regardless of player count.** `CURRENT_WORD` increments once per `SJR_LOOP` completion. Maximum 10 rounds.
- **Each player has independent timing.** `PLAYER_TIMES[i]` stores the start tick during input collection, then gets overwritten with elapsed ticks at submission time. `SJR_LOOP` reads the elapsed value for scoring.
- **End condition (game over) triggers if EITHER player has 0 hearts.** Documented limitation: the surviving player loses remaining attempts. Simpler than tracking per-player end state.
- **Sprite/sound resolution unchanged from v1.1** — same `TIER_TABLE` + global index math. Drawn ONCE per round, visible while both players answer.
- **The same word is shown to both players.** This is intentional per v1.2 design decision; P2's "advantage" of seeing P1 type is accepted.

### Integration Contract

- **Inputs:** Reads `CURRENT_WORD`, `DIFFICULTY`, `NUM_PLAYERS`, word/sprite/sound tables.
- **Outputs:** Updates `SCORES[]`, `HEARTS_ARR[]`, `PLAYER_RESULTS[]`, `PLAYER_TIMES[]`, `CURRENT_WORD`, `CURRENT_PLAYER`, `CURRENT_STATE`, `INPUT_BUFFER`.

---

## 5.3 `SCR_END.ASM` — Score + Leaderboard + Game Over

### Purpose

Show final score(s), determine 2P winner if applicable, insert both players into leaderboard, display leaderboard, wait for key.

### Screens Owned

1. **`SCR_END_RUN`** — final scores + winner banner (2P) + leaderboard + quit prompt

### Dependencies

- `GFX.ASM`, `INPUT.ASM`, `FILEIO.ASM`
- External globals: `CURRENT_STATE`, `NUM_PLAYERS`, `PLAYER_NAMES`, `SCORES`, `HEARTS_ARR`, `DIFFICULTY`, `LEADERBOARD`

### Structure (v1.2)

```asm
; SCR_END.ASM — End screen
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE
    EXTRN NUM_PLAYERS:BYTE, DIFFICULTY:BYTE
    EXTRN PLAYER_NAMES:BYTE, SCORES:WORD, HEARTS_ARR:BYTE
    EXTRN LEADERBOARD:BYTE
    EXTRN STR_GAMEOVER:BYTE, STR_WIN:BYTE
    EXTRN STR_EASY:BYTE, STR_MED:BYTE, STR_HARD:BYTE
    EXTRN STR_PLAYER1:BYTE, STR_PLAYER2:BYTE
    EXTRN STR_VS:BYTE, STR_WINNER:BYTE, STR_TIE:BYTE
    EXTRN BG_END:BYTE

    STR_FINAL    DB  'FINAL SCORE: ',0
    STR_LEADER   DB  'TOP 5 PLAYERS',0
    STR_SEP      DB  ' | ',0

.CODE
    EXTRN GFX_LOAD_BG:PROC, GFX_DRAW_STRING:PROC
    EXTRN INP_WAIT_KEY:PROC
    EXTRN FILE_INSERT_SCORE:PROC, FILE_SAVE_SCORES:PROC

    PUBLIC SCR_END_RUN

SCR_END_RUN PROC
    LEA  DX, BG_END                  ; ← v1.2 (was GFX_CLEAR)
    CALL GFX_LOAD_BG

    ; --- Title banner: GAME OVER (any player at 0) vs YOU DID IT! ---
    MOV  AL, HEARTS_ARR
    OR   AL, AL
    JZ   SER_LOSE
    CMP  NUM_PLAYERS, 2
    JB   SER_WIN_TITLE
    MOV  AL, HEARTS_ARR+1
    OR   AL, AL
    JZ   SER_LOSE
SER_WIN_TITLE:
    LEA  SI, STR_WIN
    JMP  SER_DRAW_TITLE
SER_LOSE:
    LEA  SI, STR_GAMEOVER
SER_DRAW_TITLE:
    MOV  BL, 15
    MOV  CX, 110
    MOV  DX, 20
    CALL GFX_DRAW_STRING

    ; --- 1P: just show player's score ---
    ; --- 2P: show both scores + winner banner ---
    CMP  NUM_PLAYERS, 2
    JE   SER_2P

SER_1P:
    ; "PLAYER 1: AAA  240pts"
    ; TODO: render PLAYER_NAMES (3 chars at offset 0), SCORES[0]
    JMP  SER_INSERT

SER_2P:
    ; "PLAYER 1: AAA 240pts  VS  PLAYER 2: BBB 180pts"
    ; TODO: render both names + scores, side by side or stacked
    ;
    ; --- Winner: compare SCORES[0] vs SCORES[1] ---
    MOV  AX, SCORES
    CMP  AX, SCORES+2
    JE   SER_TIE
    JA   SER_P1_WIN
    ; P2 wins
    LEA  SI, STR_WINNER
    ; ... draw "WINNER: " + PLAYER_NAMES+3 ...
    JMP  SER_INSERT
SER_P1_WIN:
    LEA  SI, STR_WINNER
    ; ... draw "WINNER: " + PLAYER_NAMES ...
    JMP  SER_INSERT
SER_TIE:
    LEA  SI, STR_TIE
    ; ... draw ...

SER_INSERT:
    ; --- Insert each player's score into leaderboard ---
    ; Player 1
    LEA  SI, PLAYER_NAMES
    MOV  BX, SCORES
    MOV  AL, DIFFICULTY
    CALL FILE_INSERT_SCORE

    ; Player 2 (only in 2P)
    CMP  NUM_PLAYERS, 2
    JNE  SER_SAVE
    LEA  SI, PLAYER_NAMES+3
    MOV  BX, SCORES+2
    MOV  AL, DIFFICULTY
    CALL FILE_INSERT_SCORE

SER_SAVE:
    CALL FILE_SAVE_SCORES

    ; --- Render leaderboard (loop 5 entries, draw NAME | SCORE | DIFF) ---
    LEA  SI, STR_LEADER
    MOV  CX, 110
    MOV  DX, 80
    CALL GFX_DRAW_STRING
    ; TODO: leaderboard rendering loop (Dev 1 implements)

    CALL INP_WAIT_KEY

    MOV  CURRENT_STATE, STATE_QUIT
    RET
SCR_END_RUN ENDP

END
```

### Design Notes

- **Win condition is "all players still have hearts."** If any player hit 0, it's a GAME OVER — including in 2P even if the other player would have finished cleanly. Documented in 5.2.

- **2P winner determination:** higher score wins. Tie shows `STR_TIE`. No tiebreak by hearts; just points.

- **Leaderboard insertion order:** P1 first, then P2. Matters only on score ties — earlier insertion takes the slot.

- **Number-to-ASCII conversion** for displaying scores is still Dev 1's task; standard `DIV 10` loop.

- **Layout for 2P score display:** stacked is probably easier than side-by-side at 320×200. Suggested:
  
  ```
  PLAYER 1: AAA — 240 PTS
  PLAYER 2: BBB — 180 PTS
  WINNER: AAA
  ```

### Integration Contract

- **Inputs:** Reads `NUM_PLAYERS`, `SCORES[]`, `HEARTS_ARR[]`, `PLAYER_NAMES[]`, `DIFFICULTY`, `LEADERBOARD`.
- **Outputs:** Modifies leaderboard (1 or 2 inserts), writes file, sets `CURRENT_STATE = STATE_QUIT`.

---

# Chapter 6 — Integration & Testing

## 6.1 Module Integration Contracts

| Module                   | Promises (outputs)                       | Requires (inputs)                           | Sets                                              |
| ------------------------ | ---------------------------------------- | ------------------------------------------- | ------------------------------------------------- |
| `GAME_TICK` (STATE)      | Runs one state's screen                  | `CURRENT_STATE` valid                       | —                                                 |
| `GFX_INIT`               | Mode 13h active, `ES=A000h`              | —                                           | Video mode                                        |
| `GFX_LOAD_BG` *(v1.2)*   | Framebuffer filled from disk             | `DS:DX`=filename                            | Video memory, `ES=A000h`                          |
| `GFX_DRAW_SPRITE`        | 32×32 sprite drawn (transparent color 0) | `DS:SI`=sprite, `BX,DX`=pos                 | Video memory                                      |
| `SND_PLAY_PATTERN`       | Pattern played to completion             | `DS:SI`=pattern                             | Speaker, time                                     |
| `INP_READ_STRING`        | Null-term'd uppercase string             | `ES:DI`=buf, `CX`=max                       | Buffer, `CX`=len                                  |
| `FILE_LOAD_SCORES`       | Leaderboard populated                    | `SCORES.DAT` (optional)                     | `LEADERBOARD`                                     |
| `FILE_SAVE_SCORES`       | Leaderboard persisted                    | `LEADERBOARD` valid                         | `SCORES.DAT`                                      |
| `FILE_INSERT_SCORE`      | Entry inserted if qualifies              | `DS:SI`=name, `BX`=score, `AL`=difficulty   | `LEADERBOARD` sorted                              |
| `SCR_MODE_RUN` *(v1.2)*  | Mode selected                            | `STR_MODE_*` strings                        | `NUM_PLAYERS`, state                              |
| `SCR_NAME_RUN` *(v1.2)*  | One player's name read                   | `CURRENT_PLAYER` valid                      | `PLAYER_NAMES[CP]`, state                         |
| `SCR_DIFF_RUN`           | Difficulty selected                      | `STR_DIFF_*` strings                        | `DIFFICULTY`, state                               |
| `SCR_ROUND_RUN` *(v1.2)* | Round played for all `NUM_PLAYERS`       | `CURRENT_WORD`, `DIFFICULTY`, `NUM_PLAYERS` | `PLAYER_RESULTS[]`, `PLAYER_TIMES[]`, state       |
| `SCR_JUDGE_RUN` *(v1.2)* | All players' scores/hearts updated       | `PLAYER_RESULTS[]`, `PLAYER_TIMES[]`        | `SCORES[]`, `HEARTS_ARR[]`, `CURRENT_WORD`, state |
| `SCR_END_RUN` *(v1.2)*   | Both players inserted; result shown      | `SCORES[]`, `HEARTS_ARR[]`, `NUM_PLAYERS`   | Leaderboard file, state                           |

## 6.2 Testing Strategy

### Per-Module Smoke Tests

Same approach as v1.1. Keep test mains in `tests/`. For v1.2 specifically:

- **`tests/test_GFX_BG.asm`** — `GFX_INIT`, `GFX_LOAD_BG('TITLE.BIN')`, wait key, `GFX_SHUTDOWN`. Verifies disk-loaded backgrounds work.
- **`tests/test_2P_flow.asm`** — minimal main that sets `NUM_PLAYERS=2` and calls `SCR_ROUND_RUN` once. Verifies the inner player loop completes without state errors.

### Integration Checkpoints (revised v1.2 timeline)

| Day | Checkpoint                                                         | Demo                                                  |
| --- | ------------------------------------------------------------------ | ----------------------------------------------------- |
| 1   | Hello world builds & runs                                          | `.EXE` prints "HELLO" and exits                       |
| 2   | Graphics module works standalone                                   | Test main draws 1 sprite per tier, exits              |
| 3   | **Background loading works** *(v1.2)*                              | `GFX_LOAD_BG` renders TITLE.BIN visibly               |
| 4   | Audio + Input + File I/O standalone                                | Audio plays one pattern; name read; leaderboard saved |
| 5   | **Intro flow integrated (Title → Mode → Name(×N) → Diff → Instr)** | Walk through intro in both 1P and 2P                  |
| 6   | **Round + Judge integrated (1P first, then 2P)**                   | Play a complete 1P game; then 2P                      |
| 7   | End screen + leaderboard                                           | Full game end-to-end with both players persisted      |
| 8   | Bug bash                                                           | Cross-mode regressions, font-on-bg transparency       |
| 9   | Polish + demo prep                                                 | —                                                     |
| 10  | Buffer day                                                         | —                                                     |

### Common Bugs to Watch For (v1.2 additions)

- **Forgetting font transparency.** Text labels rendering as black boxes over the background. Symptom: backgrounds look fine until any text is drawn, then large black rectangles appear. Fix in `GFX_DRAW_CHAR`'s inner loop.
- **Background `.BIN` files missing from runtime dir.** Symptom: screens show garbage (whatever was in framebuffer before). Add a sanity check or just verify all `.BIN` files copied to `bin/`.
- **Player index math off-by-one.** `CURRENT_PLAYER` is 0 or 1, not 1 or 2. `PLAYER_NAMES[CP*3]` for byte array, `SCORES[CP*2]` for word array. Word arrays need `SHL BX, 1`.
- **`SCR_NAME_RUN` re-entry confusion.** If `CURRENT_PLAYER` isn't reset to 0 at end of name entry, the round loop starts mid-loop. Always reset before transitioning out.
- **2P end condition logic.** Game ending too early/late. Verify with: P1 loses all hearts at round 3 — does the game end immediately? (Per spec: yes.) Test this case explicitly.
- **Score word array indexing.** `SCORES[BX]` with `BX = CURRENT_PLAYER*2`. Easy to forget the `SHL`.

## 6.3 Known Risks & Mitigations

| Risk                                                                             | Likelihood    | Impact        | Mitigation                                                                                                  |
| -------------------------------------------------------------------------------- | ------------- | ------------- | ----------------------------------------------------------------------------------------------------------- |
| Font rendering forgets transparency, overlays go opaque on bg                    | **High**      | **High**      | **Code review the inner glyph loop. Test on a non-black background BEFORE integrating with other screens.** |
| Spriter can't deliver 30 sprites + 7 backgrounds                                 | **High**      | **High**      | Talk today. Fallback: 4 backgrounds (TITLE, ROUND, END, INSTR — reuse for others), 6-8 sprites per tier.    |
| Background `.BIN` missing at runtime                                             | Medium        | Medium        | Add a "missing file" log in `GFX_LOAD_BG` error path. Or just visual-test all screens Day 5.                |
| Player array index bugs                                                          | Medium        | High          | Standardize the indexing macro early (`PLAYER_BYTE`, `PLAYER_WORD`); code review every use.                 |
| 2P "game ends when either player out of hearts" feels unfair to surviving player | Medium        | Low           | Document as known limitation. If prof objects, change to per-player end-tracking (~half a day).             |
| Audio doesn't play in DOSBox                                                     | Low           | High          | Check `pcspeaker=true` in `dosbox.conf`. Test Day 2.                                                        |
| Teammate flakes                                                                  | Medium        | Medium        | v1.2 increased Dev 1 load. If Dev 3 drops, prioritize: 1P-only fallback ships first, 2P is "polish."        |
| Scope creep                                                                      | **Very High** | **Very High** | v1.2 already absorbed the prof's two requests. Hard freeze on additions. `POLISH_IDEAS.txt` only.           |
| Data segment overflow                                                            | Low           | Critical      | ~33KB total — still safe. Backgrounds NOT in data segment. Don't change this.                               |
| Integration day reveals misaligned contracts                                     | High          | Medium        | Standups Days 2, 4, 6. Each dev demos.                                                                      |
| Background images look bad / non-cohesive                                        | Medium        | Low           | Spriter and Dev 1 align on visual style Day 1 (palette choices, theme).                                     |

---

# Appendices

## A. TASM Cheatsheet

Unchanged from v1.1. See v1.1 spec.

## B. Interrupt Quick Reference

Unchanged from v1.1, but note that `INT 21h AH=3Dh/3Fh/3Eh` is now used by `GFX_LOAD_BG` in addition to `FILEIO`.

## C. Glossary

Unchanged from v1.1.

---

# 🛑 Document Status

**Version:** 1.2 — Disk-loaded backgrounds + 2-player mode
**Date of change:** 2026-05-11
**Author of revision:** Dev 1 (lead), in consultation with professor

**Changes from v1.1 → v1.2:**

1. **Backgrounds:** Added `GFX_LOAD_BG` procedure in `GFX.ASM` to stream 64,000-byte `.BIN` images from disk to `A000h`. Replaces `GFX_CLEAR` as the first paint operation in every screen handler. Seven background files: TITLE, MODE, NAME, DIFF, INSTR, ROUND, END.
2. **Font transparency requirement:** `GFX_DRAW_CHAR` must treat "off" pixels in the font bitmap as transparent (don't draw), matching the existing sprite contract. Critical for legibility over backgrounds.
3. **2-player mode added:** New `STATE_MODE` between TITLE and NAME. `SCR_MODE_RUN` lets player pick 1P or 2P, sets `NUM_PLAYERS` global.
4. **State machine renumbered:** Inserted `STATE_MODE=1`; all higher states shifted up by 1 (`STATE_NAME=2`, ..., `STATE_QUIT=8`). Code uses named constants — no functional change beyond `SHARED.INC`.
5. **Player-indexed runtime state:** `PLAYER_NAME` → `PLAYER_NAMES[2]`, `SCORE` → `SCORES[2]`, `HEARTS` → `HEARTS_ARR[2]`. New arrays: `PLAYER_RESULTS[2]`, `PLAYER_TIMES[2]`. New scalars: `NUM_PLAYERS`, `CURRENT_PLAYER`.
6. **2P round structure:** Same word shown to both players. P1 answers, then P2 answers, then `SCR_JUDGE_RUN` processes both results, updates both score/hearts arrays, advances `CURRENT_WORD` once per round.
7. **2P name entry:** `SCR_NAME_RUN` is re-entrant per state machine. After reading P1's name, increments `CURRENT_PLAYER` but stays in `STATE_NAME`. Once `CURRENT_PLAYER == NUM_PLAYERS`, transitions to `STATE_DIFF`.
8. **Leaderboard 2P policy:** Both players' scores inserted independently as separate top-5 entries. Existing 8-byte record format unchanged.
9. **End condition:** Game ends when ANY player hits 0 hearts OR all 10 words consumed. Surviving player loses remaining attempts (accepted limitation).
10. **2P end screen:** Shows both names/scores, declares winner by higher score, with `STR_TIE` for ties.
11. **Memory map updated:** ~20B of new data-segment variables. Backgrounds are NOT in EXE — they're external `.BIN` files (~448KB total on disk, streamed to A000h on demand).
12. **Timeline:** Original 1-week sprint replaced with 10-day estimate. Spriter workload increases ~50% (added 7 backgrounds). 3-week buffer absorbs.
13. **2P fairness:** Documented accepted asymmetry — P2 watches P1 type. Not engineering around it for MVP.

**Ready for:** Implementation Day 1
**Pending:** Study Guide update — see `STUDY_GUIDE.md`

**Update this doc when:**

- A module's procedure signature changes
- A new screen or state is added
- Memory layout changes
- Team assignments shift
