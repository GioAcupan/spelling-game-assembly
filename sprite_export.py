#!/usr/bin/env python3
"""
sprite_export.py  --  PNG sprites -> TASM DB declarations for DATA.ASM
Requires: pip install Pillow

Usage:
  python sprite_export.py assets/sprites vga256.gpl assets/sprite_bytes.txt
"""

import sys
from pathlib import Path
from PIL import Image

# Must match SHARED.INC
SPRITE_W    = 32
SPRITE_H    = 32
SPRITE_SIZE = SPRITE_W * SPRITE_H  # 1024

# ORDER must match DATA.ASM exactly
EASY_WORDS   = ["CAT","DOG","EGG","SUN","HAT","BAG","CUP","PIG","HEN","ANT"]
MEDIUM_WORDS = ["APPLE","GRAPE","TRAIN","CHAIR","CLOCK","BREAD",
                "TIGER","HORSE","CLOUD","PLANT"]
HARD_WORDS   = ["ORANGE","SCHOOL","BRIDGE","CHICKEN","RAINBOW","PENGUIN",
                "BLANKET","THUNDER","LANTERN","DOLPHIN"]

TIERS = [
    ("easy",   "Easy",   EASY_WORDS,   "0-9"),
    ("medium", "Medium", MEDIUM_WORDS, "10-19"),
    ("hard",   "Hard",   HARD_WORDS,   "20-29"),
]

# ---- Palette loading ---------------------------------------------------------

def load_gpl(path):
    """GIMP .gpl -> list of (R,G,B), 256 entries."""
    palette = []
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith('#'):
                continue
            if any(s.upper().startswith(k) for k in ('GIMP','NAME','COLUMNS')):
                continue
            parts = s.split()
            if len(parts) >= 3:
                try:
                    palette.append((int(parts[0]), int(parts[1]), int(parts[2])))
                except ValueError:
                    pass
    if len(palette) != 256:
        print(f"  WARNING: {len(palette)} palette entries (expected 256)")
    return palette

# ---- Nearest-color match (cached) -------------------------------------------

_lut = {}

def nearest(r, g, b, palette):
    key = (r, g, b)
    if key in _lut:
        return _lut[key]
    best_i, best_d = 0, float('inf')
    for i, (pr, pg, pb) in enumerate(palette):
        d = (r-pr)**2 + (g-pg)**2 + (b-pb)**2
        if d < best_d:
            best_d, best_i = d, i
            if d == 0:
                break
    _lut[key] = best_i
    return best_i

# ---- PNG -> index list -------------------------------------------------------

def png_to_indices(path, palette):
    img = Image.open(path)

    # Fast path: already an indexed 32x32 PNG (GIMP indexed-mode export)
    if img.mode == 'P' and img.size == (SPRITE_W, SPRITE_H):
        pixels = list(img.getdata())
        trans = img.info.get('transparency', None)
        if trans is not None:
            pixels = [255 if p == trans else p for p in pixels]
        return pixels

    # General path: RGBA nearest-color match
    img = img.convert('RGBA')
    if img.size != (SPRITE_W, SPRITE_H):
        raise ValueError(f"Need 32x32, got {img.size} -- resize first")
    result = []
    for (r, g, b, a) in img.getdata():
        result.append(255 if a < 128 else nearest(r, g, b, palette))
    return result

# ---- Formatting -------------------------------------------------------------

def sprite_lines(indices, word, fname):
    # 8 values per DB line — works around TASM 4.1 parser limit on long
    # operand lists in large .DATA segments. See .claude/bugs/BUG-2026-05-09-TASM4-parse-limit.md
    out = [f"    ; {word}  ({fname})"]
    for row in range(32):
        chunk = indices[row*32 : row*32+32]
        for i in range(0, 32, 8):
            out.append("    DB " + ",".join(str(b) for b in chunk[i:i+8]))
    return out

def placeholder(word):
    return [
        f"    ; {word}  *** MISSING -- zeros ***",
        f"    DB {SPRITE_SIZE} DUP(0)",
    ]

# ---- Per-tier processing ----------------------------------------------------

def process_tier(root, sub, label, words, idx_range, palette):
    d = Path(root) / sub
    out = ["", f"    ; {'='*58}", f"    ; {label} ({idx_range})", f"    ; {'='*58}"]

    if not d.exists():
        print(f"  ERROR: missing directory: {d}")
        for w in words: out += placeholder(w)
        return out

    files = sorted(d.glob("*.png"))
    if len(files) != len(words):
        print(f"  WARNING [{label}]: {len(files)} PNGs, expected {len(words)}")

    fmap = dict(enumerate(files))
    for i, word in enumerate(words):
        f = fmap.get(i)
        if f is None:
            print(f"  MISSING  [{label}] {i} {word}")
            out += placeholder(word)
        else:
            try:
                idx = png_to_indices(f, palette)
                out += sprite_lines(idx, word, f.name)
                print(f"  OK  [{label}] {i:2d} {word:10s}  <- {f.name}")
            except Exception as e:
                print(f"  ERROR [{label}] {i} {word}: {e}")
                out += placeholder(word)
    return out

# ---- Validation -------------------------------------------------------------

def validate(lines):
    total = 0
    for line in lines:
        s = line.strip()
        if not s.startswith("DB"): continue
        p = s[2:].strip()
        total += int(p.split()[0]) if "DUP(" in p else len(p.split(","))
    exp = 30 * SPRITE_SIZE
    status = "OK" if total == exp else "MISMATCH"
    print(f"\nByte count {status}: {total} / {exp} expected")

# ---- Entry ------------------------------------------------------------------

def main():
    if len(sys.argv) != 4:
        print(__doc__); sys.exit(1)

    sprites_dir, gpl, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    print(f"Loading palette: {gpl}")
    palette = load_gpl(gpl)
    print(f"  {len(palette)} entries\n")

    header = [
        "; sprite_bytes.txt -- AUTO-GENERATED by sprite_export.py",
        "; Paste from SPRITE_TABLE: down, replacing all DUP(?) lines in DATA.ASM",
        "; Color 255 = transparent  |  global_index = DIFFICULTY*10 + CURRENT_WORD",
        "", "SPRITE_TABLE:",
    ]
    lines = list(header)
    for (sub, label, words, ir) in TIERS:
        lines += process_tier(sprites_dir, sub, label, words, ir, palette)
    lines.append("")

    with open(out_path, 'w') as f:
        f.write("\n".join(lines) + "\n")

    validate(lines)
    print(f"\nDone: {out_path}")

if __name__ == "__main__":
    main()