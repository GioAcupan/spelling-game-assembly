; GFX.ASM — Mode 13h graphics + background loading
; Dev 2 module. Public: GFX_INIT, GFX_SHUTDOWN, GFX_CLEAR,
; GFX_DRAW_SPRITE, GFX_DRAW_CHAR, GFX_DRAW_STRING, GFX_LOAD_BG

.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    BG_HANDLE  DW 0

    ; 8x8 bitmap font — 40 glyphs, 8 bytes each
    ; Layout: space(1) !(1) .(1) 0-9(10) ?(1) A-Z(26)
    ; MSB = leftmost pixel, 0 = transparent
    PUBLIC FONT_TABLE
FONT_TABLE LABEL BYTE
    ; [0] space 0x20
    DB 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
    ; [1] ! 0x21
    DB 18h, 18h, 18h, 18h, 18h, 00h, 18h, 00h
    ; [2] . 0x2E
    DB 00h, 00h, 00h, 00h, 00h, 00h, 18h, 00h
    ; [3] 0 0x30
    DB 3Ch, 66h, 66h, 66h, 66h, 66h, 3Ch, 00h
    ; [4] 1 0x31
    DB 18h, 38h, 18h, 18h, 18h, 18h, 3Ch, 00h
    ; [5] 2 0x32
    DB 3Ch, 66h, 06h, 0Ch, 18h, 30h, 7Eh, 00h
    ; [6] 3 0x33
    DB 3Ch, 66h, 06h, 1Ch, 06h, 66h, 3Ch, 00h
    ; [7] 4 0x34
    DB 0Ch, 1Ch, 2Ch, 4Ch, 7Eh, 0Ch, 0Ch, 00h
    ; [8] 5 0x35
    DB 7Eh, 60h, 7Ch, 06h, 06h, 66h, 3Ch, 00h
    ; [9] 6 0x36
    DB 3Ch, 66h, 60h, 7Ch, 66h, 66h, 3Ch, 00h
    ; [10] 7 0x37
    DB 7Eh, 06h, 0Ch, 18h, 30h, 30h, 30h, 00h
    ; [11] 8 0x38
    DB 3Ch, 66h, 66h, 3Ch, 66h, 66h, 3Ch, 00h
    ; [12] 9 0x39
    DB 3Ch, 66h, 66h, 3Eh, 06h, 66h, 3Ch, 00h
    ; [13] ? 0x3F
    DB 3Ch, 66h, 06h, 0Ch, 18h, 00h, 18h, 00h
    ; [14] A 0x41
    DB 3Ch, 66h, 66h, 7Eh, 66h, 66h, 66h, 00h
    ; [15] B 0x42
    DB 7Ch, 66h, 66h, 7Ch, 66h, 66h, 7Ch, 00h
    ; [16] C 0x43
    DB 3Ch, 66h, 60h, 60h, 60h, 66h, 3Ch, 00h
    ; [17] D 0x44
    DB 78h, 6Ch, 66h, 66h, 66h, 6Ch, 78h, 00h
    ; [18] E 0x45
    DB 7Eh, 60h, 60h, 7Ch, 60h, 60h, 7Eh, 00h
    ; [19] F 0x46
    DB 7Eh, 60h, 60h, 7Ch, 60h, 60h, 60h, 00h
    ; [20] G 0x47
    DB 3Ch, 66h, 60h, 6Eh, 66h, 66h, 3Ch, 00h
    ; [21] H 0x48
    DB 66h, 66h, 66h, 7Eh, 66h, 66h, 66h, 00h
    ; [22] I 0x49
    DB 3Ch, 18h, 18h, 18h, 18h, 18h, 3Ch, 00h
    ; [23] J 0x4A
    DB 1Eh, 0Ch, 0Ch, 0Ch, 0Ch, 6Ch, 38h, 00h
    ; [24] K 0x4B
    DB 66h, 6Ch, 78h, 70h, 78h, 6Ch, 66h, 00h
    ; [25] L 0x4C
    DB 60h, 60h, 60h, 60h, 60h, 60h, 7Eh, 00h
    ; [26] M 0x4D
    DB 66h, 7Eh, 7Eh, 66h, 66h, 66h, 66h, 00h
    ; [27] N 0x4E
    DB 66h, 76h, 7Eh, 6Eh, 66h, 66h, 66h, 00h
    ; [28] O 0x4F
    DB 3Ch, 66h, 66h, 66h, 66h, 66h, 3Ch, 00h
    ; [29] P 0x50
    DB 7Ch, 66h, 66h, 7Ch, 60h, 60h, 60h, 00h
    ; [30] Q 0x51
    DB 3Ch, 66h, 66h, 66h, 6Ah, 6Ch, 36h, 00h
    ; [31] R 0x52
    DB 7Ch, 66h, 66h, 7Ch, 78h, 6Ch, 66h, 00h
    ; [32] S 0x53
    DB 3Ch, 66h, 60h, 3Ch, 06h, 66h, 3Ch, 00h
    ; [33] T 0x54
    DB 7Eh, 18h, 18h, 18h, 18h, 18h, 18h, 00h
    ; [34] U 0x55
    DB 66h, 66h, 66h, 66h, 66h, 66h, 3Ch, 00h
    ; [35] V 0x56
    DB 66h, 66h, 66h, 66h, 66h, 3Ch, 18h, 00h
    ; [36] W 0x57
    DB 66h, 66h, 66h, 66h, 7Eh, 7Eh, 66h, 00h
    ; [37] X 0x58
    DB 66h, 66h, 3Ch, 18h, 3Ch, 66h, 66h, 00h
    ; [38] Y 0x59
    DB 66h, 66h, 66h, 3Ch, 18h, 18h, 18h, 00h
    ; [39] Z 0x5A
    DB 7Eh, 06h, 0Ch, 18h, 30h, 60h, 7Eh, 00h

    ; VGA DAC palette — 256 colors x 3 bytes (R,G,B), 6-bit values 0-63
    ; Auto-converted from assets/vga256.gpl (8-bit RGB / 4)
    PUBLIC VGA_PALETTE
