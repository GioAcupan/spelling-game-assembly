; MAIN.ASM — Entry point and game loop (v1.2)
; Owns all runtime state. Calls GAME_TICK in a loop until STATE_QUIT.

.MODEL SMALL
.STACK 1024

.DATA
    INCLUDE SHARED.INC

    ; --- Runtime state (global variables) ---
    CURRENT_STATE   DB  STATE_TITLE
    NUM_PLAYERS     DB  1
    CURRENT_PLAYER  DB  0
    DIFFICULTY      DB  DIFF_EASY
    CURRENT_WORD    DB  0
    TIMER_START     DW  0

    ; --- Leaderboard (5 entries × 8 bytes = 40B) ---
    LEADERBOARD     DB  LB_MAX_ENTRIES * LB_ENTRY_SIZE DUP(0)

    ; --- Login / user account state (v1.3) ---
    SESSION_USER    DB  '   '            ; logged-in username (3 chars)
    USER_TABLE      DB  MAX_USERS * USER_RECORD_SIZE DUP(0)  ; 5 × 8 = 40B
    USER_COUNT      DB  0                ; active entries in USER_TABLE
    LOGIN_RETRIES   DB  0                ; wrong-password counter
    USERNAME_BUF    DB  3 DUP(0)         ; login input scratch
    PASSWORD_BUF    DB  5 DUP(0)         ; login input scratch

    ; --- Player-indexed arrays (v1.2) ---
    PLAYER_NAMES    DB  '   ', '   '   ; 2 x 3-char names
    SCORES          DW  0, 0           ; 2 x 16-bit score
    HEARTS_ARR      DB  MAX_HEARTS, MAX_HEARTS
    PLAYER_RESULTS  DB  0, 0
    PLAYER_TIMES    DW  0, 0

    INPUT_BUFFER    DB  17 DUP(0)

    PUBLIC CURRENT_STATE, NUM_PLAYERS, CURRENT_PLAYER, DIFFICULTY
    PUBLIC CURRENT_WORD, TIMER_START
    PUBLIC LEADERBOARD, SESSION_USER, USER_TABLE, USER_COUNT, LOGIN_RETRIES
    PUBLIC USERNAME_BUF, PASSWORD_BUF
    PUBLIC PLAYER_NAMES, SCORES, HEARTS_ARR, PLAYER_RESULTS, PLAYER_TIMES
    PUBLIC INPUT_BUFFER

.CODE
    EXTRN GAME_TICK:PROC
    EXTRN GFX_INIT:PROC, GFX_SHUTDOWN:PROC
    EXTRN FILE_LOAD_SCORES:PROC
    EXTRN USER_LOAD:PROC

MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    CALL GFX_INIT
    CALL FILE_LOAD_SCORES
    CALL USER_LOAD

GAME_LOOP:
    CALL GAME_TICK
    CMP CURRENT_STATE, STATE_QUIT
    JNE GAME_LOOP

    CALL GFX_SHUTDOWN
    MOV AH, 4Ch
    MOV AL, 0
    INT 21h
MAIN ENDP

END MAIN
