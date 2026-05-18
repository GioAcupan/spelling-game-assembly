# Background Previewer System

This system allows for converting PNG images into the project's indexed binary format and previewing them in VGA Mode 13h.

## Files Created/Modified

### New Files
- `bg_export.py`: Python script to convert 320x200 PNGs to indexed binary data.
- `tests/TEST_BG.ASM`: Assembly test harness to display converted backgrounds.
- `welcome.bin`: Binary data for the sample welcome page (moved to `bin/`).

### Modified Files
- `src/GFX.ASM`: Improved error propagation in `GFX_LOAD_BG`.
- `BUILD.BAT`: Added `TEST_BG` target for the build pipeline.

## How to Use

### 1. Convert an Image
Use the Python script to convert a 320x200 PNG using the project palette.
```powershell
python bg_export.py your_image.png assets/vga256.gpl your_image.bin
```
The script will report color matching statistics (exact vs. nearest neighbor).

### 2. Build the Previewer
Assemble and link the test harness inside DOSBox:
```batch
BUILD.BAT TEST_BG
```
This produces `bin\TEST_BG.EXE` and ensures `welcome.bin` is available in the `bin/` directory.

### 3. Run the Preview
Run the executable from the `bin/` directory in DOSBox:
```batch
cd bin
TEST_BG.EXE
```
Press any key to exit the preview and return to text mode.

## Troubleshooting
- **Black Screen:** Ensure the `.bin` file is in the same directory as the `.EXE`.
- **"Error loading..."**: The program failed to open or read the file. Check if the filename in `TEST_BG.ASM` matches your binary file.
- **Wrong Colors:** Ensure you used `assets/vga256.gpl` during conversion.
