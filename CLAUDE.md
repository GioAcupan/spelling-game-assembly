# Spelling Game — 8086 Assembly

Educational toddler spelling game for Intel 8086 real mode via DOSBox.
Full design spec: `@docs/SPEC.md` (chapters are authoritative — reference by section number).

**GitNexus required:** Run `gitnexus_impact` before editing any symbol. Run `gitnexus_detect_changes` before committing. See GitNexus section below for details.

## Toolchain — DO NOT DEVIATE

- **Assembler:** TASM 4.1 (Borland Turbo Assembler, 1996) — **NOT MASM, NOT NASM, NOT TASM 5.x**
- **Linker:** TLINK
- **Runtime:** DOSBox (16-bit real mode, 8086)
- **Memory model:** `.MODEL SMALL` (one 64KB code seg + one 64KB data seg)
- **Graphics:** VGA Mode 13h (320×200, 256 colors, framebuffer at A000h)
- **Audio:** PC speaker via ports 42h/43h/61h (NOT Sound Blaster)

If a snippet uses `BITS 16`, `section .data`, `global`, or `extern` — it's NASM, it's wrong. TASM uses `.MODEL SMALL`, `.DATA`, `.CODE`, `PUBLIC`, `EXTRN`.

## Project layout

```
src/      — module .ASM source
tests/    — per-module standalone smoke-test mains
BUILD.BAT — TASM + TLINK pipeline (run from project root)
CLEAN.BAT — delete build artifacts (run from project root)
build/    — .OBJ output (gitignored)
bin/      — final .EXE (gitignored)
docs/     — full design spec, study notes
```

**DOS 8.3 filename limit:** All `.ASM` filenames must fit DOS 8.3 (max 8-char name + 3-char extension). Files like `test_STATE.asm` (10 chars) are invisible inside DOSBox. Use short names like `TEST_ST.ASM`, `TEST_GFX.ASM`. Check every new filename before creation.

Build runs **inside DOSBox**, not on the host. Workflow: edit on host → switch to DOSBox → `BUILD.BAT` → `bin\SPELL.EXE` → iterate.

**Claude Code cannot run TASM or DOSBox.** When the user pastes build errors, treat them as ground truth — don't guess at what the assembler "probably" meant.

## Build (inside DOSBox)

```
BUILD.BAT              → assemble + link all modules → bin\SPELL.EXE
BUILD.BAT test_GFX     → assemble + link one smoke test → bin\TEST_GFX.EXE
CLEAN.BAT              → delete build\*.OBJ, bin\*.EXE
```

BUILD.BAT runs `TASM` for each `.ASM` then `TLINK` to produce the `.EXE`. Smoke tests produce `bin\TEST_<NAME>.EXE` — the naming convention is `tests\test_<MODULE>.asm` → `bin\TEST_<MODULE>.EXE`.

**All TASM calls must include `/isrc`** (no space — TASM concatenates the include path to the `/i` switch; this is the form documented in the TASM 4.1 manual) so `INCLUDE SHARED.INC` resolves. BUILD.BAT and CLEAN.BAT live at the project root (not inside `build/`), and all paths in them are relative to the project root.

When adding a new `.ASM` file, add it to BUILD.BAT's TASM calls **and** TLINK line. When a module is incomplete and its smoke test hasn't passed, do NOT add it to the main `SPELL.EXE` link line.

## Hard rules (from spec Chapter 6.2 bug list)

1. **Set DS at every module entry.** Always `MOV AX, @DATA / MOV DS, AX` before touching `.DATA`.
2. **Preserve registers across calls.** Every PROC has a header comment listing `Preserves:` — push at entry, pop at exit, in mirrored order. Anything declared as "output" is the only register allowed to change.
3. **Track ES carefully.** Sprite routines need `ES = A000h`. File routines (INT 21h) need `DS:DX = filename`. Annotate which segment register holds what at every non-trivial juncture.
4. **Signed vs unsigned jumps.** `JG/JL` are signed; `JA/JB` are unsigned. Counts/sizes/indices are unsigned.
5. **ASCII uppercase only** for character comparisons. Toddler input is force-uppered.
6. **Sprite math.** `SPRITE_SIZE EQU 1024` (32×32). Global sprite index = `DIFFICULTY * 10 + CURRENT_WORD`. Don't confuse tier-local with global.
7. **TIER_TABLE indexing requires `SHL AX, 1`** (entries are word-sized pointers). Skipping the shift gives the wrong tier — silent bug.

## Module ownership

| File            | Owner           | Public exports                                                              |
| --------------- | --------------- | --------------------------------------------------------------------------- |
| `MAIN.ASM`      | Dev 1           | (entry point)                                                               |
| `STATE.ASM`     | Dev 1           | `GAME_TICK`                                                                 |
| `DATA.ASM`      | spriter + Dev 1 | `EASY_WORDS`, `MED_WORDS`, `HARD_WORDS`, `SPRITE_TABLE`, `SOUND_TABLE`      |
| `GFX.ASM`       | Dev 2           | `GFX_INIT`, `GFX_CLEAR`, `GFX_DRAW_SPRITE`, `GFX_DRAW_TEXT`, `GFX_SHUTDOWN` |
| `INPUT.ASM`     | Dev 2           | `INP_WAIT_KEY`, `INP_CHECK_KEY`, `INP_READ_STRING`                          |
| `AUDIO.ASM`     | Dev 3           | `SND_PLAY_PATTERN`, `SND_SILENCE`                                           |
| `FILEIO.ASM`    | Dev 3           | `FILE_LOAD_SCORES`, `FILE_SAVE_SCORES`                                      |
| `SCR_INTRO.ASM` | Dev 1           | `SCR_TITLE_RUN`, `SCR_NAME_RUN`, `SCR_DIFF_RUN`, `SCR_INSTR_RUN`            |
| `SCR_GAME.ASM`  | Dev 1           | `SCR_ROUND_RUN`, `SCR_JUDGE_RUN`                                            |
| `SCR_END.ASM`   | Dev 1           | `SCR_END_RUN`                                                               |
| `SHARED.INC`    | Dev 1           | EQU constants, EXTRN declarations                                           |

