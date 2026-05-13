; tests/TEST_FIO.ASM — Smoke test for FILEIO module
; Tests all 6 procedures: 3 leaderboard + 3 user-account.
; Result: 8 test lines on Mode 13h screen. OK=green, FAIL=red.
; Prerequisite: no SCORES.DAT or USERS.DAT in working directory.

.MODEL SMALL
.STACK 1024

.DATA
    INCLUDE SHARED.INC

    ; --- Leaderboard buffer (PUBLIC — FILEIO.ASM EXTRNs this) ---
    PUBLIC LEADERBOARD
LEADERBOARD     DB  LB_MAX_ENTRIES * LB_ENTRY_SIZE DUP(0)

    ; --- User account state (PUBLIC — FILEIO.ASM EXTRNs these) ---
    PUBLIC USER_TABLE, USER_COUNT
USER_TABLE      DB  MAX_USERS * USER_RECORD_SIZE DUP(0)
USER_COUNT      DB  0

    ; --- Test label strings ---
    STR_T1    DB 'T1:OK',0
    STR_T1F   DB 'T1:FAIL',0
    STR_T2    DB 'T2:OK',0
    STR_T2F   DB 'T2:FAIL',0
    STR_T3    DB 'T3:OK',0
    STR_T3F   DB 'T3:FAIL',0
    STR_T4    DB 'T4:OK',0
    STR_T4F   DB 'T4:FAIL',0
    STR_T5    DB 'T5:OK',0
    STR_T5F   DB 'T5:FAIL',0
    STR_T6    DB 'T6:OK',0
    STR_T6F   DB 'T6:FAIL',0
    STR_T7    DB 'T7:OK',0
    STR_T7F   DB 'T7:FAIL',0
    STR_T8    DB 'T8:OK',0
    STR_T8F   DB 'T8:FAIL',0
    STR_DONE  DB 'SMOKE TEST DONE. PRESS ANY KEY.',0
    DOS_DONE  DB 'TEST_FIO smoke test complete!$'

    ; --- Test data ---
    TEST_NAME  DB 'AAA'
    TEST_NAME2 DB 'BOB'
    TEST_PW    DB '12345'
    TEST_PW2   DB 'WRONG'

    ; Filenames for cleanup (local copies — FILEIO.ASM owns the real ones)
    CLN_SCORES DB 'SCORES.DAT',0
    CLN_USERS  DB 'USERS.DAT',0

.CODE
    EXTRN FILE_LOAD_SCORES:PROC, FILE_SAVE_SCORES:PROC, FILE_INSERT_SCORE:PROC
    EXTRN USER_LOAD:PROC, USER_AUTH:PROC, USER_SAVE:PROC
    EXTRN GFX_INIT:PROC, GFX_CLEAR:PROC, GFX_DRAW_STRING:PROC, GFX_SHUTDOWN:PROC

;---------------------------------------------------------------
; DRAW_RESULT — Draw test result string at (CX, DX).
; In:  SI = string ptr, BL = color, CX = x, DX = y
; Out: DX += 12 (next line), CX = 20 (reset x)
;---------------------------------------------------------------
DRAW_RESULT PROC
    CALL GFX_DRAW_STRING
    ADD  DX, 12
    MOV  CX, 20
    RET
DRAW_RESULT ENDP

MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX

    ; Delete leftover files from previous runs
    MOV  AH, 41h
    LEA  DX, CLN_SCORES
    INT  21h
    MOV  AH, 41h
    LEA  DX, CLN_USERS
    INT  21h

    ; Init graphics
    CALL GFX_INIT
    MOV  AL, 8             ; dark gray
    CALL GFX_CLEAR

    MOV  CX, 20            ; X origin for all test lines
    MOV  DX, 10            ; starting Y

    ; ================================================================
    ; TEST 1 — FILE_LOAD_SCORES with no SCORES.DAT
    ; LEADERBOARD should be all zeros after load.
    ; ================================================================
    CALL FILE_LOAD_SCORES
    CMP  BYTE PTR [LEADERBOARD], 0
    JNE  T1_FAIL
    LEA  SI, STR_T1
    MOV  BL, 2             ; green
    JMP  T1_DRAW
T1_FAIL:
    LEA  SI, STR_T1F
    MOV  BL, 4             ; red
T1_DRAW:
    CALL DRAW_RESULT

    ; ================================================================
    ; TEST 2 — FILE_INSERT_SCORE: insert "AAA"/240/HARD
    ; Should occupy slot 0.
    ; ================================================================
    LEA  SI, TEST_NAME     ; "AAA"
    MOV  BX, 240
    MOV  AL, DIFF_HARD
    CALL FILE_INSERT_SCORE
    ; Verify slot 0 name = 'AAA'
    CMP  BYTE PTR [LEADERBOARD], 'A'
    JNE  T2_FAIL
    CMP  WORD PTR [LEADERBOARD + 3], 240
    JNE  T2_FAIL
    CMP  BYTE PTR [LEADERBOARD + 5], DIFF_HARD
    JNE  T2_FAIL
    LEA  SI, STR_T2
    MOV  BL, 2
    JMP  T2_DRAW
T2_FAIL:
    LEA  SI, STR_T2F
    MOV  BL, 4
