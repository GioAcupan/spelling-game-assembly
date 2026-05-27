# 🎮 Spelling Game — MVP Implementation Document

> **Project:** Educational Spelling Game for Toddlers
> **Platform:** Intel 8086 (16-bit Real Mode) via DOSBox
> **Toolchain:** TASM 5.0 + TLINK
> **Team:** 3 devs + 1 spriter
> **Timeline:** Originally 1-week sprint → now ~13 days with v1.4 scope (3-week deadline buffer absorbs)
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
  - 4.3 `AUDIO.ASM` — PC Speaker Sound Cues & Jingles
  - 4.4 `FILEIO.ASM` — Leaderboard & User Account Persistence
- **Chapter 5 — Screen Modules** *(technical)*
  - 5.1 `SCR_INTRO.ASM` — Title + Login + Mode + Name Entry + Difficulty + Instructions
  - 5.2 `SCR_GAME.ASM` — Main Gameplay Screen (1P + 2P)
  - 5.3 `SCR_END.ASM` — Score + Leaderboard + Game Over (with end jingle)
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

| Decision                               | Choice                                                                            | Rationale                                                                                |
| -------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Code organization**                  | Multiple `.ASM` files linked into one `.EXE`                                      | Enables parallel dev work; isolates bugs; mandatory for 3-dev team                       |
| **Memory model**                       | `.MODEL SMALL`                                                                    | One 64KB code segment, one 64KB data segment — more than enough                          |
| **Graphics mode**                      | VGA Mode 13h (320×200, 256 colors)                                                | Industry-standard 8086 graphics mode; simple linear framebuffer at `A000h`               |
| **Screen backgrounds**                 | Disk-loaded full-screen `.BIN` images, blitted to `A000h`                         | 64,000 bytes each — too big for `.MODEL SMALL` data segment. Disk load is the only path. |
| **Audio approach**                     | **PC Speaker beeps/tones + blocking jingles** *(v1.3)*                            | Senior project bar. Jingles via existing `SND_PLAY_PATTERN`. No ISR, no Sound Blaster.   |
| **Background music** *(v1.3)*          | **Rejected.** Title + win/lose jingles only.                                      | PC speaker is monophonic; continuous music would require an ISR and conflict with cues.  |
| **Login screen** *(v1.3)*              | **`STATE_LOGIN` between TITLE and MODE. Auth against `USERS.DAT`.**               | Prof mandate. Auto-register unknown users; 3-retry limit on wrong password.              |
| **User account format** *(v1.3)*       | 8-byte records: name(3) + password(5). Max 5 users. Stored in `USERS.DAT`.        | Matches `SCORES.DAT` record style; same file I/O patterns.                               |
| **Password input** *(v1.3)*            | 5-char fixed-width, echoed as `*` via new `INP_READ_PASSWORD`                     | Toddler-tractable; still feels like real auth.                                           |
| **Difficulty modes**                   | 3 tiers: Easy / Medium / Hard (word-length based)                                 | Required by prof                                                                         |
| **Object count**                       | 10 words per tier = 30 total                                                      | Prof requirement                                                                         |
| **Word list architecture**             | Option A: 3 separate arrays (`EASY_WORDS`, `MED_WORDS`, `HARD_WORDS`)             | Simpler pointer math than flat-list-with-tags                                            |
| **Player modes**                       | 1P (solo) and 2P (hot-seat versus)                                                | Prof addition; same keyboard, alternating answers, joint judgment                        |
| **2P round structure**                 | Same word for both players, P1 answers then P2 answers, judge both, advance       | Cleanest pacing; state machine stays simple                                              |
| **2P fairness**                        | Accepted asymmetry — P2 sees P1's typing.                                         | Toddler game; sound cue is the real challenge. Documented limitation.                    |
| **Scrambled letter hint** *(v1.4)*     | Each round shows a hardcoded jumbled-letter hint alongside the sprite + sound cue | Prof addition; scaffolds spelling for toddlers. Hardcoded avoids RNG complexity.         |
| **Name input length**                  | 3 characters (arcade-style)                                                       | Matches spec                                                                             |
| **Logged-in user → Player 1** *(v1.3)* | Login username pre-fills `PLAYER_NAMES[0]`; Player 1 name entry is skipped        | Cohesive UX — "we know who you are"                                                      |
| **Starting hearts**                    | 3 per player                                                                      | Standard game feel                                                                       |
| **Leaderboard size**                   | Top 5 entries, stored in `SCORES.DAT`                                             | Prof wants difficulty on leaderboard                                                     |
| **Leaderboard 2P policy**              | One entry per player (a 2P match writes two independent records)                  | Simpler than match records; reuses 8B format unchanged                                   |
| **Leaderboard record**                 | Name (3B) + Score (2B) + Difficulty (1B) + padding (2B) = 8B per entry            | Stores difficulty for display                                                            |
| **Character encoding**                 | ASCII uppercase only                                                              | Simpler comparison logic; toddler-friendly                                               |

---

# Chapter 1 — High-Level System Architecture

## 1.1 What the Game Does

The game is a **state-machine driven application** that cycles through distinct screens. At its core, it's a loop that:

1. Shows the player a **picture** of an object (e.g., apple) composited over a designed background.
2. Plays a **sound cue** (an audio pattern recognizable as that object).
3. Displays a **jumbled-letter hint** (e.g., `PLEPA` for `APPLE`) *(v1.4)* — scaffolds the spelling without giving away letter order.
4. Waits for the player(s) to **type the spelling**. In 2P mode, P1 answers first, then P2.
5. **Compares** input to the correct answer.
6. Updates **score** (based on speed) or **hearts** (on wrong answer), per player.
7. Repeats with the next object, or ends the game.

Around this core loop, there's an **intro flow** (title → **login (v1.3)** → mode select → name entry → difficulty → instructions) and an **end flow** (final score → leaderboard → game over). Between rounds, the game saves high scores to disk so they persist across sessions. User accounts persist across sessions via `USERS.DAT` (v1.3).

Think of it as **8 screens connected by a state machine**, with 4 reusable I/O services (graphics, audio, keyboard, file) that each screen calls into. Every screen renders a disk-loaded full-screen background as its first paint operation, then composites sprites and text on top.

## 1.2 The Five Subsystems

The codebase is organized into five conceptual layers. Everything we build maps into one of these:

```
┌─────────────────────────────────────────────────────────────┐
│                    GAME LOGIC LAYER                         │
│  (Screens, State Machine, Word List, Score, Hearts,         │
│   Player Indexing for 1P/2P, Session User v1.3)             │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   GRAPHICS    │  │    AUDIO      │  │    INPUT      │
│ (Mode 13h     │  │ (PC Speaker   │  │ (Keyboard via │
│  bg load +    │  │  tones +      │  │  INT 16h,     │
│  sprite draw) │  │  jingles v1.3)│  │  pw mask v1.3)│
└───────────────┘  └───────────────┘  └───────────────┘
                            │
                            ▼
                   ┌───────────────┐
                   │  FILE I/O     │
                   │ (Leaderboard +│
                   │  USERS v1.3   │
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

- **Game Logic Layer** — Knows the *rules* (what's a correct answer, when to lose a heart, whose turn it is, who's logged in). Owns game state. Decides what screen comes next.
- **Graphics Subsystem** — Knows how to put pixels on screen. Loads full-screen backgrounds from disk into the framebuffer. Has no idea what an "apple" is.
- **Audio Subsystem** — Knows how to make the speaker beep at a frequency for a duration. Plays sound cues (per-word) and jingles (title/win/lose). No simultaneous tones.
- **Input Subsystem** — Knows how to read the keyboard. Returns characters; doesn't judge them. New v1.3 variant masks echoed chars for password fields.
- **File I/O Subsystem** — Knows how to read/write `SCORES.DAT` and `USERS.DAT`. Doesn't care about score or auth semantics.

> 📌 **v1.3 note:** Audio gains two responsibilities (title jingle, end jingle) but no new procedures — both use existing `SND_PLAY_PATTERN` with new pattern data in `DATA.ASM`. PC speaker remains strictly monophonic; jingles are blocking.

## 1.3 Game State Machine

The entire program is one big state machine. At any moment, the game is in exactly **one state**, and transitions to another state based on events.

```
       ┌──────────────┐
       │ STATE_TITLE  │  ◄───────── program entry; plays title jingle (v1.3)
       └──────┬───────┘
              │  [any key after jingle]
              ▼
       ┌──────────────┐
       │ STATE_LOGIN  │  ◄── NEW (v1.3); auth against USERS.DAT
       └──────┬───────┘
              │  [valid login OR new user registered]
              │  [3 failed retries → STATE_TITLE]
              ▼
       ┌──────────────┐
       │ STATE_MODE   │  (1P or 2P)
       └──────┬───────┘
              │  [1 / 2 key]
              │  [pre-fills PLAYER_NAMES[0] from SESSION_USER (v1.3)]
              ▼
       ┌──────────────┐
       │  STATE_NAME  │  (loops NUM_PLAYERS times; in 2P, skips Player 1 — v1.3)
       └──────┬───────┘
              │  [ENTER after 3 chars × (NUM_PLAYERS - 1 if logged in)]
              │  [1P case: skipped entirely]
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
              │  STATE_END   │  (both scores side-by-side, leaderboard, win/lose jingle v1.3)
              └──────┬───────┘
                     │  [any key after jingle]
                     ▼
              ┌──────────────┐
              │  STATE_QUIT  │ ──► return to DOS
              └──────────────┘