VGA_PALETTE LABEL BYTE
    DB 0,0,0,0,0,42,0,42
    DB 0,0,42,42,42,0,0,42
    DB 0,42,42,21,0,42,42,42
    DB 21,21,21,21,21,63,21,63
    DB 21,21,63,63,63,21,21,63
    DB 21,63,63,63,21,63,63,63
    DB 0,0,0,0,0,12,0,0
    DB 25,0,0,38,0,0,51,0
    DB 0,63,0,12,0,0,12,12
    DB 0,12,25,0,12,38,0,12
    DB 51,0,12,63,0,25,0,0
    DB 25,12,0,25,25,0,25,38
    DB 0,25,51,0,25,63,0,38
    DB 0,0,38,12,0,38,25,0
    DB 38,38,0,38,51,0,38,63
    DB 0,51,0,0,51,12,0,51
    DB 25,0,51,38,0,51,51,0
    DB 51,63,0,63,0,0,63,12
    DB 0,63,25,0,63,38,0,63
    DB 51,0,63,63,12,0,0,12
    DB 0,12,12,0,25,12,0,38
    DB 12,0,51,12,0,63,12,12
    DB 0,12,12,12,12,12,25,12
    DB 12,38,12,12,51,12,12,63
    DB 12,25,0,12,25,12,12,25
    DB 25,12,25,38,12,25,51,12
    DB 25,63,12,38,0,12,38,12
    DB 12,38,25,12,38,38,12,38
    DB 51,12,38,63,12,51,0,12
    DB 51,12,12,51,25,12,51,38
    DB 12,51,51,12,51,63,12,63
    DB 0,12,63,12,12,63,25,12
    DB 63,38,12,63,51,12,63,63
    DB 25,0,0,25,0,12,25,0
    DB 25,25,0,38,25,0,51,25
    DB 0,63,25,12,0,25,12,12
    DB 25,12,25,25,12,38,25,12
    DB 51,25,12,63,25,25,0,25
    DB 25,12,25,25,25,25,25,38
    DB 25,25,51,25,25,63,25,38
    DB 0,25,38,12,25,38,25,25
    DB 38,38,25,38,51,25,38,63
    DB 25,51,0,25,51,12,25,51
    DB 25,25,51,38,25,51,51,25
    DB 51,63,25,63,0,25,63,12
    DB 25,63,25,25,63,38,25,63
    DB 51,25,63,63,38,0,0,38
    DB 0,12,38,0,25,38,0,38
    DB 38,0,51,38,0,63,38,12
    DB 0,38,12,12,38,12,25,38
    DB 12,38,38,12,51,38,12,63
    DB 38,25,0,38,25,12,38,25
    DB 25,38,25,38,38,25,51,38
    DB 25,63,38,38,0,38,38,12
    DB 38,38,25,38,38,38,38,38
    DB 51,38,38,63,38,51,0,38
    DB 51,12,38,51,25,38,51,38
    DB 38,51,51,38,51,63,38,63
    DB 0,38,63,12,38,63,25,38
    DB 63,38,38,63,51,38,63,63
    DB 51,0,0,51,0,12,51,0
    DB 25,51,0,38,51,0,51,51
    DB 0,63,51,12,0,51,12,12
    DB 51,12,25,51,12,38,51,12
    DB 51,51,12,63,51,25,0,51
    DB 25,12,51,25,25,51,25,38
    DB 51,25,51,51,25,63,51,38
    DB 0,51,38,12,51,38,25,51
    DB 38,38,51,38,51,51,38,63
    DB 51,51,0,51,51,12,51,51
    DB 25,51,51,38,51,51,51,51
    DB 51,63,51,63,0,51,63,12
    DB 51,63,25,51,63,38,51,63
    DB 51,51,63,63,63,0,0,63
    DB 0,12,63,0,25,63,0,38
    DB 63,0,51,63,0,63,63,12
    DB 0,63,12,12,63,12,25,63
    DB 12,38,63,12,51,63,12,63
    DB 63,25,0,63,25,12,63,25
    DB 25,63,25,38,63,25,51,63
    DB 25,63,63,38,0,63,38,12
    DB 63,38,25,63,38,38,63,38
    DB 51,63,38,63,63,51,0,63
    DB 51,12,63,51,25,63,51,38
    DB 63,51,51,63,51,63,63,63
    DB 0,63,63,12,63,63,25,63
    DB 63,38,63,63,51,63,63,63
    DB 2,2,2,5,5,5,7,7
    DB 7,10,10,10,12,12,12,15
    DB 15,15,17,17,17,20,20,20
    DB 23,23,23,25,25,25,28,28
    DB 28,30,30,30,33,33,33,35
    DB 35,35,38,38,38,40,40,40
    DB 43,43,43,46,46,46,48,48
    DB 48,51,51,51,53,53,53,56
    DB 56,56,58,58,58,61,61,61

