; src/INPUT.ASM — Keyboard services
; Three BIOS INT 16h wrappers: wait key, check key, read string.

.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

.CODE
    PUBLIC INP_WAIT_KEY, INP_CHECK_KEY, INP_READ_STRING

;-----------------------------------------------------------
; INP_WAIT_KEY — Block until a key is pressed.
; In:  (none)
; Out: AL = ASCII char, AH = scan code
; Preserves: (none — AX is output)
; Clobbers:  AX, flags
;-----------------------------------------------------------
INP_WAIT_KEY PROC
    MOV  AH, 00h
    INT  16h
    RET
INP_WAIT_KEY ENDP

;-----------------------------------------------------------
; INP_CHECK_KEY — Non-blocking key check. Consumes key if present.
; In:  (none)
; Out: ZF=1 if no key available; ZF=0 + AL=ASCII if consumed
; Preserves: (none — AX and ZF are outputs)
; Clobbers:  AX, flags
; Note: if AL=0 (extended key), ZF may be set despite consumption.
;       Accept for MVP — only printable chars are used.
;-----------------------------------------------------------
INP_CHECK_KEY PROC
    MOV  AH, 01h
    INT  16h
    JZ   ICK_NONE            ; ZF=1 — no key in buffer
    MOV  AH, 00h             ; consume the key
    INT  16h
    OR   AL, AL              ; clear ZF (AL non-zero for printable chars)
    RET
ICK_NONE:
    XOR  AX, AX              ; ZF=1 (AX=0 sets ZF)
    RET
INP_CHECK_KEY ENDP

;-----------------------------------------------------------
; INP_READ_STRING — Read a string until Enter, with basic editing.
; No screen echo — callers in graphics mode must handle echo
; via GFX_DRAW_CHAR at their desired position.
; In:  ES:DI = buffer, CX = max length
; Out: buffer null-terminated, CX = actual length
; Preserves: BX, DI
; Clobbers:  AX, CX, flags
;-----------------------------------------------------------
INP_READ_STRING PROC
    PUSH AX
    PUSH BX
    PUSH DI

    XOR  BX, BX              ; BX = current length

IRS_LOOP:
    CALL INP_WAIT_KEY        ; blocks; AL=char, AH=scancode
    CMP  AL, 13              ; Enter?
    JE   IRS_DONE
    CMP  AL, 8               ; Backspace?
    JE   IRS_BACKSPACE
    CMP  BX, CX              ; buffer full? (unsigned compare)
    JAE  IRS_LOOP            ; ignore new chars when full

    ; Convert lowercase to uppercase
    CMP  AL, 'a'
    JB   IRS_STORE
    CMP  AL, 'z'
    JA   IRS_STORE
    SUB  AL, 32              ; 'a'->'A'

IRS_STORE:
    MOV  ES:[DI+BX], AL      ; store char in caller's buffer
    INC  BX
    JMP  IRS_LOOP

IRS_BACKSPACE:
    OR   BX, BX              ; anything to delete?
    JZ   IRS_LOOP            ; no — ignore backspace
    DEC  BX
    JMP  IRS_LOOP

IRS_DONE:
    MOV  BYTE PTR ES:[DI+BX], 0   ; null-terminate
    MOV  CX, BX                   ; return actual length

    POP  DI
    POP  BX
    POP  AX
    RET
INP_READ_STRING ENDP

END
