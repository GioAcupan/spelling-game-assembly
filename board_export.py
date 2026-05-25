#!/usr/bin/env python3
"""
board_export.py  --  PNG -> raw binary (320x200) for VGA Mode 13h
Adapted from sprite_export.py
"""

import sys
from pathlib import Path
from PIL import Image

WIDTH  = 320
HEIGHT = 200
SIZE   = WIDTH * HEIGHT

def load_gpl(path):
    palette = []
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith('#'): continue
            if any(s.upper().startswith(k) for k in ('GIMP','NAME','COLUMNS')): continue
            parts = s.split()
            if len(parts) >= 3:
                try: palette.append((int(parts[0]), int(parts[1]), int(parts[2])))
                except ValueError: pass
    return palette

_lut = {}
exact_matches = 0
nearest_matches = 0

def nearest(r, g, b, palette):
    global exact_matches, nearest_matches
    key = (r, g, b)
    if key in _lut:
        return _lut[key]
    
    # Check for exact match
    for i, (pr, pg, pb) in enumerate(palette):
        if (r, g, b) == (pr, pg, pb):
            exact_matches += 1
            _lut[key] = i
            return i
            
    # Nearest match
    nearest_matches += 1
    best_i, best_d = 0, float('inf')
    for i, (pr, pg, pb) in enumerate(palette):
        d = (r-pr)**2 + (g-pg)**2 + (b-pb)**2
        if d < best_d:
            best_d, best_i = d, i
            if d == 0: break
    _lut[key] = best_i
    return best_i

def convert_board(img_path, palette_path, out_path):
    global exact_matches, nearest_matches
    print(f"Loading palette: {palette_path}")
    palette = load_gpl(palette_path)
    
    print(f"Processing image: {img_path}")
    img = Image.open(img_path)
    if img.size != (WIDTH, HEIGHT):
        print(f"Warning: Image size is {img.size}, expected ({WIDTH}, {HEIGHT}). Resizing...")
        img = img.resize((WIDTH, HEIGHT))
    
    img = img.convert('RGB')
    pixels = list(img.getdata())
    
    indices = []
    for r, g, b in pixels:
        indices.append(nearest(r, g, b, palette))
    
    print(f"Conversion complete.")
    print(f"Unique colors in image: {len(_lut)}")
    print(f"Pixels matched exactly: {exact_matches}")
    print(f"Pixels requiring nearest match: {nearest_matches}")
    
    with open(out_path, 'wb') as f:
        f.write(bytes(indices))
    print(f"Saved binary to: {out_path}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python board_export.py <image.png> <palette.gpl> <output.bin>")
        sys.exit(1)
    convert_board(sys.argv[1], sys.argv[2], sys.argv[3])
