; tests/TEST_AUD.ASM — Smoke test for AUDIO module
; Plays 5 audible tests with console text between each.

.MODEL SMALL
.STACK 1024

.DATA
    BANNER      DB 'AUDIO SMOKE TEST',0Dh,0Ah,'$'
    TST1_MSG    DB 'TEST 1: SILENCE...$'
    TST2_MSG    DB 'TEST 2: TONE 440Hz...$'
    TST3_MSG    DB 'TEST 3: DELAY 1s...$'
    TST4_MSG    DB 'TEST 4: PATTERN C-E-G...$'
    TST5_MSG    DB 'TEST 5: LOW TONE 220Hz...$'
    DONE_MSG    DB 'ALL TESTS DONE.',0Dh,0Ah,'$'

    ; Test pattern — C-E-G ascending arpeggio, ~600ms
    PUBLIC TEST_PATTERN
TEST_PATTERN LABEL WORD
    DW  523, 120     ; C5
    DW  659, 120     ; E5
    DW  784, 200     ; G5
    DW    0          ; terminator

.CODE
    EXTRN SND_PLAY_TONE:PROC, SND_SILENCE:PROC
    EXTRN SND_DELAY:PROC, SND_PLAY_PATTERN:PROC

MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX

    ; Silence speaker immediately — DOS may leave port 61h in an unknown state
    CALL SND_SILENCE

    ; --- Banner ---
    MOV  AH, 09h
    LEA  DX, BANNER
    INT  21h

    ; --- Test 1: Silence ---
    MOV  AH, 09h
    LEA  DX, TST1_MSG
    INT  21h
    CALL SND_SILENCE
    MOV  AH, 09h
    LEA  DX, DONE_MSG
    INT  21h

    ; --- Test 2: Play 440 Hz tone for ~800ms ---
    MOV  AH, 09h
    LEA  DX, TST2_MSG
    INT  21h
    MOV  BX, 440
    CALL SND_PLAY_TONE
    MOV  CX, 800
    CALL SND_DELAY
    CALL SND_SILENCE
    MOV  AH, 09h
    LEA  DX, DONE_MSG
    INT  21h

    ; --- Test 3: Silent delay 1 second ---
    MOV  AH, 09h
    LEA  DX, TST3_MSG
    INT  21h
    MOV  CX, 1000
    CALL SND_DELAY
    MOV  AH, 09h
    LEA  DX, DONE_MSG
    INT  21h

    ; --- Test 4: Play pattern ---
    MOV  AH, 09h
    LEA  DX, TST4_MSG
    INT  21h
    LEA  SI, TEST_PATTERN
    CALL SND_PLAY_PATTERN
    MOV  AH, 09h
    LEA  DX, DONE_MSG
    INT  21h

    ; --- Test 5: Play 220 Hz tone for ~500ms ---
    MOV  AH, 09h
    LEA  DX, TST5_MSG
    INT  21h
    MOV  BX, 220
    CALL SND_PLAY_TONE
    MOV  CX, 500
    CALL SND_DELAY
    CALL SND_SILENCE
    MOV  AH, 09h
    LEA  DX, DONE_MSG
    INT  21h

    ; --- Clean exit ---
    MOV  AH, 4Ch
    MOV  AL, 0
    INT  21h
MAIN ENDP

END MAIN
