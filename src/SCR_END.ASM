; SCR_END.ASM — Score Screen + Leaderboard (v1.4)
; Public: SCR_SCORE_RUN, SCR_END_RUN
;   SCR_SCORE_RUN: GFX_CLEAR → route BG (1P/2P) → jingle →
;                  score display → INP_WAIT_KEY → STATE_END
;   SCR_END_RUN:   GFX_CLEAR → GFX_LOAD_BG(END.BIN) → leaderboard
;                  insert/save → leaderboard render → INP_WAIT_KEY → STATE_QUIT

.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    ; --- Global state (from MAIN.ASM) ---
    EXTRN CURRENT_STATE:BYTE, NUM_PLAYERS:BYTE
    EXTRN PLAYER_NAMES:BYTE, SCORES:WORD, HEARTS_ARR:BYTE
    EXTRN DIFFICULTY:BYTE, LEADERBOARD:BYTE

    ; --- Data assets (from DATA.ASM) ---
    EXTRN STR_GAMEOVER:BYTE, STR_WIN:BYTE
    EXTRN STR_PLAYER1:BYTE, STR_PLAYER2:BYTE
    EXTRN STR_VS:BYTE, STR_WINNER:BYTE, STR_TIE:BYTE
    EXTRN BG_END:BYTE, BG_SCORE1:BYTE, BG_SCORE2:BYTE
    EXTRN SND_WIN_JINGLE:WORD, SND_LOSE_JINGLE:WORD

    ; --- Private strings ---
    STR_LEADER   DB 'TOP 5 PLAYERS',0
    STR_PTS      DB ' PTS',0
    STR_SEP      DB ' | ',0              ; leaderboard column separator
    STR_DASH     DB ' - ',0
    NUM_BUF      DB 6 DUP(0)            ; scratch for NUM_TO_STR (5 digits + null)
    DIFF_CHARS   DB 'E','M','H'         ; difficulty labels (indexed by DIFF_EASY=0, etc.)

    ; --- Leaderboard loop scratch ---
    LB_OFFSET    DW 0                    ; current byte offset into LEADERBOARD
    LB_Y         DW 0                    ; current Y position
    LB_IDX       DB 0                    ; entry index 0..4

.CODE
    ; --- GFX procs ---
    EXTRN GFX_LOAD_BG:PROC, GFX_CLEAR:PROC, GFX_DRAW_STRING:PROC, GFX_DRAW_CHAR:PROC

    ; --- Input procs ---
    EXTRN INP_WAIT_KEY:PROC

    ; --- Audio procs ---
    EXTRN SND_PLAY_PATTERN:PROC

    ; --- File I/O procs ---
    EXTRN FILE_INSERT_SCORE:PROC, FILE_SAVE_SCORES:PROC

    PUBLIC SCR_SCORE_RUN, SCR_END_RUN

; ================================================================
; NUM_TO_STR — Convert 16-bit unsigned to decimal ASCII string.
;   In:  AX = number (0–65535)
;        ES:DI = dest buffer (6 bytes min)
;   Out: buffer null-terminated
;   Preserves: BX, CX, DX, DI
;   Clobbers:  AX
; ================================================================
NUM_TO_STR PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    OR   AX, AX
    JNZ  NTS_DIVIDE

    ; Zero case — store "0"
    MOV  BYTE PTR ES:[DI], '0'
    MOV  BYTE PTR ES:[DI+1], 0
    JMP  NTS_DONE

NTS_DIVIDE:
    XOR  CX, CX              ; CX = digit count

NTS_PUSH:
    XOR  DX, DX
    MOV  BX, 10
    DIV  BX                   ; AX = quotient, DX = remainder (0-9)
    PUSH DX                   ; save digit on stack
    INC  CX
    OR   AX, AX
    JNZ  NTS_PUSH

NTS_POP:
    POP  DX
    ADD  DL, '0'
    MOV  ES:[DI], DL
    INC  DI
    LOOP NTS_POP

    MOV  BYTE PTR ES:[DI], 0  ; null terminate

NTS_DONE:
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    RET
NUM_TO_STR ENDP


; ================================================================
; DRAW_CHAR_SAFE — Draw one char with CX/DX preservation + advance.
; GFX_DRAW_CHAR clobbers CX and DX. This wrapper saves/restores
; them (like GFX_DRAW_STRING does internally) and advances CX by 8.
;   In:  AL = ASCII char, BL = color, CX = x, DX = y
;   Out: CX += 8, DX preserved; ES = A000h
;   Preserves: DX
;   Clobbers:  AX, SI, DI
; ================================================================
DRAW_CHAR_SAFE PROC
    PUSH CX
    PUSH DX
    CALL GFX_DRAW_CHAR
    POP  DX
    POP  CX
    ADD  CX, 8
    RET
