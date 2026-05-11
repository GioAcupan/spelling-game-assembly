# Claude Code setup for the Spelling Game project

A focused, opinionated configuration for using Claude Code on the 8086 spelling-game project. Six files, each with a clear job. Nothing speculative.

## What's in here

```
CLAUDE.md                                — Project context loaded into every session
.claude/
├── skills/
│   └── tasm-conventions/
│       └── SKILL.md                     — Auto-applied skill for any .ASM work
├── agents/
│   └── integration-checker.md           — Subagent for cross-module contract review
└── commands/
    ├── module.md                        — /module <NAME> — per-module workflow
    └── build-error.md                   — /build-error <pasted error> — diagnosis
```

## Installation

1. Copy `CLAUDE.md` to the **root** of your project repo (next to `BUILD.BAT`, `src/`, etc.).
2. Copy the entire `.claude/` directory to the project root as well.
3. Drop your existing `SPELLING_GAME_MVP_1_.md` into `docs/SPEC.md` (the references in CLAUDE.md and the slash commands assume that path).
4. Open the project in Claude Code (`claude` from the terminal in the project root).
5. First-time check: ask Claude something simple like *"What toolchain does this project use?"* — it should cite TASM 4.1 from your CLAUDE.md without searching. If it doesn't, your CLAUDE.md isn't being loaded; verify it's at the repo root.

## What each piece does and when it triggers

### `CLAUDE.md` — the foundation

Read at the start of every session. Contains the toolchain, hard rules, file ownership table, and a Day 1–7 status checklist. **Update the status checklist as you go** — it's a living document, and Claude reads it every session, so an out-of-date checklist will mislead it.

Why it's short (~100 lines): per the consensus on CLAUDE.md sizing, instruction-following degrades as the file grows. The full 2000-line spec belongs in `docs/SPEC.md` (referenced via `@docs/SPEC.md`), not pasted into CLAUDE.md.

### `tasm-conventions` skill — auto-applied

Whenever Claude writes or reviews assembly, this skill activates. It encodes:
- TASM ↔ NASM ↔ MASM translation table (catches the most common LLM failure mode)
- The PROC header convention this project uses
- Segment-register management rules
- The bug-pattern checklist from spec Chapter 6.2

You don't need to invoke it manually. Claude pulls it in based on its description.

### `integration-checker` subagent

Run this when you've edited two or more modules and are about to attempt linking, or on Day 5 before integration:

> "Use the integration-checker subagent on the current `src/` tree."

It reports findings only — won't modify files. Findings are tagged `[BLOCKER]`, `[WARN]`, `[INFO]`. Fix all blockers before running BUILD.BAT.

### `/module <NAME>` slash command

The command you'll use 10 times. Run it like:

```
/module GFX
```

It forces the plan-then-execute workflow: read spec → produce plan → wait for approval → implement (smoke test first, then module) → hand off to DOSBox → suggest commit.

Don't skip the plan step even if a module looks small. The 5 minutes you spend reviewing the plan are cheaper than any debugging cycle in DOSBox.

### `/build-error <pasted error>` slash command

When DOSBox spits out a TASM or TLINK error, paste the whole thing after the command:

```
/build-error
**Error** GFX.ASM(47): Undefined symbol: GFX_INIT
```

Claude classifies the error, localizes it, applies the tasm-conventions checklist, and proposes one concrete fix (or asks one clarifying question if genuinely ambiguous). Avoids the failure mode where Claude shotguns three speculative changes and you waste a full edit-build cycle on each.

## What I deliberately did NOT include

- **Hooks.** They require bash scripts that vary by host OS (Windows + DOSBox vs Mac vs Linux), and broken hooks are worse than no hooks. If you want one, the highest-value candidate is a `PostToolUse` hook on Edit that greps newly-written `.ASM` files for forbidden NASM idioms (`BITS`, `section`, `global`, `extern`) and yells if it finds them. A 10-line bash script. Add it later if the tasm-conventions skill isn't catching them.

- **More slash commands.** I considered `/smoketest`, `/sprite-import`, `/contract-check` (redundant with the subagent), and a few others. None of them appear often enough in your 1-week sprint to justify the maintenance cost. Add them if a workflow shows up three times.

- **A spriter-import skill.** Your spriter is exporting raw bytes that get pasted into `DATA.ASM`. The format is fixed and the operation happens once per sprite. Not worth a skill.

- **Subagents for each module owner.** Tempting (a "graphics-dev" agent, an "audio-dev" agent), but it splits context unhelpfully. Each developer running their own Claude Code session in their own branch is the same thing with less indirection.

## Per-developer workflow (recommended)

Each of your 3 devs runs Claude Code in their own session, on their own git branch:

| Dev | Branch | Modules | Sessions |
|---|---|---|---|
| 1 (lead) | `main` (integrates) | MAIN, STATE, SHARED, SCR_INTRO, SCR_GAME, SCR_END | One per module, `/clear` between |
| 2 | `dev2-gfx-input` | GFX, INPUT | One per module |
| 3 | `dev3-audio-fileio` | AUDIO, FILEIO | One per module |

Day 5 integration: lead pulls Dev 2 and Dev 3's branches, runs the integration-checker subagent, fixes blockers, attempts a full build, fixes link errors via `/build-error`. Standalone smoke tests should already pass on each branch before the merge.

## When to update this setup

- **`CLAUDE.md` status checklist** — every time you finish a day's checkpoint
- **`tasm-conventions` skill** — if you discover a new bug class that bit you twice (one-time bugs aren't worth codifying)
- **Slash commands** — if you find yourself typing the same prompt prefix three times, that's a candidate for a new command

Resist scope creep on the tooling itself. Ship the game first.
