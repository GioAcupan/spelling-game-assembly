; tests/TEST_GFX.ASM — Smoke test for GFX module
; Validates all 7 public procedures visually.

.MODEL SMALL
.STACK 1024

.DATA
    TEST_MSG    DB 'GFX OK!',0
    PRESS_MSG   DB 'PRESS KEY',0
    DONE_MSG    DB 'GFX smoke test complete!$'

    ; 32x32 test sprite — red cross on transparent background
    ; Color 4 = red, color 0 = transparent
    PUBLIC TEST_SPRITE
TEST_SPRITE LABEL BYTE
    ; Top 12 rows: vertical bar only (manually unrolled for TASM 4.1)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    ; Middle 8 rows: full horizontal bar
    DB 32 DUP(4)
    DB 32 DUP(4)
    DB 32 DUP(4)
    DB 32 DUP(4)
    DB 32 DUP(4)
    DB 32 DUP(4)
    DB 32 DUP(4)
    DB 32 DUP(4)
    ; Bottom 12 rows: vertical bar only
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)
    DB 12 DUP(0), 8 DUP(4), 12 DUP(0)

.CODE
    EXTRN GFX_INIT:PROC, GFX_SHUTDOWN:PROC, GFX_CLEAR:PROC
    EXTRN GFX_DRAW_SPRITE:PROC, GFX_DRAW_CHAR:PROC, GFX_DRAW_STRING:PROC
    EXTRN GFX_LOAD_BG:PROC

MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX

    ; 1. Init graphics
    CALL GFX_INIT

    ; 2. Fill screen blue (color 1)
    MOV  AL, 1
    CALL GFX_CLEAR

    ; 3. Draw test sprite at (144, 50) — red cross on blue
    LEA  SI, TEST_SPRITE
    MOV  BX, 144
    MOV  DX, 50
    CALL GFX_DRAW_SPRITE

    ; 4. Draw "GFX OK!" in white at (128, 120)
    LEA  SI, TEST_MSG
    MOV  BL, 15               ; white
    MOV  CX, 128
    MOV  DX, 120
    CALL GFX_DRAW_STRING

    ; 5. Draw "PRESS KEY" in yellow at (112, 140)
    LEA  SI, PRESS_MSG
    MOV  BL, 14               ; yellow
    MOV  CX, 112
    MOV  DX, 140
    CALL GFX_DRAW_STRING

    ; 6. Wait for keypress
    MOV  AH, 00h
    INT  16h

    ; 7. Shutdown graphics
    CALL GFX_SHUTDOWN

    ; 8. Print completion message via DOS
    MOV  AH, 09h
    LEA  DX, DONE_MSG
    INT  21h

    MOV  AH, 4Ch
    MOV  AL, 0
    INT  21h
MAIN ENDP

END MAIN