DRAW_CHAR_SAFE ENDP


; ================================================================
; SCR_SCORE_RUN — Show player scores after the round ends.
;   Routes background: SCORE1.BIN (1P) or SCORE2.BIN (2P).
;   Plays win/lose jingle, shows score display, winner.
;   Reads:  NUM_PLAYERS, SCORES[], HEARTS_ARR[], PLAYER_NAMES[]
;   Writes: CURRENT_STATE = STATE_END
;   Preserves: BX, CX, DX, SI, DI, BP
; ================================================================
SCR_SCORE_RUN PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    MOV  AX, @DATA
    MOV  DS, AX

    ; --- 1. Clear framebuffer, then load background (route by player count) ---
    MOV  AL, 0
    CALL GFX_CLEAR
    CMP  NUM_PLAYERS, 2
    JE   SSR_2P_BG
    LEA  DX, BG_SCORE1
    JMP  SSR_LOAD_BG
SSR_2P_BG:
    LEA  DX, BG_SCORE2
SSR_LOAD_BG:
    CALL GFX_LOAD_BG            ; ES = A000h after this

    ; --- 2. Determine win/lose and play jingle ---
    MOV  AL, HEARTS_ARR
    OR   AL, AL
    JZ   SSR_LOSE_JINGLE
    CMP  NUM_PLAYERS, 2
    JB   SSR_WIN_JINGLE
    CMP  HEARTS_ARR+1, 0
    JE   SSR_LOSE_JINGLE

SSR_WIN_JINGLE:
    LEA  SI, SND_WIN_JINGLE
    CALL SND_PLAY_PATTERN
    JMP  SSR_AFTER_JINGLE

SSR_LOSE_JINGLE:
    LEA  SI, SND_LOSE_JINGLE
    CALL SND_PLAY_PATTERN

SSR_AFTER_JINGLE:
    ; --- 3. Score display ---
    CMP  NUM_PLAYERS, 2
    JE   SSR_2P_SCORES

    ; --- 3a. 1P score row at (131, 104) ---
    MOV  BL, 1
    MOV  CX, 131
    MOV  DX, 104

    MOV  AL, PLAYER_NAMES
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+1
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+2
    CALL DRAW_CHAR_SAFE

    LEA  SI, STR_DASH
    CALL GFX_DRAW_STRING

    MOV  AX, SCORES
    PUSH ES
    PUSH DS
    POP  ES
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES

    SUB  CX, 10
    LEA  SI, NUM_BUF
    CALL GFX_DRAW_STRING
    SUB  CX, 15
    LEA  SI, STR_PTS
    CALL GFX_DRAW_STRING
    JMP  SSR_WAIT_KEY

    ; --- 3b. 2P score display ---
SSR_2P_SCORES:
    ; P1 row at (136, 93)
    MOV  BL, 1
    MOV  CX, 136
    MOV  DX, 93

    MOV  AL, PLAYER_NAMES
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+1
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+2
    CALL DRAW_CHAR_SAFE

    LEA  SI, STR_DASH
    CALL GFX_DRAW_STRING

    MOV  AX, SCORES
    PUSH ES
    PUSH DS
    POP  ES
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES

    SUB  CX, 10
    LEA  SI, NUM_BUF
    CALL GFX_DRAW_STRING
    LEA  SI, STR_PTS
    CALL GFX_DRAW_STRING

    ; P2 row at (136, 122)
    MOV  BL, 1
    MOV  CX, 136
    MOV  DX, 122

    MOV  AL, PLAYER_NAMES+3
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+4
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+5
    CALL DRAW_CHAR_SAFE

    LEA  SI, STR_DASH
    CALL GFX_DRAW_STRING

    MOV  AX, SCORES+2
    PUSH ES
    PUSH DS
    POP  ES
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES

    SUB  CX, 10
    LEA  SI, NUM_BUF
    CALL GFX_DRAW_STRING
    LEA  SI, STR_PTS
    CALL GFX_DRAW_STRING

    ; --- Winner / Tie banner at Y=78 ---
    MOV  AX, SCORES
    CMP  AX, SCORES+2
    JE   SSR_TIE
    JA   SSR_P1_WIN

    ; P2 wins: "WINNER: BBB"
    MOV  BL, 1
    MOV  CX, 95
    MOV  DX, 78
    LEA  SI, STR_WINNER
    CALL GFX_DRAW_STRING
    MOV  AL, PLAYER_NAMES+3
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+4
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+5
    CALL DRAW_CHAR_SAFE
    JMP  SSR_WAIT_KEY

