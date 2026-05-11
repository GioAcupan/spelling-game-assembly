; tests/TEST_DT.ASM — Smoke test for DATA module
; Links with DATA.OBJ and verifies word lists, tier table,
; sprite table, and sound table accessibility.

.MODEL SMALL
.STACK 1024

.DATA
    INCLUDE SHARED.INC
    EXTRN EASY_WORDS:BYTE
    EXTRN MED_WORDS:BYTE
    EXTRN HARD_WORDS:BYTE
    EXTRN TIER_TABLE:WORD
    EXTRN SPRITE_TABLE:BYTE
    EXTRN SOUND_TABLE:WORD

    MSG_HEADER  DB 'DATA.ASM Smoke Test', 0Dh, 0Ah
                DB '===================', 0Dh, 0Ah, '$'
    MSG_TIER0   DB 'TIER 0 (EASY):  $'
    MSG_TIER1   DB 'TIER 1 (MED):   $'
    MSG_TIER2   DB 'TIER 2 (HARD):  $'
    MSG_PASS    DB ' [PASS]', 0Dh, 0Ah, '$'
    MSG_FAIL    DB ' [FAIL]', 0Dh, 0Ah, '$'
    MSG_SPRITE  DB 'SPRITE TABLE:   $'
    MSG_SOUND   DB 'SOUND TABLE:    $'
    MSG_DONE    DB '===================', 0Dh, 0Ah
                DB 'ALL TESTS PASSED', 0Dh, 0Ah, '$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; --- Print header ---
    MOV AH, 09h
    LEA DX, MSG_HEADER
    INT 21h

    ; ============================================================
    ; Test 1: WORD LISTS — print first word of each tier
    ; ============================================================

    ; --- Tier 0: Easy ---
    MOV AH, 09h
    LEA DX, MSG_TIER0
    INT 21h
    LEA SI, EASY_WORDS
    CALL PRINT_WORD
    CMP BYTE PTR [EASY_WORDS], 'C'
    JE  L1
    JMP T1_FAIL
L1: MOV AH, 09h
    LEA DX, MSG_PASS
    INT 21h

    ; --- Tier 1: Medium ---
    MOV AH, 09h
    LEA DX, MSG_TIER1
    INT 21h
    LEA SI, MED_WORDS
    CALL PRINT_WORD
    CMP BYTE PTR [MED_WORDS], 'A'
    JE  L2
    JMP T1_FAIL
L2: MOV AH, 09h
    LEA DX, MSG_PASS
    INT 21h

    ; --- Tier 2: Hard ---
    MOV AH, 09h
    LEA DX, MSG_TIER2
    INT 21h
    LEA SI, HARD_WORDS
    CALL PRINT_WORD
    CMP BYTE PTR [HARD_WORDS], 'O'
    JE  L3
    JMP T1_FAIL
L3: MOV AH, 09h
    LEA DX, MSG_PASS
    INT 21h

    ; ============================================================
    ; Test 2: TIER_TABLE resolution
    ; ============================================================
    MOV BX, 0
    SHL BX, 1
    MOV SI, [TIER_TABLE+BX]
    CMP SI, OFFSET EASY_WORDS
    JE  L4
    JMP T2_FAIL
L4:
    MOV BX, 1
    SHL BX, 1
    MOV SI, [TIER_TABLE+BX]
    CMP SI, OFFSET MED_WORDS
    JE  L5
    JMP T2_FAIL
L5:
    MOV BX, 2
    SHL BX, 1
    MOV SI, [TIER_TABLE+BX]
    CMP SI, OFFSET HARD_WORDS
    JE  L6
    JMP T2_FAIL
L6:

    ; ============================================================
    ; Test 3: SPRITE_TABLE — non-zero bytes after blank rows
    ; ============================================================
    MOV AH, 09h
    LEA DX, MSG_SPRITE
    INT 21h
    LEA BX, SPRITE_TABLE
    CMP BYTE PTR [BX+96], 0
    JNE T3_PASS
    CMP BYTE PTR [BX+100], 0
    JNE T3_PASS
    CMP BYTE PTR [BX+1024], 0
    JNE T3_PASS
    CMP BYTE PTR [BX+1024+192], 0
    JNE L7
    JMP T3_FAIL
L7:
T3_PASS:
    MOV AH, 09h
    LEA DX, MSG_PASS
    INT 21h

    ; ============================================================
    ; Test 4: SOUND_TABLE — first pattern accessible
    ; ============================================================
    MOV AH, 09h
    LEA DX, MSG_SOUND
    INT 21h
    MOV SI, [SOUND_TABLE]
    CMP WORD PTR [SI], 0
    JNE L8
    JMP T4_FAIL
L8: CMP WORD PTR [SI], 784
    JE  L9
    JMP T4_FAIL
L9: MOV AH, 09h
    LEA DX, MSG_PASS
    INT 21h

    ; ============================================================
    ; All tests passed
    ; ============================================================
    MOV AH, 09h
    LEA DX, MSG_DONE
    INT 21h
    MOV AH, 4Ch
    MOV AL, 0
    INT 21h

    ; --- Failure handlers (far — reached via JMP only) ---
T1_FAIL:
    MOV AH, 09h
    LEA DX, MSG_FAIL
    INT 21h
    JMP DONE_FAIL
T2_FAIL:
    MOV AH, 09h
    LEA DX, MSG_TIER0
    INT 21h
DONE_FAIL:
    MOV AH, 4Ch
    MOV AL, 1
    INT 21h
T3_FAIL:
    MOV AH, 09h
    LEA DX, MSG_FAIL
    INT 21h
    JMP DONE_FAIL
T4_FAIL:
    MOV AH, 09h
    LEA DX, MSG_FAIL
    INT 21h
    JMP DONE_FAIL
MAIN ENDP

;-----------------------------------------------------------
; PRINT_WORD — Print null-terminated word at DS:SI
; In:  DS:SI -> null-terminated ASCII string
; Out: (none)
; Preserves: SI
; Clobbers: AX, DX
;-----------------------------------------------------------
PRINT_WORD PROC
    PUSH SI
PW_LOOP:
    MOV AL, [SI]
    OR  AL, AL
    JZ  PW_DONE
    MOV AH, 02h
    MOV DL, AL
    INT 21h
    INC SI
    JMP PW_LOOP
PW_DONE:
    POP SI
    RET
PRINT_WORD ENDP

END MAIN