.CODE
    PUBLIC GFX_LOAD_PALETTE
    PUBLIC GFX_INIT, GFX_SHUTDOWN, GFX_CLEAR
    PUBLIC GFX_LOAD_BG
    PUBLIC GFX_DRAW_SPRITE, GFX_DRAW_CHAR, GFX_DRAW_STRING

;-----------------------------------------------------------
; CHAR_TO_INDEX — Map ASCII char to font glyph index.
; In:  AL = ASCII char
; Out: AX = glyph index (0-39), 0=space for unmapped chars
; Preserves: BX, CX, DX, SI, DI, BP, DS
; Clobbers: AX
;-----------------------------------------------------------
CHAR_TO_INDEX PROC
    CMP  AL, 20h
    JB   CTI_DEF          ; < space
    JE   CTI_DEF          ; space = index 0
    CMP  AL, 21h
    JE   CTI_01           ; !
    CMP  AL, 2Eh
    JE   CTI_02           ; .
    CMP  AL, 30h
    JB   CTI_DEF          ; 22h-2Dh → space
    CMP  AL, 39h
    JA   CTI_NOT_DIGIT
    SUB  AL, 30h-3        ; 0-9 → 3-12
    JMP  CTI_RET
CTI_NOT_DIGIT:
    CMP  AL, 3Fh
    JE   CTI_13           ; ?
    CMP  AL, 41h
    JB   CTI_DEF          ; 40h, @ etc → space
    CMP  AL, 5Ah
    JA   CTI_LCASE
    SUB  AL, 41h-14       ; A-Z → 14-39
    JMP  CTI_RET
CTI_LCASE:
    CMP  AL, 61h
    JB   CTI_DEF
    CMP  AL, 7Ah
    JA   CTI_DEF
    SUB  AL, 61h-14       ; a-z → 14-39
    JMP  CTI_RET
CTI_01: MOV AL, 1
    JMP  CTI_RET
CTI_02: MOV AL, 2
    JMP  CTI_RET
CTI_13: MOV AL, 13
    JMP  CTI_RET
CTI_DEF:XOR  AL, AL
CTI_RET:XOR  AH, AH
    RET
CHAR_TO_INDEX ENDP

;-----------------------------------------------------------
; GFX_LOAD_PALETTE — Program VGA DAC with custom palette (256 colors).
; In:  DS = @DATA (to reach VGA_PALETTE)
; Out: Custom palette loaded into VGA DAC registers
; Preserves: DS, BP
; Clobbers: AX, CX, DX, SI
;-----------------------------------------------------------
GFX_LOAD_PALETTE PROC
    PUSH BP
    PUSH CX
    PUSH DX
    PUSH SI

    XOR  AL, AL
    MOV  DX, 03C8h
    OUT  DX, AL               ; start at color index 0

    LEA  SI, VGA_PALETTE
    MOV  CX, 768              ; 256 × 3
    INC  DX                   ; 03C9h
    CLD