SSR_P1_WIN:
    ; P1 wins: "WINNER: AAA"
    MOV  BL, 1
    MOV  CX, 95
    MOV  DX, 78
    LEA  SI, STR_WINNER
    CALL GFX_DRAW_STRING
    MOV  AL, PLAYER_NAMES
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+1
    CALL DRAW_CHAR_SAFE
    MOV  AL, PLAYER_NAMES+2
    CALL DRAW_CHAR_SAFE
    JMP  SSR_WAIT_KEY

SSR_TIE:
    MOV  BL, 1
    MOV  CX, 100
    MOV  DX, 78
    LEA  SI, STR_TIE
    CALL GFX_DRAW_STRING

    ; --- 4. Wait for any key ---
SSR_WAIT_KEY:
    CALL INP_WAIT_KEY

    ; --- 5. Transition to leaderboard ---
    MOV  CURRENT_STATE, STATE_END
    POP  BP
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    RET
SCR_SCORE_RUN ENDP


; ================================================================
; SCR_END_RUN — Leaderboard insert, save, and display.
;   Reads:  NUM_PLAYERS, SCORES[], PLAYER_NAMES[], DIFFICULTY,
;           LEADERBOARD
;   Writes: LEADERBOARD (via FILE_INSERT_SCORE + FILE_SAVE_SCORES)
;           CURRENT_STATE = STATE_QUIT
;   Preserves: BX, CX, DX, SI, DI, BP
; ================================================================
SCR_END_RUN PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    MOV  AX, @DATA
    MOV  DS, AX

    ; --- 1. Clear framebuffer, then load background ---
    MOV  AL, 0
    CALL GFX_CLEAR
    LEA  DX, BG_END
    CALL GFX_LOAD_BG            ; ES = A000h after this

    ; --- 2. Leaderboard insert ---
    LEA  SI, PLAYER_NAMES
    MOV  BX, SCORES
    MOV  AL, DIFFICULTY
    CALL FILE_INSERT_SCORE

    ; Insert P2 (2P only)
    CMP  NUM_PLAYERS, 2
    JNE  SER_SAVE
    LEA  SI, PLAYER_NAMES+3
    MOV  BX, SCORES+2
    MOV  AL, DIFFICULTY
    CALL FILE_INSERT_SCORE

SER_SAVE:
    CALL FILE_SAVE_SCORES

    ; --- 3. Leaderboard render ---
    ; Init loop state in scratch variables
    MOV  LB_OFFSET, 0
    MOV  LB_Y, 57
    MOV  LB_IDX, 0

SER_LB_LOOP:
    ; Check if entry is empty (name[0] == 0) → skip
    MOV  DI, LB_OFFSET
    CMP  BYTE PTR [LEADERBOARD + DI], 0
    JE   SER_LB_NEXT

    ; --- Draw name (3 chars) at (82, LB_Y) ---
    MOV  CX, 82
    MOV  DX, LB_Y
    MOV  BL, 1

    MOV  AL, [LEADERBOARD + DI]
    CALL DRAW_CHAR_SAFE
    MOV  DI, LB_OFFSET             ; reload — DI clobbered by DRAW_CHAR_SAFE
    MOV  AL, [LEADERBOARD + DI + 1]
    CALL DRAW_CHAR_SAFE
    MOV  DI, LB_OFFSET             ; reload — DI clobbered by DRAW_CHAR_SAFE
    MOV  AL, [LEADERBOARD + DI + 2]
    CALL DRAW_CHAR_SAFE

    ; " | "
    LEA  SI, STR_SEP
    CALL GFX_DRAW_STRING

    ; Score number
    MOV  DI, LB_OFFSET
    MOV  AX, WORD PTR [LEADERBOARD + DI + 3]

    PUSH ES
    PUSH DS
    POP  ES
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES

    LEA  SI, NUM_BUF
    CALL GFX_DRAW_STRING

    ; " | "
    LEA  SI, STR_SEP
    CALL GFX_DRAW_STRING

    ; Difficulty letter
    MOV  DI, LB_OFFSET
    MOV  AL, [LEADERBOARD + DI + 5]
    MOV  AH, 0
    MOV  SI, AX
    MOV  AL, DIFF_CHARS[SI]
    CALL DRAW_CHAR_SAFE

SER_LB_NEXT:
    ADD  LB_OFFSET, LB_ENTRY_SIZE
    ADD  LB_Y, 13
    INC  LB_IDX
    CMP  LB_IDX, LB_MAX_ENTRIES
    JB   SER_LB_LOOP

    ; --- 4. Wait for any key ---
    CALL INP_WAIT_KEY

    ; --- 5. Transition to quit ---
    MOV  CURRENT_STATE, STATE_QUIT
    POP  BP
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    RET
SCR_END_RUN ENDP

END
