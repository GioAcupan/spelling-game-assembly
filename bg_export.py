#!/usr/bin/env python3
"""
bg_export.py  --  PNG -> raw binary (320x200) for VGA Mode 13h
Provides detailed color matching statistics.
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

def convert_bg(img_path, palette_path, out_path):
    print(f"Loading palette: {palette_path}")
    palette = load_gpl(palette_path)
    
    print(f"Processing image: {img_path}")
    img = Image.open(img_path)
    if img.size != (WIDTH, HEIGHT):
        print(f"Warning: Image size is {img.size}, expected ({WIDTH}, {HEIGHT}). Resizing...")
        img = img.resize((WIDTH, HEIGHT))
    
    img = img.convert('RGB')
    pixels = list(img.getdata())
    unique_colors = set(pixels)
    
    print(f"Unique colors in PNG: {len(unique_colors)}")
    
    # Map colors
    color_map = {}
    exact_count = 0
    nearest_count = 0
    
    palette_set = set(palette)
    
    for color in unique_colors:
        if color in palette_set:
            # Exact match
            color_map[color] = palette.index(color)
            exact_count += 1
        else:
            # Nearest match
            r, g, b = color
            best_i, best_d = 0, float('inf')
            for i, (pr, pg, pb) in enumerate(palette):
                d = (r-pr)**2 + (g-pg)**2 + (b-pb)**2
                if d < best_d:
                    best_d, best_i = d, i
                    if d == 0: break
            color_map[color] = best_i
            nearest_count += 1
            
    print(f"Unique colors matching palette exactly: {exact_count}")
    print(f"Unique colors requiring nearest match:  {nearest_count}")
    
    # Convert pixels
    indices = [color_map[p] for p in pixels]
    
    with open(out_path, 'wb') as f:
        f.write(bytes(indices))
    print(f"Saved binary to: {out_path}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python bg_export.py <image.png> <palette.gpl> <output.bin>")
        sys.exit(1)
    convert_bg(sys.argv[1], sys.argv[2], sys.argv[3])