T2_DRAW:
    CALL DRAW_RESULT

    ; ================================================================
    ; TEST 3 — FILE_SAVE_SCORES + reload
    ; Save, zero LEADERBOARD, reload, verify slot 0 survived.
    ; ================================================================
    CALL FILE_SAVE_SCORES
    ; Zero LEADERBOARD
    PUSH DS
    POP  ES
    LEA  DI, LEADERBOARD
    MOV  CX, LB_MAX_ENTRIES * LB_ENTRY_SIZE
    MOV  AL, 0
    CLD
    REP  STOSB
    CALL FILE_LOAD_SCORES
    CMP  BYTE PTR [LEADERBOARD], 'A'
    JNE  T3_FAIL
    CMP  WORD PTR [LEADERBOARD + 3], 240
    JNE  T3_FAIL
    LEA  SI, STR_T3
    MOV  BL, 2
    JMP  T3_DRAW
T3_FAIL:
    LEA  SI, STR_T3F
    MOV  BL, 4
T3_DRAW:
    CALL DRAW_RESULT

    ; ================================================================
    ; TEST 4 — USER_LOAD with no USERS.DAT
    ; USER_COUNT should be 0, table zeroed.
    ; ================================================================
    ; Zero USER_TABLE first (simulate startup state)
    PUSH DS
    POP  ES
    LEA  DI, USER_TABLE
    MOV  CX, MAX_USERS * USER_RECORD_SIZE
    MOV  AL, 0
    CLD
    REP  STOSB
    MOV  USER_COUNT, 99     ; set to non-zero to verify LOAD resets it
    CALL USER_LOAD
    CMP  BYTE PTR [USER_COUNT], 0
    JNE  T4_FAIL
    LEA  SI, STR_T4
    MOV  BL, 2
    JMP  T4_DRAW
T4_FAIL:
    LEA  SI, STR_T4F
    MOV  BL, 4
T4_DRAW:
    CALL DRAW_RESULT

    ; ================================================================
    ; TEST 5 — USER_AUTH new user: "BOB"/"12345"
    ; Should return AX=1 (new user registered).
    ; ================================================================
    LEA  SI, TEST_NAME2    ; "BOB"
    LEA  DI, TEST_PW       ; "12345"
    CALL USER_AUTH
    CMP  AX, 1
    JNE  T5_FAIL
    ; Verify USER_COUNT incremented
    CMP  BYTE PTR [USER_COUNT], 1
    JNE  T5_FAIL
    LEA  SI, STR_T5
    MOV  BL, 2
    JMP  T5_DRAW
T5_FAIL:
    LEA  SI, STR_T5F
    MOV  BL, 4
T5_DRAW:
    CALL DRAW_RESULT

    ; ================================================================
    ; TEST 6 — USER_AUTH correct password
    ; Should return AX=0.
    ; ================================================================
    LEA  SI, TEST_NAME2    ; "BOB"
    LEA  DI, TEST_PW       ; "12345"
    CALL USER_AUTH
    CMP  AX, 0
    JNE  T6_FAIL
    LEA  SI, STR_T6
    MOV  BL, 2
    JMP  T6_DRAW
T6_FAIL:
    LEA  SI, STR_T6F
    MOV  BL, 4
T6_DRAW:
    CALL DRAW_RESULT

    ; ================================================================
    ; TEST 7 — USER_AUTH wrong password
    ; Should return AX=2.
    ; ================================================================
    LEA  SI, TEST_NAME2    ; "BOB"
    LEA  DI, TEST_PW2      ; "WRONG"
    CALL USER_AUTH
    CMP  AX, 2
    JNE  T7_FAIL
    LEA  SI, STR_T7
    MOV  BL, 2
    JMP  T7_DRAW
T7_FAIL:
    LEA  SI, STR_T7F
    MOV  BL, 4
T7_DRAW:
    CALL DRAW_RESULT

    ; ================================================================
    ; TEST 8 — USER_SAVE + reload
    ; Save, zero table, reload, verify "BOB" survived.
    ; ================================================================
    CALL USER_SAVE
    ; Zero USER_TABLE and USER_COUNT
    PUSH DS
    POP  ES
    LEA  DI, USER_TABLE
    MOV  CX, MAX_USERS * USER_RECORD_SIZE
    MOV  AL, 0
    CLD
    REP  STOSB
    MOV  USER_COUNT, 0
    CALL USER_LOAD
    CMP  BYTE PTR [USER_COUNT], 1
    JNE  T8_FAIL
    CMP  BYTE PTR [USER_TABLE], 'B'
    JNE  T8_FAIL
    LEA  SI, STR_T8
    MOV  BL, 2
    JMP  T8_DRAW
T8_FAIL:
    LEA  SI, STR_T8F
    MOV  BL, 4
T8_DRAW:
    CALL DRAW_RESULT

    ; --- Done ---
    LEA  SI, STR_DONE
    MOV  BL, 15            ; white
    MOV  CX, 20
    MOV  DX, 170
    CALL GFX_DRAW_STRING

    ; Wait for key
    MOV  AH, 00h
    INT  16h

    CALL GFX_SHUTDOWN

    ; Clean up test files for next run
    MOV  AH, 41h
    LEA  DX, CLN_SCORES
    INT  21h
    MOV  AH, 41h
    LEA  DX, CLN_USERS
    INT  21h

    MOV  AH, 09h
    LEA  DX, DOS_DONE
    INT  21h

    MOV  AH, 4Ch
    MOV  AL, 0
    INT  21h
MAIN ENDP

END MAIN