```

**State constants (v1.3 — renumbered to insert LOGIN):**

```
STATE_TITLE  = 0
STATE_LOGIN  = 1     ← NEW (v1.3)
STATE_MODE   = 2     (was 1)
STATE_NAME   = 3     (was 2)
STATE_DIFF   = 4     (was 3)
STATE_INSTR  = 5     (was 4)
STATE_ROUND  = 6     (was 5)
STATE_JUDGE  = 7     (was 6)
STATE_END    = 8     (was 7)
STATE_QUIT   = 9     (was 8)
```

Because all state references in code use the named `EQU` constant, no code changes are needed beyond updating `SHARED.INC`. Just be aware if you're staring at hex dumps.

**Why no separate STATE_LOGIN_OK / STATE_LOGIN_FAIL?** `SCR_LOGIN_RUN` handles the retry loop internally and renders welcome/error messages inline. State machine stays flat — one entry, one exit per call. On 3 retries, it sets `CURRENT_STATE = STATE_TITLE` and returns.

## 1.4 Data Flow

```
┌─────────────────────────────────────────┐
│  DATA SEGMENT (static, known at compile)│
│  ─────────────────────────────────────  │
│  • EASY_WORDS:  "CAT", "DOG", ...  (10) │
│  • MED_WORDS:   "APPLE", "TRAIN",. (10) │
│  • HARD_WORDS:  "ORANGE", "BRIDGE" (10) │
│  • SCRAMBLE_TABLE: 30 × 16B (v1.4)      │
│  • SPRITE_TABLE: 30 sprites × 1KB each  │
│  • SOUND_PATTERNS: one array per word   │
│  • SND_TITLE_JINGLE  (v1.3)             │
│  • SND_WIN_JINGLE    (v1.3)             │
│  • SND_LOSE_JINGLE   (v1.3)             │
│  • UI strings: "GAME OVER", login, etc. │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  RUNTIME STATE (updated as game plays)  │
│  ─────────────────────────────────────  │
│  • CURRENT_STATE   (byte)               │
│  • SESSION_USER    (3 bytes)            │  ← NEW (v1.3): logged-in username
│  • USER_TABLE      (5 × 8 = 40 bytes)   │  ← NEW (v1.3): loaded USERS.DAT
│  • USER_COUNT      (byte: 0..5)         │  ← NEW (v1.3): active entries
│  • LOGIN_RETRIES   (byte: 0..3)         │  ← NEW (v1.3): wrong-pw counter
│  • USERNAME_BUF    (3 bytes)            │  ← NEW (v1.3): login input scratch
│  • PASSWORD_BUF    (5 bytes)            │  ← NEW (v1.3): login input scratch
│  • NUM_PLAYERS     (byte: 1 or 2)       │
│  • CURRENT_PLAYER  (byte: 0 or 1)       │
│  • DIFFICULTY      (byte: 0=E, 1=M, 2=H)│
│  • CURRENT_WORD    (index 0..9)         │
│  • PLAYER_NAMES    (2 × 3 chars = 6B)   │
│  • SCORES          (2 × word = 4B)      │
│  • HEARTS_ARR      (2 × byte = 2B)      │
│  • PLAYER_RESULTS  (2 × byte = 2B)      │
│  • PLAYER_TIMES    (2 × word = 4B)      │
│  • TIMER_START     (word, BIOS ticks)   │
│  • INPUT_BUFFER    (17 chars)           │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  PERSISTENT STORAGE (disk)              │
│  ─────────────────────────────────────  │
│  • SCORES.DAT  — top 5 leaderboard      │
│    Format: 5 × { name(3) + score(2)     │
│                 + difficulty(1) + pad(2)│
│  • USERS.DAT   — user accounts (v1.3)   │
│    Format: 5 × { name(3) + password(5) }│
│    Created on first run if absent.      │
│  • TITLE.BIN, LOGIN.BIN (v1.3),         │
│    MODE.BIN, NAME.BIN, DIFF.BIN,        │
│    INSTR.BIN, ROUND.BIN, END.BIN —      │
│    64,000 bytes each, raw Mode 13h dump │
└─────────────────────────────────────────┘
```

> 📌 **1P note on player arrays:** In 1P mode, `NUM_PLAYERS=1` and `CURRENT_PLAYER` is always 0. Only `PLAYER_NAMES[0]`, `SCORES[0]`, `HEARTS_ARR[0]` are touched. With v1.3 login, `PLAYER_NAMES[0]` is pre-filled from `SESSION_USER`.

## 1.5 Runtime Environment & Memory Map

When the `.EXE` runs under DOSBox, the machine looks like this:

- **CPU:** Emulated 8086, 16-bit registers, real mode (no memory protection).
- **RAM:** 640 KB conventional memory; we use a tiny fraction.
- **Video memory:** `A000:0000` (Mode 13h framebuffer, 64000 bytes = 320×200 pixels × 1 byte each).
- **BIOS data area:** `0040:006C` holds a timer that ticks 18.2 times per second — our scoring clock.
- **DOS services:** Accessed via `INT 21h` (file I/O, console I/O, exit).
- **BIOS services:** Accessed via `INT 10h` (video), `INT 16h` (keyboard).

**Our program's memory footprint (approximate):**

| Section                         | Size                             | Contents                                                                                 |
| ------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------- |
| Code segment                    | ~8-12 KB                         | All `.ASM` modules compiled together (+~1KB for v1.3 login + jingles)                    |
| Data segment                    | ~34 KB                           | 30 sprites × 1KB + word lists + SCRAMBLE_TABLE (v1.4) + strings + variables + USER_TABLE |
| Stack segment                   | 1 KB                             | Function call stack                                                                      |
| **Total (in-EXE)**              | **~42-46 KB**                    | Within 64 KB `.MODEL SMALL` limit — comfortable                                          |
| **External `.BIN` backgrounds** | **~8 × 64 KB = ~512 KB on disk** | Not in EXE; streamed to `A000h` on demand. v1.3 adds LOGIN.BIN.                          |
| **External `USERS.DAT`**        | **40 bytes**                     | Created at first launch if absent                                                        |
| **External `SCORES.DAT`**       | **40 bytes**                     | Created on first save                                                                    |

> ⚠️ **v1.3 data segment additions:** USER_TABLE (40B) + SESSION_USER (3B) + USER_COUNT (1B) + LOGIN_RETRIES (1B) + USERNAME_BUF (3B) + PASSWORD_BUF (5B) + 3 jingle patterns (~50B each) ≈ +200B. Total still ~33.5KB, well under 64KB.

> ⚠️ **v1.4 data segment additions:** SCRAMBLE_TABLE (30 × 16B = 480B) + STR_HINT (~10B). Total now ~34KB, still well under 64KB.

> ⚠️ **Why backgrounds are NOT in the data segment:** One 320×200 background is 64,000 bytes — almost a full data segment by itself. Disk-loading is the only viable path under `.MODEL SMALL`.

## 1.6 Key Design Decisions (and Why)

- **PC Speaker audio, not Sound Blaster.** Senior project did beeps and passed.
- **Mode 13h graphics, not text mode.** Prof wants real sprites.
- **Disk-loaded backgrounds, not embedded.** 64,000 bytes per image; physically cannot fit multiple in the `.MODEL SMALL` data segment.
- **Transparent sprite + font compositing.** Color 0 = transparent; backgrounds show through. Critical for legibility over backgrounds.
- **30 words across 3 difficulty tiers (10 each).** Prof requirement.
- **Option A word list architecture (3 separate arrays).** `DIFFICULTY` byte indexes `TIER_TABLE`. Zero searching.
- **Difficulty stored in leaderboard.** Each entry includes a difficulty byte.
- **Hot-seat 2P, not simultaneous.** `INT 16h` gives one keyboard buffer.
- **Same word for both players in 2P.** Cleaner pacing; one word advance per round.
- **Two-player loop *inside* `SCR_ROUND_RUN`, not in state machine.** Keeps state machine flat.
- **One leaderboard entry per player per 2P match.** Existing 8B record format unchanged.
- **End condition in 2P:** game ends when *either* player hits 0 hearts OR all 10 words consumed. Documented limitation.
- **Login screen as separate state.** *(v1.3)* `STATE_LOGIN` between TITLE and MODE keeps the state machine readable. `SCR_LOGIN_RUN` owns the retry loop internally.
- **Auto-register on unknown username.** *(v1.3)* Toddler-friendly: never blocks a child on "no such user." Falls back to "USERS FULL" only when `USER_TABLE` has 5 entries.
- **3-retry limit on wrong password.** *(v1.3)* After 3 failures, return to `STATE_TITLE`. Prevents infinite-loop UX. MVP simplification — proper "forgot password" flow out of scope.
- **5-char password masked as `*`.** *(v1.3)* `INP_READ_PASSWORD` is a new variant of `INP_READ_STRING` that draws `*` to screen instead of the typed char. Buffer still holds the real characters for comparison.
- **No `SCR_LOGIN_RESULT` state.** *(v1.3)* Welcome / new-user / error messages rendered inline in `SCR_LOGIN_RUN` with a brief `SND_DELAY`, then transition. Keeps state machine flat.
- **Login username pre-fills `PLAYER_NAMES[0]`.** *(v1.3)* In 1P mode, name entry is skipped entirely. In 2P, only Player 2 enters initials. Done in `SCR_MODE_RUN` after mode is chosen.
- **Title and end jingles via `SND_PLAY_PATTERN`.** *(v1.3)* Jingles are just longer pattern arrays in `DATA.ASM`. Zero new audio code. Jingles block (~1-2 sec) before input is accepted — acceptable for title/end screens.
- **Background music explicitly rejected.** *(v1.3)* PC speaker is monophonic; continuous music would require a timer-tick ISR (`INT 1Ch` hook) and complex coordination with word sound cues. Jingles deliver the "feels like a real game" benefit at ~5% of the implementation cost.
- **`USERS.DAT` shares format style with `SCORES.DAT`.** *(v1.3)* Both are fixed-width 8-byte records, 5 entries max. New `USER_LOAD` / `USER_SAVE` / `USER_AUTH` procedures in `FILEIO.ASM` mirror the leaderboard pattern.
- **Scrambled letter hint, hardcoded per word.** *(v1.4)* Each round shows a jumbled version of the target word (e.g., `APPLE` → `PLEPA`) alongside the sprite and sound cue. Stored in a parallel `SCRAMBLE_TABLE` indexed the same way as `SPRITE_TABLE` and `SOUND_TABLE` (global word index = `DIFFICULTY*10 + CURRENT_WORD`). 30 entries × 16 bytes = 480 bytes.
- **Why hardcode rather than runtime-randomize the scramble.** *(v1.4)* (a) Avoids an RNG dependency for one feature. (b) Guarantees each scramble looks good — distinct from the original, ideally not a real word, length-matched. (c) Consistency across plays helps toddlers build pattern recognition. The cost — 480 bytes — is trivial.
- **Modular `.ASM` files, state machine pattern, data-driven word list.** Unchanged.

---

# Chapter 2 — Code Modules & File Structure

## 2.1 File Layout

```
spelling_game/
├── src/
│   ├── MAIN.ASM          ← Entry point + main loop
│   ├── STATE.ASM         ← State dispatcher + transitions (v1.3: + STATE_LOGIN)
│   ├── DATA.ASM          ← Word list, sprite data, sound data, jingles (v1.3), strings
│   │
│   ├── GFX.ASM           ← Mode 13h primitives + GFX_LOAD_BG
│   ├── AUDIO.ASM         ← PC speaker tone/pattern playback (unchanged in v1.3)
│   ├── INPUT.ASM         ← Keyboard read routines (v1.3: + INP_READ_PASSWORD)
│   ├── FILEIO.ASM        ← Leaderboard + user account I/O (v1.3: + USER_* procs)
│   │
│   ├── SCR_INTRO.ASM     ← Title, login (v1.3), mode, name, difficulty, instructions
│   ├── SCR_GAME.ASM      ← Round + judge (1P/2P unified)
│   ├── SCR_END.ASM       ← Score + leaderboard + game over (v1.3: + end jingle)
│   │
│   └── SHARED.INC        ← Shared constants, macros, EXTRN decls
│
├── assets/
│   ├── sprites/          ← PNG mockups from spriter
│   ├── sprite_bytes.txt  ← Exported raw byte arrays
│   └── backgrounds/      ← Full-screen mockups
│       ├── TITLE.BIN     ← 64,000 bytes each, raw Mode 13h dump
│       ├── LOGIN.BIN     ← v1.3
│       ├── MODE.BIN
│       ├── NAME.BIN
│       ├── DIFF.BIN
│       ├── INSTR.BIN
│       ├── ROUND.BIN
│       └── END.BIN
│
├── build/
│   ├── BUILD.BAT         ← Assemble + link all modules
│   └── CLEAN.BAT
│
├── bin/
│   ├── SPELL.EXE         ← The shipping executable
│   ├── SCORES.DAT        ← Leaderboard save file
│   ├── USERS.DAT         ← v1.3: user accounts (created on first launch)
│   ├── TITLE.BIN         ← All .BIN files copied from assets/backgrounds/
│   ├── LOGIN.BIN         ← v1.3
│   ├── MODE.BIN
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

> 📌 **No new `.ASM` files in v1.3.** Login goes in existing `SCR_INTRO.ASM`. User auth goes in existing `FILEIO.ASM`. Password input goes in existing `INPUT.ASM`. Jingles are just data in existing `DATA.ASM`. `BUILD.BAT` structure is unchanged.

## 2.2 Module Responsibilities

### Core Engine

| Module      | Owns                                               | Exports                                                                                                                                                                                                                                                                                                  |
| ----------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MAIN.ASM`  | Program entry, global game loop, all runtime state | (none — it's the top level)                                                                                                                                                                                                                                                                              |
| `STATE.ASM` | `CURRENT_STATE` byte, transition logic             | `GAME_TICK`                                                                                                                                                                                                                                                                                              |
| `DATA.ASM`  | All static game data                               | Labels: `EASY_WORDS`, `MED_WORDS`, `HARD_WORDS`, `TIER_TABLE`, `SPRITE_TABLE`, `SOUND_TABLE`, `SCRAMBLE_TABLE` *(v1.4)*, `SND_TITLE_JINGLE` *(v1.3)*, `SND_WIN_JINGLE` *(v1.3)*, `SND_LOSE_JINGLE` *(v1.3)*, UI strings (incl. `STR_HINT` *(v1.4)*), `BG_*` filename strings (incl. `BG_LOGIN` *(v1.3)*) |

### I/O Services

| Module       | Owns                                               | Exports                                                                                                                       |
| ------------ | -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `GFX.ASM`    | Video mode, drawing primitives, background loading | `GFX_INIT`, `GFX_CLEAR`, `GFX_LOAD_BG`, `GFX_DRAW_SPRITE`, `GFX_DRAW_CHAR`, `GFX_DRAW_STRING`, `GFX_SHUTDOWN`                 |
| `AUDIO.ASM`  | Speaker port control                               | `SND_PLAY_TONE`, `SND_SILENCE`, `SND_PLAY_PATTERN`, `SND_DELAY`                                                               |
| `INPUT.ASM`  | Keyboard polling                                   | `INP_WAIT_KEY`, `INP_CHECK_KEY`, `INP_READ_STRING`, `INP_READ_PASSWORD` *(v1.3)*                                              |
| `FILEIO.ASM` | Leaderboard + user account disk I/O                | `FILE_LOAD_SCORES`, `FILE_SAVE_SCORES`, `FILE_INSERT_SCORE`, `USER_LOAD` *(v1.3)*, `USER_AUTH` *(v1.3)*, `USER_SAVE` *(v1.3)* |

### Screen Handlers

| Module          | Owns                                                                    | Exports                                                                                                    |
| --------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `SCR_INTRO.ASM` | Title, login *(v1.3)*, mode, name, difficulty, instructions             | `SCR_TITLE_RUN`, `SCR_LOGIN_RUN` *(v1.3)*, `SCR_MODE_RUN`, `SCR_NAME_RUN`, `SCR_DIFF_RUN`, `SCR_INSTR_RUN` |
| `SCR_GAME.ASM`  | Round logic (with 2P loop), scoring, judgment                           | `SCR_ROUND_RUN`, `SCR_JUDGE_RUN`                                                                           |
| `SCR_END.ASM`   | Score display, leaderboard, 2P winner display, win/lose jingle *(v1.3)* | `SCR_END_RUN`                                                                                              |

### Shared

| Module       | Contents                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SHARED.INC` | `EQU` constants (`STATE_TITLE=0`, `STATE_LOGIN=1` *(v1.3)*, `STATE_MODE=2`, `STATE_NAME=3`, `STATE_DIFF=4`, `STATE_INSTR=5`, `STATE_ROUND=6`, `STATE_JUDGE=7`, `STATE_END=8`, `STATE_QUIT=9`, `DIFF_EASY=0`, `DIFF_MED=1`, `DIFF_HARD=2`, `MAX_HEARTS=3`, `MAX_PLAYERS=2`, `WORDS_PER_TIER=10`, `WORD_RECORD_SIZE=16`, `SPRITE_SIZE=1024`, `BG_SIZE=64000`, `MAX_USERS=5` *(v1.3)*, `USER_RECORD_SIZE=8` *(v1.3)*, `USERNAME_LEN=3` *(v1.3)*, `PASSWORD_LEN=5` *(v1.3)*, `MAX_LOGIN_RETRIES=3` *(v1.3)*), macros, `EXTRN` declarations |

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
         ├─► FILEIO (v1.3)├─► AUDIO        ├─► AUDIO (v1.3)
         ├─► AUDIO (v1.3) ├─► DATA         ├─► FILEIO
         │                                 │
         └─► (all screens read DATA for strings;
              all screens call GFX_LOAD_BG at entry)

v1.3 additions to call graph:
  - SCR_INTRO calls FILEIO (USER_LOAD/AUTH/SAVE) for login screen
  - SCR_INTRO calls AUDIO (SND_PLAY_PATTERN) for title jingle
  - SCR_END calls AUDIO (SND_PLAY_PATTERN) for win/lose jingle
```

**Dependency rules:**

- Screen modules depend on service modules and `DATA`.
- Service modules are **independent** of each other.
- `STATE.ASM` calls into screen modules; screens only *update* the state byte.
- `DATA.ASM` is pure data — no code, no calls.
- `GFX.ASM` uses `INT 21h` directly for `GFX_LOAD_BG`; it does NOT call `FILEIO`.
- `FILEIO.ASM` now owns two distinct file responsibilities (scores + users), but they're independent procs sharing no state. *(v1.3)*

## 2.4 Team Workload Assignment

> ⚠️ **v1.3 scope warning:** Original 1-week sprint is now ~13 days. Each round of features adds 2-3 dev-days. Communicate the new ETA. Strict freeze after v1.3.

### 🧑‍💻 Dev 1 — Lead (You)

- `MAIN.ASM`, `STATE.ASM`, `SHARED.INC`
- `SCR_INTRO.ASM` (incl. new `SCR_LOGIN_RUN` *(v1.3)*, `SCR_MODE_RUN` with PLAYER_NAMES[0] pre-fill *(v1.3)*, `SCR_NAME_RUN` with 2P loop)
- `SCR_GAME.ASM` (2P round loop + judging both players)
- `SCR_END.ASM` (incl. win/lose jingle playback *(v1.3)*, side-by-side 2P score display)
- Integration, final debugging
- **~24 hours total** (was ~22; +2 for `SCR_LOGIN_RUN` and pre-fill plumbing)

### 🧑‍💻 Dev 2 — Graphics + Input

- `GFX.ASM` (Mode 13h, sprite draw, text draw with transparency, `GFX_LOAD_BG`)
- Font rendering with transparency
- `INPUT.ASM` (incl. new `INP_READ_PASSWORD` *(v1.3)* — masks echo as `*`)
- **~11 hours total** (was ~10; +1 for `INP_READ_PASSWORD`)

### 🧑‍💻 Dev 3 — Audio + File I/O

- `AUDIO.ASM` (unchanged in v1.3 — jingles use existing `SND_PLAY_PATTERN`)
- `FILEIO.ASM` (incl. new `USER_LOAD`, `USER_AUTH`, `USER_SAVE` *(v1.3)*)
- **~9 hours total** (was ~6; +3 for user account I/O)

### 🎨 Spriter (parallel, off critical path)

- **30 × 32×32 sprites** in 16-color VGA palette (10 Easy + 10 Medium + 10 Hard)
- **8 × full-screen 320×200 backgrounds** *(v1.3 adds LOGIN.BIN)* — TITLE, **LOGIN**, MODE, NAME, DIFF, INSTR, ROUND, END
  - LOGIN.BIN needs reserved blank areas for "USERNAME:" and "PASSWORD:" labels (around y=80 and y=110) and input fields beside them
  - ROUND.BIN needs reserved blank area where the sprite renders (around x=144, y=50), where the scramble hint renders *(v1.4)* (around x=120, y=95), and where text labels go
  - Export each as raw 64,000-byte `.BIN` file
- **30 scramble strings** *(v1.4)* — one jumbled version per word, populated into `SCRAMBLE_TABLE` in `DATA.ASM`. Rules: same letters as the original, different order, ideally not a real word. Length-match the original (e.g., `APPLE` (5) → `PLEPA` (5)). ~1 hour with the spriter or whoever populates the word list.
- `DATA.ASM` population (sprite bytes + jingle patterns *(v1.3)* + scramble table *(v1.4)*)
- **~27-31 hours total** (was 26-30; +1 for scramble strings)
- **TALK TO THEM TODAY.**

**Fallback if spriter capacity is genuinely insufficient:**

- LOGIN.BIN can reuse NAME.BIN initially (same form-style layout) — recolor only if time permits.
- Drop further to 4 unique backgrounds + reuse: TITLE, ROUND, END, INSTR — reuse INSTR.BIN for MODE/NAME/DIFF/LOGIN.
- Drop sprite count to 6-8 per tier if needed.

**If Dev 3 flakes:** Dev 1 absorbs `FILEIO.ASM` (now larger). Dev 2 absorbs `AUDIO.ASM`. **In this scenario, defer login to post-MVP** — it's the only fully removable feature.

## 2.5 Build System

### `BUILD.BAT` (runs inside DOSBox)

**No structural changes from v1.2** — v1.3 adds no new `.ASM` files. The eventual full build script remains:

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

REM Copy background .BIN assets to runtime dir
copy assets\backgrounds\*.BIN bin\

echo Build complete: bin\SPELL.EXE
```

**v1.3 recommendation:** Add a new smoke-test entry `TEST_USR` for user-account I/O. Mirrors the existing `TEST_INP` / `TEST_GFX` pattern. Useful before integrating `SCR_LOGIN_RUN`.

```batch
:TEST_USR
echo Building smoke test: USER auth
tasm /zi /isrc tests\TEST_USR.ASM
if errorlevel 1 goto FAIL
copy TEST_USR.OBJ build\TEST_USR.OBJ >nul
del TEST_USR.OBJ
tasm /zi /isrc src\FILEIO.ASM
if errorlevel 1 goto FAIL
copy FILEIO.OBJ build\FILEIO.OBJ >nul
del FILEIO.OBJ
tlink /v build\TEST_USR.OBJ+build\FILEIO.OBJ, bin\TEST_USR.EXE
if errorlevel 1 goto FAIL
echo Build complete: bin\TEST_USR.EXE
goto DONE
```

### Workflow

Unchanged from v1.2. Edit `.ASM` in host editor → DOSBox → `BUILD.BAT` → run `bin\SPELL.EXE`.

---

# Chapter 3 — Core Engine Modules

## 3.1 `MAIN.ASM` — Entry Point & Game Loop

### Purpose

The top-level module. Owns program initialization, the main loop, and shutdown. Declares all mutable runtime state as globals.

### Dependencies

- `STATE.ASM` (calls `GAME_TICK`)
- `GFX.ASM` (calls `GFX_INIT`, `GFX_SHUTDOWN`)
- `FILEIO.ASM` (calls `FILE_LOAD_SCORES`, `USER_LOAD` *(v1.3)*)
- `SHARED.INC`

### Structure (v1.3)

```asm
; MAIN.ASM — Entry point and game loop
.MODEL SMALL
.STACK 1024
.DATA
    INCLUDE SHARED.INC

    ; --- Runtime state (global variables) ---
    CURRENT_STATE   DB  STATE_TITLE
    NUM_PLAYERS     DB  1
    CURRENT_PLAYER  DB  0
    DIFFICULTY      DB  DIFF_EASY
    CURRENT_WORD    DB  0
    TIMER_START     DW  0

    ; --- Login / user account state (v1.3) ---
    SESSION_USER    DB  '   '            ; logged-in username
    USER_TABLE      DB  MAX_USERS * USER_RECORD_SIZE DUP(0)  ; 5 × 8 = 40 bytes
    USER_COUNT      DB  0                ; active entries in USER_TABLE
    LOGIN_RETRIES   DB  0                ; wrong-password counter
    USERNAME_BUF    DB  3 DUP(0)         ; login input scratch
    PASSWORD_BUF    DB  5 DUP(0)         ; login input scratch

    ; --- Player-indexed arrays ---
    PLAYER_NAMES    DB  '   ', '   '     ; 2 × 3-char names
    SCORES          DW  0, 0
    HEARTS_ARR      DB  MAX_HEARTS, MAX_HEARTS
    PLAYER_RESULTS  DB  0, 0
    PLAYER_TIMES    DW  0, 0

    INPUT_BUFFER    DB  17 DUP(0)

    PUBLIC CURRENT_STATE, NUM_PLAYERS, CURRENT_PLAYER, DIFFICULTY
    PUBLIC CURRENT_WORD, TIMER_START
    PUBLIC SESSION_USER, USER_TABLE, USER_COUNT, LOGIN_RETRIES
    PUBLIC USERNAME_BUF, PASSWORD_BUF
    PUBLIC PLAYER_NAMES, SCORES, HEARTS_ARR, PLAYER_RESULTS, PLAYER_TIMES
    PUBLIC INPUT_BUFFER

.CODE
    EXTRN GAME_TICK:PROC
    EXTRN GFX_INIT:PROC, GFX_SHUTDOWN:PROC
    EXTRN FILE_LOAD_SCORES:PROC
    EXTRN USER_LOAD:PROC                ; ← NEW (v1.3)

MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    CALL GFX_INIT
    CALL FILE_LOAD_SCORES
    CALL USER_LOAD                       ; ← NEW (v1.3): populate USER_TABLE

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

### Design Notes

- **`USER_LOAD` is called once at startup**, populates `USER_TABLE` from disk. If `USERS.DAT` doesn't exist, leaves `USER_COUNT=0` and continues silently (first-launch case).
- **`SESSION_USER` is set by `SCR_LOGIN_RUN`** on successful auth. Read by `SCR_MODE_RUN` to pre-fill `PLAYER_NAMES[0]`.
- **`USERNAME_BUF` / `PASSWORD_BUF` are scratch** — only valid during `SCR_LOGIN_RUN`. Don't read them elsewhere.

### Integration Contract

- **Inputs:** None.
- **Outputs:** Sets up `DS`, runs main loop, exits to DOS.
- **Called by:** DOS.
- **Calls:** `GAME_TICK`, `GFX_INIT`, `GFX_SHUTDOWN`, `FILE_LOAD_SCORES`, `USER_LOAD` *(v1.3)*.

---

## 3.2 `STATE.ASM` — Game State Machine

### Purpose

Dispatches the current game state to the correct screen handler.

### Dependencies

- All `SCR_*.ASM` modules
- `SHARED.INC`

### Structure (v1.3)

```asm
; STATE.ASM — State dispatcher
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE

.CODE
    EXTRN SCR_TITLE_RUN:PROC
    EXTRN SCR_LOGIN_RUN:PROC            ; ← NEW (v1.3)
    EXTRN SCR_MODE_RUN:PROC
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
    CMP AL, STATE_LOGIN                  ; ← NEW (v1.3)
    JE  GT_LOGIN                         ; ← NEW (v1.3)
    CMP AL, STATE_MODE
    JE  GT_MODE
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
GT_LOGIN:   CALL SCR_LOGIN_RUN           ; ← NEW (v1.3)
            RET
GT_MODE:    CALL SCR_MODE_RUN
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

Unchanged from v1.2 except for the new `STATE_LOGIN` dispatch. Pattern is identical to other states.

### Integration Contract

- **Inputs:** Reads `CURRENT_STATE`.
- **Outputs:** Calls the appropriate screen handler.
- **Called by:** `MAIN.ASM`.
- **Calls:** All `SCR_*_RUN` procedures, including `SCR_LOGIN_RUN` *(v1.3)*.

---

## 3.3 `DATA.ASM` — Word List & Assets

### Purpose

The project's "database." All compile-time-constant data.

### Structure (v1.3 — jingle patterns + login strings added; word/sprite/sound sections unchanged)

```asm
; DATA.ASM — Word list (3 tiers), sprite data, sound patterns, jingles, UI strings
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    ; [EASY_WORDS, MED_WORDS, HARD_WORDS, TIER_TABLE, SPRITE_TABLE,
    ;  SOUND_TABLE and all SND_* per-word patterns are unchanged from v1.2.
    ;  Refer to v1.2 spec for body.]

    ; --- v1.3: Jingle patterns (freq, duration_ms pairs, 0-terminated) ---
    PUBLIC SND_TITLE_JINGLE, SND_WIN_JINGLE, SND_LOSE_JINGLE

SND_TITLE_JINGLE:
    DW  523, 150     ; C5
    DW  659, 150     ; E5
    DW  784, 150     ; G5
    DW 1047, 300     ; C6
    DW    0          ; terminator

SND_WIN_JINGLE:
    DW  523, 120     ; C5
    DW  659, 120     ; E5
    DW  784, 120     ; G5
    DW 1047, 120     ; C6
    DW  784, 120     ; G5
    DW 1319, 400     ; E6 (held)
    DW    0          ; terminator

SND_LOSE_JINGLE:
    DW  523, 200     ; C5
    DW  494, 200     ; B4
    DW  440, 200     ; A4
    DW  392, 500     ; G4 (held)
    DW    0          ; terminator

    ; --- v1.4: Scrambled hint table (parallel to SPRITE_TABLE / SOUND_TABLE) ---
    ; Indexed by global word index: DIFFICULTY * 10 + CURRENT_WORD
    ; Each entry is 16 bytes (WORD_RECORD_SIZE), null-padded.
    ; Layout matches the word arrays for symmetry, but only the prefix
    ; up to the null is read. Spriter/word-list owner fills in real scrambles.
    PUBLIC SCRAMBLE_TABLE

SCRAMBLE_TABLE:
    ; --- EASY tier (indices 0..9) ---
    DB 'TAC',0,            0,0,0,0,0,0,0,0,0,0,0,0   ; CAT
    DB 'GDO',0,            0,0,0,0,0,0,0,0,0,0,0,0   ; DOG
    ; ... 8 more EASY scrambles, 16 bytes each ...

    ; --- MEDIUM tier (indices 10..19) ---
    DB 'PLEPA',0,          0,0,0,0,0,0,0,0,0,0       ; APPLE
    DB 'IARNT',0,          0,0,0,0,0,0,0,0,0,0       ; TRAIN
    ; ... 8 more MED scrambles, 16 bytes each ...

    ; --- HARD tier (indices 20..29) ---
    DB 'GNAROE',0,         0,0,0,0,0,0,0,0,0         ; ORANGE
    DB 'IDGEBR',0,         0,0,0,0,0,0,0,0,0         ; BRIDGE
    ; ... 8 more HARD scrambles, 16 bytes each ...

    ; TOTAL: 30 entries × 16 bytes = 480 bytes

    ; --- UI strings (v1.3 + v1.4 additions marked) ---
    PUBLIC STR_TITLE, STR_INSTR, STR_GAMEOVER, STR_WIN
    PUBLIC STR_DIFF_PROMPT, STR_EASY, STR_MED, STR_HARD
    PUBLIC STR_MODE_PROMPT, STR_1P, STR_2P
    PUBLIC STR_PLAYER1, STR_PLAYER2, STR_YOUR_TURN
    PUBLIC STR_VS, STR_WINNER, STR_TIE
    PUBLIC STR_LOGIN, STR_USERNAME, STR_PASSWORD                  ; ← NEW (v1.3)
    PUBLIC STR_WELCOME, STR_NEW_USER, STR_WRONG_PW, STR_USERS_FULL ; ← NEW (v1.3)
    PUBLIC STR_HINT                                               ; ← NEW (v1.4)

STR_TITLE:       DB 'SPELLING FUN!',0
STR_INSTR:       DB 'TYPE WHAT YOU HEAR. PRESS ENTER.',0
STR_GAMEOVER:    DB 'GAME OVER',0
STR_WIN:         DB 'YOU DID IT!',0
STR_DIFF_PROMPT: DB 'CHOOSE DIFFICULTY:',0
STR_EASY:        DB '1. EASY',0
STR_MED:         DB '2. MEDIUM',0
STR_HARD:        DB '3. HARD',0

STR_MODE_PROMPT: DB 'CHOOSE MODE:',0
STR_1P:          DB '1. ONE PLAYER',0
STR_2P:          DB '2. TWO PLAYERS',0
STR_PLAYER1:     DB 'PLAYER 1',0
STR_PLAYER2:     DB 'PLAYER 2',0
STR_YOUR_TURN:   DB 'YOUR TURN!',0
STR_VS:          DB ' VS ',0
STR_WINNER:      DB 'WINNER: ',0
STR_TIE:         DB 'ITS A TIE!',0

; --- Login strings (v1.3) ---
STR_LOGIN:       DB 'LOGIN',0
STR_USERNAME:    DB 'USERNAME:',0
STR_PASSWORD:    DB 'PASSWORD:',0
STR_WELCOME:     DB 'WELCOME BACK!',0
STR_NEW_USER:    DB 'NEW PLAYER! WELCOME!',0
STR_WRONG_PW:    DB 'WRONG PASSWORD. TRY AGAIN.',0
STR_USERS_FULL:  DB 'USERS FULL. TRY LATER.',0

; --- Scramble hint label (v1.4) ---
STR_HINT:        DB 'HINT: ',0

    ; --- Background filenames ---
    PUBLIC BG_TITLE, BG_LOGIN, BG_MODE, BG_NAME, BG_DIFF, BG_INSTR, BG_ROUND, BG_END
BG_TITLE:  DB 'TITLE.BIN',0
BG_LOGIN:  DB 'LOGIN.BIN',0                                       ; ← NEW (v1.3)
BG_MODE:   DB 'MODE.BIN',0
BG_NAME:   DB 'NAME.BIN',0
BG_DIFF:   DB 'DIFF.BIN',0
BG_INSTR:  DB 'INSTR.BIN',0
BG_ROUND:  DB 'ROUND.BIN',0
BG_END:    DB 'END.BIN',0

    ; --- Filenames for FILEIO ---
    PUBLIC FN_SCORES, FN_USERS                                    ; ← FN_USERS NEW (v1.3)
FN_SCORES: DB 'SCORES.DAT',0
FN_USERS:  DB 'USERS.DAT',0                                       ; ← NEW (v1.3)

END
```

```tasm
; DATA.ASM from v1.2 — Word list (3 tiers), sprite data, sound patterns, UI strings
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

- **Jingles are pattern data, not code.** `SND_PLAY_PATTERN` (Chapter 4.3) already handles freq/duration pairs terminated by `0`. Adding new jingles = adding data only.
- **Pitch values use standard PC speaker frequencies.** C5=523Hz, E5=659Hz, etc. Adjust if they sound off in DOSBox — the senior project's PCM emulation handles these cleanly.
- **Win jingle is uplifting (ascending then resolves up), lose is descending.** Standard musical conventions; instant recognition.
- **Filename strings centralized** so screens just reference labels (`LEA DX, BG_LOGIN`).
- **`SCRAMBLE_TABLE` is parallel to `SPRITE_TABLE` and `SOUND_TABLE`.** *(v1.4)* Same global word index (`DIFFICULTY * 10 + CURRENT_WORD`), same access pattern. Records are 16 bytes (`WORD_RECORD_SIZE`) with null-terminated strings padded to width — readable by `GFX_DRAW_STRING` as-is.
- **Scramble strings are NOT validated at build time.** *(v1.4)* If someone types `'APPLE'` instead of a scramble, the game still runs — it just shows the answer as the hint, which is a content bug not a code bug. Spriter is responsible for content quality.

### Integration Contract

- **Inputs:** None.
- **Outputs:** All labels exported via `PUBLIC`.

---

# Chapter 4 — I/O Modules

## 4.1 `INPUT.ASM` — Keyboard Input

### Purpose

All keyboard reading goes through here. Four modes: wait for any key, check if a key is pressed (non-blocking), read a string until Enter, **read a masked password (v1.3)**.

### Dependencies

- `GFX.ASM` for the password echo path (calls `GFX_DRAW_CHAR` to render `*`)
- `SHARED.INC`

### Structure (v1.3 — only `INP_READ_PASSWORD` is new; others unchanged)

```asm
; INPUT.ASM — Keyboard services
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

.CODE
    EXTRN GFX_DRAW_CHAR:PROC             ; ← for password masking (v1.3)

    PUBLIC INP_WAIT_KEY, INP_CHECK_KEY, INP_READ_STRING
    PUBLIC INP_READ_PASSWORD             ; ← NEW (v1.3)

; [INP_WAIT_KEY, INP_CHECK_KEY, INP_READ_STRING unchanged from v1.2 — see that spec]

;---------------------------------------------------------------
; INP_READ_PASSWORD — Read a fixed-length password, echo as '*'.   ← NEW (v1.3)
; In:  ES:DI = buffer (must have CX bytes available)
;      CX    = exact password length (5 for our use)
;      BX    = screen X position for echo (asterisks drawn here)
;      DX    = screen Y position for echo
; Out: Buffer filled with CX uppercase chars (no null terminator —
;      caller knows the length); screen shows '*' per char.
; Preserves: ES, DI on return (caller-relevant)
; Clobbers:  AX, BX, CX, DX, flags
;---------------------------------------------------------------
INP_READ_PASSWORD PROC
    PUSH SI
    PUSH DI
    PUSH BX
    PUSH DX

    XOR  SI, SI                 ; SI = chars typed so far
    MOV  BP, BX                 ; preserve starting X in BP
                                ; (each char advances X by 8px)

IRP_LOOP:
    CMP  SI, CX
    JAE  IRP_WAIT_ENTER         ; full — only Enter terminates
    CALL INP_WAIT_KEY
    CMP  AL, 13
    JE   IRP_DONE
    CMP  AL, 8                  ; backspace
    JE   IRP_BACKSPACE

    ; --- Validate: must be letter or digit ---
    CMP  AL, '0'
    JB   IRP_LOOP
    CMP  AL, '9'
    JBE  IRP_STORE
    CMP  AL, 'a'
    JB   IRP_CHECK_UPPER
    CMP  AL, 'z'
    JA   IRP_LOOP
    SUB  AL, 32                 ; lowercase → uppercase
    JMP  IRP_STORE
IRP_CHECK_UPPER:
    CMP  AL, 'A'
    JB   IRP_LOOP
    CMP  AL, 'Z'
    JA   IRP_LOOP

IRP_STORE:
    MOV  ES:[DI+SI], AL         ; store the REAL char in buffer
    ; --- Echo '*' at current screen position ---
    PUSH AX
    MOV  AL, '*'
    PUSH CX
    MOV  CX, BX                 ; X position
    CALL GFX_DRAW_CHAR
    POP  CX
    POP  AX
    ADD  BX, 8                  ; advance cursor X
    INC  SI
    JMP  IRP_LOOP

IRP_BACKSPACE:
    OR   SI, SI
    JZ   IRP_LOOP
    DEC  SI
    SUB  BX, 8
    ; TODO: redraw space at cursor position (Dev 2 — same trick as INP_READ_STRING)
    JMP  IRP_LOOP

IRP_WAIT_ENTER:
    CALL INP_WAIT_KEY
    CMP  AL, 13
    JNE  IRP_WAIT_ENTER

IRP_DONE:
    POP  DX
    POP  BX
    POP  DI
    POP  SI
    RET
INP_READ_PASSWORD ENDP

END
```

### v1.2 version (for reference)

```asm6502
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

- **Fixed length, no early termination by Enter mid-string.** Once `SI == CX`, further keys are ignored until Enter. This makes the buffer always exactly `CX` chars long — no null terminator needed; caller uses `PASSWORD_LEN` constant.
- **`INP_READ_STRING` is variable-length, null-terminated; `INP_READ_PASSWORD` is fixed-length, no terminator.** Different contracts because login compares fixed-width 5-byte fields against `USER_TABLE`.
- **Backspace cursor redraw is the same TODO that exists for `INP_READ_STRING`** — Dev 2 should solve once for both.
- **Echo position is caller-supplied** because `GFX_DRAW_CHAR` doesn't track a cursor. `SCR_LOGIN_RUN` provides the starting X/Y where the password field begins.

### Integration Contract

- **`INP_READ_PASSWORD`:**
  - **In:** `ES:DI` = buffer, `CX` = length, `BX,DX` = echo position
  - **Out:** Buffer filled with `CX` uppercase chars
  - **Clobbers:** `AX, BX, CX, DX, flags`
  - **Preserves:** `ES, DI, SI, BP`
  - **Calls:** `INP_WAIT_KEY`, `GFX_DRAW_CHAR`

---

## 4.2 `GFX.ASM` — Graphics (Mode 13h, Backgrounds, Sprite Rendering)

**No v1.3 changes.** See v1.2 spec body. The font transparency requirement remains critical: `GFX_DRAW_CHAR`'s inner loop must skip "off" pixels in the glyph bitmap. Without this, the `*` characters in the password field will punch black rectangles through the LOGIN.BIN background.

Purpose

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
  - **Calls:** `INT 21h` (3Dh open, 3Fh read, 3Eh close)---

## 4.3 `AUDIO.ASM` — PC Speaker Sound Cues & Jingles

### Purpose

Play distinguishable tone patterns. Used for both per-word sound cues (during gameplay) and jingles (title screen, win/lose at end). **No new procedures in v1.3** — jingles use existing `SND_PLAY_PATTERN`.

### v1.3 Usage Notes

- **Title jingle** plays during `SCR_TITLE_RUN` after `GFX_LOAD_BG` and before `INP_WAIT_KEY`. Blocks ~750ms (sum of jingle durations). User can press a key during the jingle; the press is buffered by BIOS and consumed when `INP_WAIT_KEY` runs.
- **Win/lose jingle** plays during `SCR_END_RUN` after `GFX_LOAD_BG` and before any other rendering. ~880ms for win, ~1100ms for lose.
- **Word sound cues** in `SCR_ROUND_RUN` are unchanged — same `SND_PLAY_PATTERN` calls, same patterns.

### Limitation (v1.3)

PC speaker is **monophonic**. While a jingle is playing, no other sound can play. While a word cue is playing, no jingle. This is why background music is rejected: it would block all gameplay audio. Sequential audio is the only model.

### Structure

Unchanged from v1.2. Procedures: `SND_PLAY_TONE`, `SND_SILENCE`, `SND_DELAY`, `SND_PLAY_PATTERN`.

### Integration Contract

Unchanged.

---

## 4.4 `FILEIO.ASM` — Leaderboard & User Account Persistence

### Purpose

Load and save the top-5 leaderboard to `SCORES.DAT`. **In v1.3, also load/save/auth user accounts via `USERS.DAT`.**

### Dependencies

- `SHARED.INC`
- `INT 21h` services
- `DATA.ASM` (for `FN_SCORES`, `FN_USERS` filename strings)

### File Formats

**`SCORES.DAT` (unchanged from v1.2):**

```
Record layout (8 bytes each):
  Offset 0-2:  3-byte name
  Offset 3-4:  16-bit score (little-endian word)
  Offset 5:    difficulty byte (0=Easy, 1=Med, 2=Hard)
  Offset 6-7:  2-byte padding

Total file size: 5 × 8 = 40 bytes.
```

**`USERS.DAT` (new in v1.3):**

```
Record layout (8 bytes each):
  Offset 0-2:  3-byte username (uppercase ASCII)
  Offset 3-7:  5-byte password (uppercase ASCII, fixed-width)

Total file size: 5 × 8 = 40 bytes.
Unused slots are zero-filled (first byte == 0 signals empty slot).
```

### New Procedures (v1.3)

```asm
;---------------------------------------------------------------
; USER_LOAD — Load USERS.DAT into USER_TABLE. Called once at boot.
; In:  none
; Out: USER_TABLE populated, USER_COUNT set
;      If USERS.DAT missing/short: USER_COUNT = 0, table zeroed
; Preserves: nothing critical
; Clobbers:  AX, BX, CX, DX, SI, DI
;---------------------------------------------------------------
; Implementation outline:
;   1. INT 21h, AH=3Dh open FN_USERS read-only
;      If CF set (file missing): zero USER_TABLE, set USER_COUNT=0, return
;   2. INT 21h, AH=3Fh read up to MAX_USERS*USER_RECORD_SIZE bytes
;      into USER_TABLE
;   3. Set USER_COUNT = (bytes_read / USER_RECORD_SIZE)
;   4. INT 21h, AH=3Eh close
;   5. Walk USER_TABLE counting non-zero first bytes to handle holes
;      (simpler: assume contiguous packing — register only inserts at end)

;---------------------------------------------------------------
; USER_AUTH — Check or register a user.
; In:  DS:SI = 3-byte username (uppercase)
;      DS:DI = 5-byte password (uppercase)
; Out: AX = 0  → existing user, password correct
;      AX = 1  → new user, registered into USER_TABLE in memory
;      AX = 2  → existing user, wrong password
;      AX = 3  → no such user, USER_TABLE full (cannot register)
; Side effect: on AX=1, USER_TABLE and USER_COUNT updated.
;              Caller should call USER_SAVE to persist.
; Preserves: SI, DI
; Clobbers:  AX, BX, CX, DX, flags
;---------------------------------------------------------------
; Implementation outline:
;   1. Walk USER_TABLE entries [0..USER_COUNT-1]:
;        Compare 3-byte name at offset 0.
;        If match:
;          Compare 5-byte password at offset 3.
;          If match: return AX=0
;          Else:     return AX=2
;   2. No match found:
;        If USER_COUNT == MAX_USERS: return AX=3
;        Else:
;          Copy username (3B) + password (5B) into next slot
;          INC USER_COUNT
;          Return AX=1

;---------------------------------------------------------------
; USER_SAVE — Write USER_TABLE back to USERS.DAT.
; In:  none (reads USER_TABLE, USER_COUNT)
; Out: USERS.DAT written. Errors silent (file system issues are rare in DOSBox).
; Preserves: nothing critical
; Clobbers:  AX, BX, CX, DX
;---------------------------------------------------------------
; Implementation outline:
;   1. INT 21h, AH=3Ch create/truncate FN_USERS
;   2. INT 21h, AH=40h write USER_COUNT * USER_RECORD_SIZE bytes from USER_TABLE
;   3. INT 21h, AH=3Eh close
```

### Design Notes

- **`USER_TABLE` is contiguous-packed.** New users go in slot `USER_COUNT`, then `USER_COUNT` increments. No "delete user" path in MVP — table only grows.
- **Empty `USERS.DAT` on first launch is normal.** `USER_LOAD` silently handles missing-file. First user to log in triggers auto-register, then `USER_SAVE` creates the file.
- **Password comparison is byte-by-byte over 5 fixed bytes** — no null terminator, no length to track. Simpler than string comparison.
- **No insertion order matters for users** (unlike scores). Order in file == order of first-time registration.
- **Leaderboard procedures (`FILE_LOAD_SCORES`, `FILE_SAVE_SCORES`, `FILE_INSERT_SCORE`) are unchanged from v1.2.** In 2P mode, `SCR_END_RUN` still calls `FILE_INSERT_SCORE` twice — once per player.

### Integration Contract

- **`USER_LOAD`:**
  - **In:** none
  - **Out:** `USER_TABLE` filled, `USER_COUNT` set
  - **Called by:** `MAIN.ASM` once at boot
- **`USER_AUTH`:**
  - **In:** `DS:SI`=name (3B), `DS:DI`=password (5B)
  - **Out:** `AX` ∈ {0, 1, 2, 3}
  - **Side effect:** May add entry to `USER_TABLE`
  - **Called by:** `SCR_LOGIN_RUN`
- **`USER_SAVE`:**
  - **In:** reads `USER_TABLE`, `USER_COUNT`
  - **Out:** `USERS.DAT` on disk
  - **Called by:** `SCR_LOGIN_RUN` after successful auth/registration

---

# Chapter 5 — Screen Modules

## 5.1 `SCR_INTRO.ASM` — Title + Login + Mode + Name + Difficulty + Instructions

### Purpose

The "onboarding" sequence: title (with jingle) → **login (v1.3)** → mode select → name entry (loops in 2P, skips Player 1 if logged in) → difficulty → instructions.

### Screens Owned

1. **`SCR_TITLE_RUN`** — title + jingle + "press any key" → `STATE_LOGIN` *(v1.3)*
2. **`SCR_LOGIN_RUN`** *(v1.3)* — username + password → auth → `STATE_MODE`
3. **`SCR_MODE_RUN`** — 1P vs 2P selection, pre-fills `PLAYER_NAMES[0]` *(v1.3)*
4. **`SCR_NAME_RUN`** — read 3 initials per player; skips Player 1 in 2P if logged in *(v1.3)*
5. **`SCR_DIFF_RUN`** — Easy / Medium / Hard
6. **`SCR_INSTR_RUN`** — explain gameplay

### Dependencies

- `GFX.ASM` (`GFX_LOAD_BG`, `GFX_DRAW_STRING`, `GFX_DRAW_CHAR`)
- `INPUT.ASM` (`INP_WAIT_KEY`, `INP_READ_STRING`, `INP_READ_PASSWORD` *(v1.3)*)
- `AUDIO.ASM` (`SND_PLAY_PATTERN`, `SND_DELAY`) *(v1.3)*
- `FILEIO.ASM` (`USER_AUTH`, `USER_SAVE`) *(v1.3)*
- `DATA.ASM`
- External globals: `CURRENT_STATE`, `NUM_PLAYERS`, `CURRENT_PLAYER`, `PLAYER_NAMES`, `DIFFICULTY`, `SESSION_USER`, `LOGIN_RETRIES`, `USERNAME_BUF`, `PASSWORD_BUF`

### Modified `SCR_TITLE_RUN` (v1.3)

```asm
;---------------------------------------------------------------
; SCR_TITLE_RUN — Title screen with jingle. Any key → STATE_LOGIN.
;---------------------------------------------------------------
SCR_TITLE_RUN PROC
    LEA  DX, BG_TITLE
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

    ; --- v1.3: Play title jingle (blocks ~750ms) ---
    LEA  SI, SND_TITLE_JINGLE
    CALL SND_PLAY_PATTERN

    CALL INP_WAIT_KEY

    MOV  CURRENT_STATE, STATE_LOGIN      ; ← v1.3 (was STATE_MODE)
    RET
SCR_TITLE_RUN ENDP
```

### New `SCR_LOGIN_RUN` (v1.3)

```asm
;---------------------------------------------------------------
; SCR_LOGIN_RUN — Login screen. Auth against USERS.DAT.
; Handles retry loop and welcome/error messages internally.
; Exit states:
;   STATE_MODE  — successful auth or new user registered
;   STATE_TITLE — 3 failed retries OR USERS.DAT full
;---------------------------------------------------------------
SCR_LOGIN_RUN PROC
    MOV  LOGIN_RETRIES, 0

SLR_RENDER:
    LEA  DX, BG_LOGIN
    CALL GFX_LOAD_BG

    LEA  SI, STR_LOGIN
    MOV  BL, 15
    MOV  CX, 130
    MOV  DX, 30
    CALL GFX_DRAW_STRING

    LEA  SI, STR_USERNAME
    MOV  CX, 60
    MOV  DX, 80
    CALL GFX_DRAW_STRING

    LEA  SI, STR_PASSWORD
    MOV  CX, 60
    MOV  DX, 110
    CALL GFX_DRAW_STRING

SLR_PROMPT:
    ; --- Read username (3 chars, normal echo) ---
    PUSH DS
    POP  ES
    LEA  DI, USERNAME_BUF
    MOV  CX, 3
    CALL INP_READ_STRING       ; (assumes Dev 2 wired echo at preset cursor pos)

    ; --- Read password (5 chars, masked echo) ---
    LEA  DI, PASSWORD_BUF
    MOV  CX, 5
    MOV  BX, 140               ; echo X position
    MOV  DX, 110               ; echo Y position
    CALL INP_READ_PASSWORD

    ; --- Auth ---
    LEA  SI, USERNAME_BUF
    LEA  DI, PASSWORD_BUF
    CALL USER_AUTH

    ; AX = 0 (OK), 1 (new), 2 (wrong pw), 3 (full)
    CMP  AX, 0
    JE   SLR_OK
    CMP  AX, 1
    JE   SLR_NEW
    CMP  AX, 3
    JE   SLR_FULL

    ; --- AX == 2: wrong password ---
    INC  LOGIN_RETRIES
    LEA  SI, STR_WRONG_PW
    MOV  BL, 12                ; red-ish
    MOV  CX, 60
    MOV  DX, 150
    CALL GFX_DRAW_STRING
    MOV  CX, 1200
    CALL SND_DELAY

    MOV  AL, LOGIN_RETRIES
    CMP  AL, MAX_LOGIN_RETRIES
    JAE  SLR_BAIL_TITLE
    JMP  SLR_RENDER

SLR_FULL:
    LEA  SI, STR_USERS_FULL
    MOV  BL, 12
    MOV  CX, 60
    MOV  DX, 150
    CALL GFX_DRAW_STRING
    MOV  CX, 2000
    CALL SND_DELAY
    JMP  SLR_BAIL_TITLE

SLR_NEW:
    LEA  SI, STR_NEW_USER
    JMP  SLR_PROCEED

SLR_OK:
    LEA  SI, STR_WELCOME

SLR_PROCEED:
    MOV  BL, 10                ; green-ish
    MOV  CX, 60
    MOV  DX, 150
    CALL GFX_DRAW_STRING

    ; --- Save SESSION_USER ---
    PUSH DS
    POP  ES
    LEA  SI, USERNAME_BUF
    LEA  DI, SESSION_USER
    MOV  CX, 3
    REP  MOVSB

    ; --- Persist USER_TABLE (writes file on new-user path; no-op cost on OK) ---
    CALL USER_SAVE

    MOV  CX, 1500
    CALL SND_DELAY

    MOV  CURRENT_STATE, STATE_MODE
    RET

SLR_BAIL_TITLE:
    MOV  CURRENT_STATE, STATE_TITLE
    RET
SCR_LOGIN_RUN ENDP
```

### Modified `SCR_MODE_RUN` (v1.3)

```asm
;---------------------------------------------------------------
; SCR_MODE_RUN — 1P or 2P select. Sets NUM_PLAYERS.
; v1.3: pre-fills PLAYER_NAMES[0] from SESSION_USER and routes
;       past name entry in 1P mode.
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
    JMP  SMR_PREFILL
SMR_2P:
    MOV  NUM_PLAYERS, 2

SMR_PREFILL:
    ; --- v1.3: Copy SESSION_USER → PLAYER_NAMES[0] ---
    PUSH DS
    POP  ES
    LEA  SI, SESSION_USER
    LEA  DI, PLAYER_NAMES
    MOV  CX, 3
    REP  MOVSB

    ; --- 1P: skip name entry entirely (CURRENT_PLAYER stays 0) ---
    CMP  NUM_PLAYERS, 1
    JNE  SMR_2P_PATH
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_DIFF
    RET

SMR_2P_PATH:
    ; --- 2P: enter SCR_NAME_RUN with CURRENT_PLAYER=1 (skip Player 1) ---
    MOV  CURRENT_PLAYER, 1
    MOV  CURRENT_STATE, STATE_NAME
    RET
SCR_MODE_RUN ENDP
```

### `SCR_NAME_RUN` (v1.3 — unchanged code; entry point semantics changed)

The procedure body is identical to v1.2. The only semantic change is that callers now sometimes set `CURRENT_PLAYER = 1` on first entry (when `SCR_MODE_RUN` did the v1.3 skip). The increment-and-compare loop still works correctly: from `CURRENT_PLAYER=1`, after one Player 2 entry, `CURRENT_PLAYER` becomes 2, equals `NUM_PLAYERS=2`, and transitions to `STATE_DIFF`.

### `SCR_DIFF_RUN`, `SCR_INSTR_RUN` (no v1.3 changes)

Same as v1.2.

### Design Notes

- **`SCR_LOGIN_RUN` is single-entry, single-exit.** It contains its own retry loop. The state machine doesn't loop on `STATE_LOGIN`; it enters once and exits to either `STATE_MODE` (success) or `STATE_TITLE` (bail). This contrasts with `SCR_NAME_RUN` which is re-entrant — different pattern, chosen here because retry UX is more naturally a tight loop.
- **Inline result messages.** "WELCOME BACK!" and "NEW PLAYER!" render briefly (1500ms) then transition. No dedicated state.
- **`USER_SAVE` is called even on success.** Harmless if `USER_TABLE` didn't change (rewrites same data). Cheaper than branching on auth result type.
- **`PLAYER_NAMES[0]` is overwritten by login.** If a future feature wanted "play as guest," it would need a separate guest flag — out of scope for MVP.
- **Cursor positions for echo are hardcoded.** `INP_READ_STRING` for username needs to know where to draw chars; per spec contract it gets a position via TODO-marked code path. `INP_READ_PASSWORD` takes `BX,DX` explicitly. Dev 2 should align both eventually.

### Integration Contract

- **`SCR_LOGIN_RUN`:**
  - **In:** Reads `USER_TABLE`, `STR_LOGIN`, etc. and `BG_LOGIN` filename.
  - **Out:** Writes `SESSION_USER`, may modify `USER_TABLE` (via `USER_AUTH`), writes `USERS.DAT` (via `USER_SAVE`). Sets `CURRENT_STATE` to `STATE_MODE` or `STATE_TITLE`.
- **`SCR_MODE_RUN`:**
  - **In:** Reads `SESSION_USER`.
  - **Out:** Writes `NUM_PLAYERS`, `CURRENT_PLAYER`, `PLAYER_NAMES[0]`. Sets `CURRENT_STATE` to `STATE_DIFF` (1P) or `STATE_NAME` (2P).

---

## 5.2 `SCR_GAME.ASM` — Main Gameplay Screen (1P + 2P)

### v1.4 Change: Render Scramble Hint in `SCR_ROUND_RUN`

`SCR_JUDGE_RUN` is **unchanged**. `SCR_ROUND_RUN` gains one new `EXTRN` and three lines of rendering, inserted after the sprite is drawn and before (or alongside) the sound cue plays. The scramble stays on screen for the full round so both players in 2P see the same hint.

**New EXTRN:**

```asm
    EXTRN SCRAMBLE_TABLE:BYTE                ; ← NEW (v1.4)
    EXTRN STR_HINT:BYTE                      ; ← NEW (v1.4)
    EXTRN WORD_RECORD_SIZE:ABS               ; reused for SCRAMBLE_TABLE stride
```

**Insertion point (pseudocode added to `SCR_ROUND_RUN`, after sprite draw):**

```asm
    ; ============================================================
    ; v1.4: Draw scrambled letter hint
    ; ------------------------------------------------------------
    ; At this point, the global word index has already been computed
    ; for sprite/sound resolution. Recompute (or preserve from earlier)
    ; into AX = DIFFICULTY * 10 + CURRENT_WORD.
    ; ============================================================
    MOV  AL, DIFFICULTY
    MOV  AH, 0
    MOV  BX, WORDS_PER_TIER          ; 10
    MUL  BX                          ; AX = DIFFICULTY * 10
    MOV  BL, CURRENT_WORD
    MOV  BH, 0
    ADD  AX, BX                      ; AX = global word index (0..29)

    ; --- Compute SCRAMBLE_TABLE offset: index * 16 ---
    MOV  CL, 4                       ; SHL by 4 = multiply by 16
    SHL  AX, CL                      ; AX = offset into SCRAMBLE_TABLE

    ; --- Draw "HINT: " label ---
    LEA  SI, STR_HINT
    MOV  BL, 14                      ; yellow-ish
    MOV  CX, 100                     ; X position (left-aligned)
    MOV  DX, 95                      ; Y position (below sprite at y=50+32=82)
    CALL GFX_DRAW_STRING

    ; --- Draw scrambled word, right after the label ---
    LEA  SI, SCRAMBLE_TABLE
    ADD  SI, AX                      ; DS:SI = scrambled string
    MOV  BL, 15                      ; white
    MOV  CX, 148                     ; X position (after "HINT: " label, ~6 chars × 8px)
    MOV  DX, 95
    CALL GFX_DRAW_STRING
    ; ============================================================
```

### Design Notes

- **Same global-index math as `SPRITE_TABLE` / `SOUND_TABLE`.** If you already computed the global index for sprite resolution, just preserve it in a register or memory slot through the scramble draw — don't recompute. The pseudocode above shows the standalone recomputation for clarity.
- **`SHL AX, CL` with `CL=4` multiplies by 16.** This is the `WORD_RECORD_SIZE` stride. If `WORD_RECORD_SIZE` ever changes (it shouldn't), this hardcoded shift breaks — the spec lists this as a known constant-coupling.
- **The hint draws once per round** (not per player). Both players in 2P see the same hint, which is the intended pacing — they're racing on the same problem.
- **Color choice:** Yellow `BL=14` for the "HINT:" label, white `BL=15` for the scramble itself. Matches the rest of the in-game text palette. Adjust if the spriter's `ROUND.BIN` background fights the color.
- **Position `(100, 95)` is approximate.** The sprite ends at y=82 (50 + 32). The hint sits ~13px below at y=95. Adjust based on what looks right against `ROUND.BIN`.
- **No timing change.** `SCR_ROUND_RUN`'s structure (sprite → sound → player loop) is unchanged; the scramble draw is purely additive and happens before the player loop begins.
- **`SCR_JUDGE_RUN` does NOT compare against the scramble.** Player input is still compared to the real word in `TIER_TABLE`. The scramble is read-only display data — toddlers see it as a letter-bank to help reconstruct the word.

### v1.4 Integration Contract Addendum

- **`SCR_ROUND_RUN` (v1.4):**
  - **Additional Inputs:** Reads `SCRAMBLE_TABLE`, `STR_HINT`.
  - **No new outputs.** State transitions unchanged.

`SCR_JUDGE_RUN`: **no changes.**

---

## 5.3 `SCR_END.ASM` — Score + Leaderboard + Game Over

### Purpose

Show final score(s), determine 2P winner if applicable, **play win or lose jingle (v1.3)**, insert players into leaderboard, display leaderboard, wait for key.

### v1.3 Additions

- **Win/lose jingle playback** at the top of `SCR_END_RUN`, immediately after `GFX_LOAD_BG`.
- Jingle selection: `SND_WIN_JINGLE` if all players have hearts > 0, else `SND_LOSE_JINGLE`.

### Dependencies

- `GFX.ASM`, `INPUT.ASM`, `FILEIO.ASM`, `AUDIO.ASM` *(v1.3)*
- External globals: `CURRENT_STATE`, `NUM_PLAYERS`, `PLAYER_NAMES`, `SCORES`, `HEARTS_ARR`, `DIFFICULTY`, `LEADERBOARD`

### Modified `SCR_END_RUN` (v1.3 — only the jingle insert is new)

```asm
SCR_END_RUN PROC
    LEA  DX, BG_END
    CALL GFX_LOAD_BG

    ; --- v1.3: Determine win/lose and play jingle ---
    MOV  AL, HEARTS_ARR
    OR   AL, AL
    JZ   SER_LOSE_JINGLE
    CMP  NUM_PLAYERS, 2
    JB   SER_WIN_JINGLE
    MOV  AL, HEARTS_ARR+1
    OR   AL, AL
    JZ   SER_LOSE_JINGLE

SER_WIN_JINGLE:
    LEA  SI, SND_WIN_JINGLE
    CALL SND_PLAY_PATTERN
    JMP  SER_AFTER_JINGLE

SER_LOSE_JINGLE:
    LEA  SI, SND_LOSE_JINGLE
    CALL SND_PLAY_PATTERN

SER_AFTER_JINGLE:
    ; --- Title banner: GAME OVER vs YOU DID IT! ---
    ; (Same win/lose check as above — could share a flag to avoid duplication.
    ;  Keeping flat for readability; cost is one extra CMP.)
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

    ; [Rest of SCR_END_RUN unchanged from v1.2:
    ;  - 1P or 2P score rendering
    ;  - winner determination (2P)
    ;  - FILE_INSERT_SCORE for each player
    ;  - FILE_SAVE_SCORES
    ;  - leaderboard rendering loop
    ;  - INP_WAIT_KEY
    ;  - CURRENT_STATE = STATE_QUIT]

    RET
SCR_END_RUN ENDP
```

### Design Notes

- **Jingle plays before any rendering past the background.** This gives the user a moment to read the screen as it appears, with audio reinforcing the outcome.
- **The duplicate hearts-check** (once for jingle, once for title banner) is intentional — keeps each block independently legible. A shared flag would save 6 bytes of code and cost readability.
- **Jingle blocks for ~880ms (win) or ~1100ms (lose).** Total time from STATE_END entry to leaderboard visible: ~1-1.5sec. Acceptable.

### Integration Contract

- **Inputs:** Reads `NUM_PLAYERS`, `SCORES[]`, `HEARTS_ARR[]`, `PLAYER_NAMES[]`, `DIFFICULTY`, `LEADERBOARD`.
- **Outputs:** Modifies leaderboard (1 or 2 inserts), writes file, plays jingle, sets `CURRENT_STATE = STATE_QUIT`.

---

# Chapter 6 — Integration & Testing

## 6.1 Module Integration Contracts

| Module                       | Promises (outputs)                                 | Requires (inputs)                                                         | Sets                                              |
| ---------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------- |
| `GAME_TICK` (STATE)          | Runs one state's screen                            | `CURRENT_STATE` valid                                                     | —                                                 |
| `GFX_INIT`                   | Mode 13h active, `ES=A000h`                        | —                                                                         | Video mode                                        |
| `GFX_LOAD_BG`                | Framebuffer filled from disk                       | `DS:DX`=filename                                                          | Video memory, `ES=A000h`                          |
| `GFX_DRAW_SPRITE`            | 32×32 sprite drawn (transparent color 0)           | `DS:SI`=sprite, `BX,DX`=pos                                               | Video memory                                      |
| `SND_PLAY_PATTERN`           | Pattern played to completion                       | `DS:SI`=pattern                                                           | Speaker, time                                     |
| `INP_READ_STRING`            | Null-term'd uppercase string                       | `ES:DI`=buf, `CX`=max                                                     | Buffer, `CX`=len                                  |
| `INP_READ_PASSWORD` *(v1.3)* | Fixed-length pw buffer, `*`-echoed                 | `ES:DI`=buf, `CX`=len, `BX,DX`=echo pos                                   | Buffer (exactly CX bytes)                         |
| `USER_LOAD` *(v1.3)*         | `USER_TABLE` populated                             | `USERS.DAT` (optional)                                                    | `USER_TABLE`, `USER_COUNT`                        |
| `USER_AUTH` *(v1.3)*         | Returns auth result code                           | `DS:SI`=name, `DS:DI`=password                                            | May modify `USER_TABLE`, `USER_COUNT`             |
| `USER_SAVE` *(v1.3)*         | `USER_TABLE` persisted                             | `USER_TABLE`, `USER_COUNT` valid                                          | `USERS.DAT`                                       |
| `FILE_LOAD_SCORES`           | Leaderboard populated                              | `SCORES.DAT` (optional)                                                   | `LEADERBOARD`                                     |
| `FILE_SAVE_SCORES`           | Leaderboard persisted                              | `LEADERBOARD` valid                                                       | `SCORES.DAT`                                      |
| `FILE_INSERT_SCORE`          | Entry inserted if qualifies                        | `DS:SI`=name, `BX`=score, `AL`=difficulty                                 | `LEADERBOARD` sorted                              |
| `SCR_TITLE_RUN`              | Title + jingle shown; key consumed                 | `BG_TITLE`, `SND_TITLE_JINGLE` *(v1.3)*                                   | `CURRENT_STATE = STATE_LOGIN`                     |
| `SCR_LOGIN_RUN` *(v1.3)*     | User authed or registered, or bailed               | `USER_TABLE`, login strings                                               | `SESSION_USER`, possibly `USER_TABLE`, state      |
| `SCR_MODE_RUN`               | Mode selected, `PLAYER_NAMES[0]` set               | `SESSION_USER` *(v1.3)*                                                   | `NUM_PLAYERS`, `CURRENT_PLAYER`, `PLAYER_NAMES`   |
| `SCR_NAME_RUN`               | One player's name read                             | `CURRENT_PLAYER` valid                                                    | `PLAYER_NAMES[CP]`, state                         |
| `SCR_DIFF_RUN`               | Difficulty selected                                | `STR_DIFF_*`                                                              | `DIFFICULTY`, state                               |
| `SCR_ROUND_RUN` *(v1.4)*     | Round played for all `NUM_PLAYERS`, scramble drawn | `CURRENT_WORD`, `DIFFICULTY`, `NUM_PLAYERS`, `SCRAMBLE_TABLE`, `STR_HINT` | `PLAYER_RESULTS[]`, `PLAYER_TIMES[]`, state       |
| `SCR_JUDGE_RUN`              | All players' scores/hearts updated                 | `PLAYER_RESULTS[]`, `PLAYER_TIMES[]`                                      | `SCORES[]`, `HEARTS_ARR[]`, `CURRENT_WORD`, state |
| `SCR_END_RUN` *(v1.3)*       | Jingle plays, both players inserted                | `SCORES[]`, `HEARTS_ARR[]`, `NUM_PLAYERS`                                 | Leaderboard file, state                           |

## 6.2 Testing Strategy

### Per-Module Smoke Tests

Same approach as v1.2. For v1.3 specifically:

- **`tests/TEST_USR.ASM`** — `USER_LOAD`, then `USER_AUTH` with: (a) brand-new username, (b) existing username + correct password, (c) existing username + wrong password, then `USER_SAVE`. Verify by inspecting `USERS.DAT` hex.
- **`tests/test_jingle.asm`** — `GFX_INIT`, play `SND_TITLE_JINGLE`, `SND_WIN_JINGLE`, `SND_LOSE_JINGLE` in sequence with `INP_WAIT_KEY` between each.
- **`tests/test_login_flow.asm`** — minimal main that boots straight into `STATE_LOGIN`. Verify the full retry + register + bail flow.

### Integration Checkpoints (revised v1.3 timeline)

| Day | Checkpoint                                                             | Demo                                                                    |
| --- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| 1   | Hello world builds & runs                                              | `.EXE` prints "HELLO" and exits                                         |
| 2   | Graphics module works standalone                                       | Test main draws 1 sprite per tier, exits                                |
| 3   | Background loading works                                               | `GFX_LOAD_BG` renders TITLE.BIN visibly                                 |
| 4   | Audio + Input + File I/O standalone; **USER_AUTH passes** *(v1.3)*     | Audio plays; name read; leaderboard saves; user auth works              |
| 5   | **Title jingle integrated** *(v1.3)*                                   | Title screen plays jingle on entry                                      |
| 6   | **Login flow integrated** *(v1.3)*                                     | Title → Login → Mode → ... → game start with pre-filled P1              |
| 7   | Intro flow integrated (Title → Login → Mode → Name(×N) → Diff → Instr) | Walk through intro in both 1P and 2P                                    |
| 8   | Round + Judge integrated (1P first, then 2P)                           | Play a complete 1P game; then 2P                                        |
| 9   | End screen + leaderboard + **win/lose jingle** *(v1.3)*                | Full game end-to-end with both players persisted; jingle plays          |
| 10  | Bug bash                                                               | Cross-mode regressions, font-on-bg transparency, login retry edge cases |
| 11  | Polish + demo prep                                                     | —                                                                       |
| 12  | Buffer day                                                             | —                                                                       |
| 13  | Buffer day                                                             | —                                                                       |

### Common Bugs to Watch For (v1.3 additions)

- **Login retry counter not reset.** If `LOGIN_RETRIES` carries over between attempts (e.g., player bails to title, returns later), they get fewer retries. Make sure `SLR_RENDER`'s `MOV LOGIN_RETRIES, 0` runs on every entry to `SCR_LOGIN_RUN`. The skeleton above does this correctly.
- **`USERS.DAT` corruption from partial writes.** If a crash occurs mid-`USER_SAVE`, file may be truncated. Low impact in DOSBox (no real crashes). Fix would be write-to-temp-then-rename; out of scope for MVP.
- **Password buffer not zeroed between login attempts.** `PASSWORD_BUF` accumulates stale bytes if a retry happens. Fix: `INP_READ_PASSWORD` overwrites all `CX` bytes, so this is safe by construction. Confirm during code review.
- **`INP_READ_PASSWORD` accepting digits but `USER_AUTH` only comparing letters.** Both procs treat the password as opaque bytes — any uppercase letter or digit is fine. Ensure `INP_READ_PASSWORD`'s validator matches what `INP_READ_STRING` does (both allow A-Z, 0-9).
- **`SESSION_USER` not pre-filling in 1P mode.** If `SCR_MODE_RUN` forgets the `REP MOVSB`, Player 1's name shows as spaces. Test: log in as "AAA", pick 1P, verify end screen shows "PLAYER 1: AAA".
- **2P with skipped Player 1 in `SCR_NAME_RUN`.** The header should say "PLAYER 2" on entry, not "PLAYER 1". `SCR_NAME_RUN`'s existing header logic (`OR AL, AL / JNZ SNR_P2`) handles this correctly when `CURRENT_PLAYER=1` on entry. Verify.
- **Title jingle eats keypresses.** If user presses a key during the jingle, BIOS buffers it. When `INP_WAIT_KEY` runs after the jingle, it consumes that key, advances to `STATE_LOGIN`, and the next key the user presses goes into `USERNAME_BUF`. Mildly annoying but not broken — note in known limitations.
- **End jingle delays leaderboard.** Players who lose may see "GAME OVER" and want to look immediately. The 1.1sec lose-jingle delay is intentional drama; if it tests poorly with toddlers, shorten the jingle pattern in `DATA.ASM`.

## 6.3 Known Risks & Mitigations

| Risk                                                              | Likelihood    | Impact        | Mitigation                                                                                                    |
| ----------------------------------------------------------------- | ------------- | ------------- | ------------------------------------------------------------------------------------------------------------- |
| Font rendering forgets transparency, overlays go opaque on bg     | **High**      | **High**      | Code review the inner glyph loop. Test on a non-black background BEFORE integrating with other screens.       |
| Spriter can't deliver 30 sprites + 8 backgrounds                  | **High**      | **High**      | Fallback: LOGIN.BIN reuses NAME.BIN; 4 unique backgrounds total. Drop sprite count to 6-8 per tier.           |
| `USERS.DAT` issues — missing file, partial write, format mismatch | Low           | Medium        | `USER_LOAD` silently handles missing file. Manual wipe between major version tests. *(v1.3)*                  |
| Login retry edge cases (counter reset, bail behavior)             | Medium        | Medium        | `TEST_USR` smoke test should cover all 4 USER_AUTH return paths. Day 6 integration test covers bail. *(v1.3)* |
| Background `.BIN` missing at runtime                              | Medium        | Medium        | Add a "missing file" log in `GFX_LOAD_BG` error path. Visual-test all screens Day 5.                          |
| Player array index bugs                                           | Medium        | High          | Standardize indexing; code review every use.                                                                  |
| Jingle blocks too long, users complain                            | Low           | Low           | Shorten patterns in `DATA.ASM` — pure data change, no code touch. *(v1.3)*                                    |
| 2P "game ends when either player out of hearts" feels unfair      | Medium        | Low           | Documented limitation.                                                                                        |
| Audio doesn't play in DOSBox                                      | Low           | High          | Check `pcspeaker=true` in `dosbox.conf`. Test Day 2.                                                          |
| Teammate flakes                                                   | Medium        | Medium        | v1.3 further increased Dev 1 + Dev 3 load. If Dev 3 drops, defer **login** (v1.3 only removable feature).     |
| Scope creep                                                       | **Very High** | **Very High** | **Strict freeze after v1.3.** No more features. `POLISH_IDEAS.txt` only.                                      |
| Data segment overflow                                             | Low           | Critical      | ~33.5KB total — still safe.                                                                                   |
| Integration day reveals misaligned contracts                      | High          | Medium        | Standups Days 2, 4, 6, 9. Each dev demos.                                                                     |
| Background music sneak-in attempt by enthusiastic teammate        | Low           | High          | Per Chapter 1.6 design decision — explicitly rejected. Direct to `POLISH_IDEAS.txt`. *(v1.3)*                 |

---

# Appendices

## A. TASM Cheatsheet

Unchanged.

## B. Interrupt Quick Reference

Unchanged from v1.1, but note that `INT 21h AH=3Ch/3Dh/3Eh/3Fh/40h` is now used by `GFX_LOAD_BG`, `FILEIO` leaderboard procs, and `FILEIO` user-account procs (v1.3).

## C. Glossary

Unchanged.

---

# 🛑 Document Status

**Version:** 1.4 — Scrambled letter hint
**Date of change:** 2026-05-13
**Author of revision:** Dev 1 (lead), in consultation with professor

**Changes from v1.3 → v1.4:**

1. **Scrambled letter hint added to gameplay.** During each round, alongside the sprite and sound cue, the player sees a jumbled-letter hint (e.g., `APPLE` → `PLEPA`). The hint is displayed once per round and stays visible for both players in 2P mode.
2. **New data structure `SCRAMBLE_TABLE` in `DATA.ASM`.** Parallel to `SPRITE_TABLE` and `SOUND_TABLE` — same global word index (`DIFFICULTY * 10 + CURRENT_WORD`). 30 entries × 16 bytes (`WORD_RECORD_SIZE`) = 480 bytes. Each entry is a null-terminated uppercase string, length-matched to the original word.
3. **New string `STR_HINT` in `DATA.ASM`** — the literal `'HINT: '` label rendered before the scramble.
4. **Hardcoded, not runtime-randomized.** Avoids an RNG dependency and guarantees scramble quality (distinct from original, length-matched, ideally not a real word). 480 bytes is a trivial cost.
5. **`SCR_ROUND_RUN` adds two `GFX_DRAW_STRING` calls** (label + scramble) plus the index-math required to resolve the scramble pointer. ~10 instructions inserted between the existing sprite draw and player loop. No timing or state changes.
6. **`SCR_JUDGE_RUN` is unchanged.** Spelling is still compared to the real word in `TIER_TABLE`; the scramble is read-only display.
7. **`ROUND.BIN` background needs a reserved blank area** around `(x=120, y=95)` for the hint to render cleanly. Spriter coordination required.
8. **Spriter / word-list owner adds 30 scramble strings** to `DATA.ASM`. ~1 hour of content work.
9. **No new `.ASM` files. No new states. No `SHARED.INC` changes.** Pure data + a few render lines. `WORD_RECORD_SIZE=16` is reused for `SCRAMBLE_TABLE` stride; no new size constant needed.
10. **Data segment up ~490B** (480B `SCRAMBLE_TABLE` + ~10B `STR_HINT`). Total ~34 KB, well under 64 KB.
11. **Timeline:** No meaningful shift. Dev 1 ~+0.5h for the `SCR_ROUND_RUN` insert. Spriter ~+1h for scramble strings. Absorbed without buffer impact.

**Changes from v1.2 → v1.3:**

1. **Login screen added.** New `STATE_LOGIN = 1` between `STATE_TITLE` and `STATE_MODE`. New `SCR_LOGIN_RUN` in `SCR_INTRO.ASM` handles username (3 chars) + password (5 chars) entry, authenticates against `USERS.DAT`, with auto-register for new usernames and 3-retry limit on wrong passwords.
2. **State machine renumbered.** All states from `STATE_MODE` onward shift up by 1. `STATE_QUIT` is now 9. Named constants mean only `SHARED.INC` needs literal updates.
3. **`USERS.DAT` file added.** 5 records × 8 bytes = 40 bytes. Format: name(3) + password(5). Created on first launch if absent. Stored alongside `SCORES.DAT` in `bin/`.
4. **New `FILEIO.ASM` procedures:** `USER_LOAD` (called once at boot), `USER_AUTH` (4 return codes: OK / new-user / wrong-pw / table-full), `USER_SAVE` (writes `USER_TABLE` to disk).
5. **New `INPUT.ASM` procedure:** `INP_READ_PASSWORD` — fixed-length, echoes `*` instead of typed character. Validator accepts A-Z and 0-9. No null terminator.
6. **Logged-in user pre-fills Player 1.** `SCR_MODE_RUN` copies `SESSION_USER` into `PLAYER_NAMES[0]` after mode selection. In 1P mode, name entry is skipped entirely. In 2P mode, `SCR_NAME_RUN` enters with `CURRENT_PLAYER=1`, prompting only for Player 2.
7. **Title jingle.** `SND_TITLE_JINGLE` pattern (C-E-G-C ascending arpeggio, ~750ms) plays in `SCR_TITLE_RUN` before `INP_WAIT_KEY`. Uses existing `SND_PLAY_PATTERN` — no new audio code.
8. **End jingles.** `SND_WIN_JINGLE` and `SND_LOSE_JINGLE` play at start of `SCR_END_RUN`. Selection by checking `HEARTS_ARR[]` for any zero. ~880-1100ms.
9. **Background music explicitly rejected.** Decision documented in Chapter 1.6 with rationale (PC speaker monophonic; would require ISR; conflicts with word sound cues).
10. **New runtime state in `MAIN.ASM`:** `SESSION_USER` (3B), `USER_TABLE` (40B), `USER_COUNT` (1B), `LOGIN_RETRIES` (1B), `USERNAME_BUF` (3B), `PASSWORD_BUF` (5B). All exported via `PUBLIC`.
11. **New strings in `DATA.ASM`:** `STR_LOGIN`, `STR_USERNAME`, `STR_PASSWORD`, `STR_WELCOME`, `STR_NEW_USER`, `STR_WRONG_PW`, `STR_USERS_FULL`. New filename strings: `BG_LOGIN`, `FN_USERS`.
12. **New SHARED.INC constants:** `MAX_USERS=5`, `USER_RECORD_SIZE=8`, `USERNAME_LEN=3`, `PASSWORD_LEN=5`, `MAX_LOGIN_RETRIES=3`. State EQUs renumbered.
13. **Spriter scope:** +1 background (LOGIN.BIN). +2-3 hours. Total now ~26-30 hours.
14. **Timeline:** 10 days → 13 days. Dev 1 +2h, Dev 2 +1h, Dev 3 +3h. 3-week buffer still absorbs.
15. **No new `.ASM` files.** All v1.3 additions go into existing modules. `BUILD.BAT` structure unchanged; recommended addition is a `TEST_USR` smoke-test entry.

**Ready for:** Implementation Day 1 (or current day if mid-sprint)
**Pending:** Study Guide update — see `STUDY_GUIDE.md`

**Update this doc when:**

- A module's procedure signature changes
- A new screen or state is added
- Memory layout changes
- Team assignments shift