Detailed per-module specs in `@docs/SPEC.md` chapters 3–5.

## Slash Commands

- **`/module <NAME>`** — Plan-then-execute workflow for a single module (e.g. `/module GFX`). Reads the spec, produces a plan, waits for approval, implements smoke test first, then the module.
- **`/build-error`** — Paste a TASM/TLINK error after this command. Diagnoses methodically: classify → localize → apply tasm-conventions checklist → propose one concrete fix. No speculative shotgun fixes.

## Available Skills & Subagents

**Skills** (invoked automatically by description match, or explicitly via `/skill-name`):

| Skill | Purpose |
|---|---|
| `tasm-conventions` | Auto-applied on any `.ASM` work — TASM syntax, PROC conventions, segment reg rules, bug checklist |
| `debug-asm` | Trace registers, flags, memory, and DOS interrupt assumptions for a bug |
| `explain-asm` | Line-by-line explanation of TASM code in register/memory/DOS terms |
| `implement-asm` | Safe implementation of a TASM routine or program |
| `review-asm` | Review for correctness, 8086 compatibility, and assignment safety |
| `create-pr` | Create a pull request |

**Subagents** (use the Agent tool):

| Agent | Purpose |
|---|---|
| `code-reviewer-8086` | Reviews 8086/TASM assembly for correctness, DOS interrupts, register safety |
| `debugger-8086` | Traces registers, flags, memory, and DOS interrupt assumptions |
| `integration-checker` | Verifies PUBLIC/EXTRN matching, register conventions, segment register handoff across modules. **Run before Day 5 integration.** Reports only — doesn't modify files. |
| `test-designer-8086` | Designs manual test cases for 8086/TASM programs |

**`integration-checker` is critical.** Run it after editing 2+ modules or before attempting a full build link. Fix all `[BLOCKER]` findings before running BUILD.BAT.

## Workflow expectations

- **Plan Mode for every module.** Read the relevant spec chapter, propose a plan, get approval, then code. Use `/module <NAME>` to start.
- **Smoke test before integration.** Each module has a standalone test main in `tests/` that exercises only its public procs. Build & run that before declaring the module done.
- **One module per Claude Code session.** Run `/clear` between unrelated modules — context bloat degrades instruction-following.
- **Update BUILD.BAT only when adding a new .ASM file.** No silent changes to the link line.
- **Commit after each smoke test passes.** Small commits make Day 5 integration tractable.
- If debugging, **first explain the likely fault(s)** in terms of registers, memory, flags, or DOS API usage.
- After writing code, do a static review for 8086/TASM compatibility.
- End with a compact explanation of the register/data flow.

**PreToolUse guard:** `settings.json` has a hook that runs `.claude/scripts/check_asm_write.py` on every `Edit`/`Write` to an `.ASM` file. It blocks non-8086 instructions (`pushad`, `cmov*`, `enter`, `leave`) and 32-bit registers (`eax`, `ebx`, etc.) before they reach the file. If a write is rejected, the code you tried to write contains a forbidden instruction or register — fix it on your side, don't modify the guard script.

## Review checklist

Always verify:

1. 8086 instruction compatibility.
2. Correct segment initialization where needed.
3. Correct DOS interrupt usage.
4. Register preservation assumptions.
5. Edge cases for signed/unsigned arithmetic.
6. Loop termination and off-by-one errors.
7. String terminators and buffer lengths.
8. Whether the solution matches TASM syntax rather than MASM/NASM-specific syntax.

## NOT in scope (push back if asked)

- Sound Blaster / DAC audio
- More than 30 sprites total (10 per tier × 3 tiers)
- 32-bit / protected mode / DPMI
- Any feature not in the spec until Day 5+ — log "wouldn't it be cool" ideas to `POLISH_IDEAS.txt` and revisit only after MVP integration is green.

## Status (update this file)

- [ ] Day 1 — repo skeleton + hello-world MAIN.ASM builds and prints HELLO
- [ ] Day 2 — GFX standalone (1 sprite from each tier renders)
- [ ] Day 3 — AUDIO standalone (one pattern plays in DOSBox)
- [ ] Day 4 — INPUT + FILEIO standalone (name read, scores persist across runs)
- [ ] Day 5 — full integration: title → name → diff → instr → round → end (playable)
- [ ] Day 6 — bug-fix pass on Day 5 findings; all 3 tiers complete without crash
- [ ] Day 7 — polish + demo prep

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **spelling-game** (263 symbols, 268 relationships, 3 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/spelling-game/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/spelling-game/context` | Codebase overview, check index freshness |
| `gitnexus://repo/spelling-game/clusters` | All functional areas |
| `gitnexus://repo/spelling-game/processes` | All execution flows |
| `gitnexus://repo/spelling-game/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