GLP_LOOP:
    LODSB                     ; AL = [DS:SI], SI++
    OUT  DX, AL               ; VGA auto-advances to next register
    LOOP GLP_LOOP

    POP  SI
    POP  DX
    POP  CX
    POP  BP
    RET
GFX_LOAD_PALETTE ENDP

;-----------------------------------------------------------
; GFX_INIT — Set VGA Mode 13h (320×200, 256 colors) + load custom palette.
; In:  (none)
; Out: Mode 13h active, custom palette loaded, ES = A000h
; Preserves: DS, BP
; Clobbers: AX, CX, DX, SI
;-----------------------------------------------------------
GFX_INIT PROC
    PUSH BP

    MOV  AX, 0013h
    INT  10h

    CALL GFX_LOAD_PALETTE     ; load vga256.gpl palette into VGA DAC

    MOV  AX, 0A000h
    MOV  ES, AX

    POP  BP
    RET
GFX_INIT ENDP

;-----------------------------------------------------------
; GFX_SHUTDOWN — Restore text mode (80×25).
; In:  (none)
; Out: Text mode active
; Preserves: DS, BP
; Clobbers: AX
;-----------------------------------------------------------
GFX_SHUTDOWN PROC
    PUSH BP

    MOV  AX, 0003h
    INT  10h

    POP  BP
    RET
GFX_SHUTDOWN ENDP

;-----------------------------------------------------------
; GFX_CLEAR — Fill framebuffer with a single palette index.
; In:  AL = palette index (color)
; Out: Framebuffer filled; ES = A000h
; Preserves: DS, SI, DI, BP
; Clobbers: AX, CX
;-----------------------------------------------------------
GFX_CLEAR PROC
    PUSH BP
    PUSH DI
    PUSH SI

    PUSH AX                 ; stash color
    MOV  AX, 0A000h
    MOV  ES, AX
    POP  AX                 ; AL = color

    XOR  DI, DI
    MOV  CX, BG_SIZE
    CLD
    REP  STOSB

    POP  SI
    POP  DI
    POP  BP
    RET
GFX_CLEAR ENDP

;-----------------------------------------------------------
; GFX_DRAW_SPRITE — Draw 32×32 sprite with color-255 transparency.
; In:  DS:SI = 1024-byte sprite data (row-major, 32×32)
;      BX = x (0–287), DX = y (0–167)
; Out: Sprite composited onto framebuffer; ES = A000h
; Preserves: DS, BP
; Clobbers: AX, BX, CX, DX, SI, DI
;-----------------------------------------------------------
GFX_DRAW_SPRITE PROC
    PUSH BP

    PUSH AX
    MOV  AX, 0A000h
    MOV  ES, AX
    POP  AX

    ; DI = y*320 + x = y*256 + y*64 + x
    PUSH AX
    MOV  AX, DX              ; AX = y
    SHL  AX, 1               ; *2
    SHL  AX, 1               ; *4
    SHL  AX, 1               ; *8
    SHL  AX, 1               ; *16
    SHL  AX, 1               ; *32
    SHL  AX, 1               ; *64
    MOV  DI, AX              ; DI = y*64
    SHL  AX, 1               ; *128
    SHL  AX, 1               ; *256
    ADD  DI, AX              ; DI = y*320
    POP  AX
    ADD  DI, BX              ; DI = y*320 + x

    CLD

    MOV  DX, 32              ; row counter
GDS_ROW:
    MOV  CX, 32              ; column counter
GDS_COL:
    LODSB                    ; AL = [DS:SI], SI++
    CMP  AL, 255
    JE   GDS_SKIP
    STOSB                    ; ES:[DI]=AL, DI++
    LOOP GDS_COL
    JMP  GDS_ROWADV
GDS_SKIP:
    INC  DI                  ; skip pixel
    LOOP GDS_COL
GDS_ROWADV:
    ADD  DI, 320-32          ; next row (advance past remaining cols already handled)
    DEC  DX
    JNZ  GDS_ROW

    POP  BP
    RET
GFX_DRAW_SPRITE ENDP

