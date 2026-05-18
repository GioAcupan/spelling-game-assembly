;---------------------------------------------------------------
; TEST_BG.ASM — Preview a background image in VGA Mode 13h
; Uses GFX_INIT, GFX_LOAD_BG, and GFX_SHUTDOWN from GFX.ASM.
;---------------------------------------------------------------
.MODEL SMALL
.STACK 100h

.DATA
    BG_FILE DB 'welcome.bin', 0
    MSG_ERR DB 'Error loading background image.', 13, 10, '$'

.CODE
    EXTRN GFX_INIT:PROC, GFX_SHUTDOWN:PROC, GFX_LOAD_BG:PROC

START:
    MOV  AX, @DATA
    MOV  DS, AX

    ; Initialize graphics (Mode 13h + Palette)
    CALL GFX_INIT

    ; Load background into VGA memory (A000:0000)
    ; GFX_LOAD_BG expects DS:DX to point to filename
    LEA  DX, BG_FILE
    CALL GFX_LOAD_BG
    JNC  LB_OK

    ; Error: shutdown graphics and print message
    CALL GFX_SHUTDOWN
    MOV  AX, @DATA
    MOV  DS, AX
    LEA  DX, MSG_ERR
    MOV  AH, 09h
    INT  21h
    JMP  LB_EXIT

LB_OK:
    ; Wait for keypress
    MOV  AH, 00h
    INT  16h
    CALL GFX_SHUTDOWN

LB_EXIT:
    ; Exit to DOS
    MOV  AX, 4C00h
    INT  21h

END START