;-----------------------------------------------------------
; GFX_DRAW_CHAR — Draw 8×8 glyph with font transparency.
; In:  AL = ASCII char
;      BL = color
;      CX = x (0–312)
;      DX = y (0–192)
; Out: 8×8 glyph drawn; ES = A000h
; Preserves: DS, BP
; Clobbers: AX, BX (BH←BL), CX, DX, SI, DI, ES (←A000h)
;-----------------------------------------------------------
GFX_DRAW_CHAR PROC
    PUSH BP

    CALL CHAR_TO_INDEX       ; AX = glyph index 0-39

    ; SI = FONT_TABLE + index*8
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1
    LEA  SI, FONT_TABLE
    ADD  SI, AX              ; DS:SI = glyph bytes

    ; DI = y*320 + x = y*256 + y*64 + x
    PUSH AX
    MOV  AX, DX              ; AX = y
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1
    MOV  DI, AX              ; DI = y*64
    SHL  AX, 1
    SHL  AX, 1
    ADD  DI, AX              ; DI = y*320
    POP  AX
    ADD  DI, CX              ; DI = y*320 + x

    PUSH AX
    MOV  AX, 0A000h
    MOV  ES, AX
    POP  AX

    MOV  BH, BL              ; BH = color (preserve BL through inner work)

    CLD

    MOV  AH, 8               ; row counter
GDC_ROW:
    MOV  AL, [SI]            ; glyph row byte
    INC  SI
    MOV  CX, 8               ; column counter
GDC_COL:
    SHL  AL, 1               ; MSB → CF
    JNC  GDC_SKIP
    MOV  ES:[DI], BH         ; write color pixel
GDC_SKIP:
    INC  DI
    LOOP GDC_COL
    ADD  DI, 320-8           ; next row in framebuffer
    DEC  AH
    JNZ  GDC_ROW

    POP  BP
    RET
GFX_DRAW_CHAR ENDP

;-----------------------------------------------------------
; GFX_DRAW_STRING — Draw null-terminated string with font.
; In:  DS:SI = null-terminated string
;      BL = color
;      CX = x (0–312)
;      DX = y (0–192)
; Out: String rendered; wraps to next line at x > 312
; Preserves: DS, BP
; Clobbers: AX, BX (BH←BL), CX, DX, SI, DI, ES (←A000h)
;-----------------------------------------------------------
GFX_DRAW_STRING PROC
    PUSH BP

GDS_LOOP:
    LODSB                    ; AL = [SI], SI++
    OR   AL, AL
    JZ   GDS_DONE

    PUSH CX                  ; save x
    PUSH DX                  ; save y
    PUSH SI                  ; GFX_DRAW_CHAR clobbers SI
    CALL GFX_DRAW_CHAR
    POP  SI                  ; restore string pointer
    POP  DX
    POP  CX
    ADD  CX, 8               ; advance x
    CMP  CX, 313             ; 320 - 8 + 1 = last valid x
    JB   GDS_LOOP
    XOR  CX, CX              ; wrap x = 0
    ADD  DX, 8               ; next line
    JMP  GDS_LOOP

GDS_DONE:
    POP  BP
    RET
GFX_DRAW_STRING ENDP

;-----------------------------------------------------------
; GFX_LOAD_BG — Load 64,000-byte .BIN image into video memory.
; In:  DS:DX = null-terminated filename
; Out: Framebuffer filled; ES = A000h
; Preserves: AX, BX, CX, DX, SI, DI, ES
; Clobbers: flags
;-----------------------------------------------------------
GFX_LOAD_BG PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES

    ; Open file for reading
    MOV  AH, 3Dh
    MOV  AL, 0               ; read-only
    INT  21h
    JC   GLB_ERR
    MOV  BG_HANDLE, AX

    ; Read directly into A000:0000
    MOV  AX, 0A000h
    MOV  ES, AX
    XOR  DI, DI

    MOV  AH, 3Fh
    MOV  BX, BG_HANDLE
    MOV  CX, BG_SIZE
    PUSH DS
    PUSH ES
    POP  DS                  ; DOS read: DS:DX = buffer
    MOV  DX, DI
    INT  21h
    POP  DS
    JC   GLB_CLOSE

    ; Close file
    MOV  AH, 3Eh
    MOV  BX, BG_HANDLE
    INT  21h
    JMP  GLB_DONE

GLB_CLOSE:
    MOV  AH, 3Eh
    MOV  BX, BG_HANDLE
    INT  21h
    STC                      ; Ensure carry remains set even if close clears it

GLB_DONE:
GLB_ERR:
    POP  ES
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
GFX_LOAD_BG ENDP

END
