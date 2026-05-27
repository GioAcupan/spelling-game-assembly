; SCR_GAME.ASM — Main gameplay screen (v1.4 spec)
; Public: SCR_ROUND_RUN, SCR_JUDGE_RUN
;   SCR_ROUND_RUN — per-player: reload bg → sprite → scramble → input loop
;   SCR_JUDGE_RUN — judge answers, update scores/hearts, advance/end
;
; v1.5: sprites + sounds integrated — GFX_DRAW_SPRITE + SND_PLAY_PATTERN active.
.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    ; --- Global state (from MAIN.ASM) ---
    EXTRN CURRENT_STATE:BYTE, CURRENT_WORD:BYTE
    EXTRN NUM_PLAYERS:BYTE, CURRENT_PLAYER:BYTE
    EXTRN DIFFICULTY:BYTE
    EXTRN PLAYER_NAMES:BYTE, SCORES:WORD, HEARTS_ARR:BYTE
    EXTRN PLAYER_RESULTS:BYTE, PLAYER_TIMES:WORD
    EXTRN INPUT_BUFFER:BYTE

    ; --- Data assets (from DATA.ASM) ---

    EXTRN TIER_TABLE:WORD
    EXTRN STR_GAMEOVER:BYTE, STR_WIN:BYTE
    EXTRN STR_PLAYER1:BYTE, STR_PLAYER2:BYTE, STR_YOUR_TURN:BYTE
    EXTRN STR_VS:BYTE, BG_ROUND:BYTE, BG_JUDGE:BYTE
    EXTRN SCRAMBLE_TABLE:BYTE, STR_HINT:BYTE
    EXTRN SPRITE_TABLE:BYTE, SOUND_TABLE:WORD
    EXTRN SND_CORRECT_SFX:WORD, SND_WRONG_SFX:WORD


    ; --- Private strings & scratch ---
    STR_RIGHT   DB 'YES!',0
    STR_WRONG   DB 'OOPS!',0
    STR_TYPE    DB 'TYPE IT:',0
    STR_SCORE   DB 'SCORE:',0

    STR_HEARTS  DB 'HEARTS:',0
    NUM_BUF     DB 6 DUP(0)            ; scratch for score-to-ASCII

    WORD_BASE   DW 0                   ; saved offset of current correct word
    GLOBAL_IDX  DW 0                   ; global word index (safe across calls)
    SCRAMBLE_OFF DW 0                  ; pre-computed scramble table offset

    ; --- Echo save buffer for clean backspace ---
    ECHO_COL  DB 111
    ECHO_ROW  DB 141
    ECHO_XW   DW 0
    ECHO_IDX  DB 0
    ECHO_CHR  DB 0
    ECHO_SAVE DB 1024 DUP(0)       ; 16 slots × 64 bytes

.CODE
    ; --- GFX procs ---
    EXTRN GFX_LOAD_BG:PROC, GFX_CLEAR:PROC
    EXTRN GFX_DRAW_CHAR:PROC, GFX_DRAW_STRING:PROC
    EXTRN GFX_DRAW_SPRITE:PROC

    ; --- Input procs ---
    EXTRN INP_WAIT_KEY:PROC

    ; --- Audio procs ---
    EXTRN SND_PLAY_PATTERN:PROC

    PUBLIC SCR_ROUND_RUN, SCR_JUDGE_RUN

; ================================================================
; NUM_TO_STR — Convert 16-bit unsigned to decimal ASCII.
;   In:  AX = number (0–65535)
;        ES:DI = dest buffer (6 bytes min)
;   Out: buffer null-terminated; ES:DI advanced past string
;   Preserves: BX, CX, DX
;   Clobbers:  AX, DI
; ================================================================
NUM_TO_STR PROC
    PUSH BX
    PUSH CX
    PUSH DX

    OR   AX, AX
    JNZ  NTS_DIVIDE

    MOV  BYTE PTR ES:[DI], '0'
    MOV  BYTE PTR ES:[DI+1], 0
    JMP  NTS_DONE

NTS_DIVIDE:
    XOR  CX, CX

NTS_PUSH:
    XOR  DX, DX
    MOV  BX, 10
    DIV  BX
    PUSH DX
    INC  CX
    OR   AX, AX
    JNZ  NTS_PUSH

NTS_POP:
    POP  DX
    ADD  DL, '0'
    MOV  ES:[DI], DL
    INC  DI
    LOOP NTS_POP

    MOV  BYTE PTR ES:[DI], 0

NTS_DONE:
    POP  DX
    POP  CX
    POP  BX
    RET
NUM_TO_STR ENDP

; ================================================================
; STR_COMPARE — Compare DS:SI word vs ES:DI user input.
;   In:  DS:SI = correct word (null-terminated)
;        ES:DI = user input (null-terminated)
;   Out: ZF=1 if match, ZF=0 if mismatch
;   Preserves: BX, CX, DX
;   Clobbers:  AX, SI, DI
; ================================================================
STR_COMPARE PROC
SCO_LOOP:
    MOV  AL, [SI]
    MOV  AH, ES:[DI]
    CMP  AL, AH
    JNE  SCO_DONE
    OR   AL, AL
    JZ   SCO_DONE
    INC  SI
    INC  DI
    JMP  SCO_LOOP
SCO_DONE:
    RET
STR_COMPARE ENDP

; ================================================================
; SCR_ROUND_RUN — Play one round for all NUM_PLAYERS players.
;   Reads:  CURRENT_WORD, DIFFICULTY, NUM_PLAYERS, word lists
;   Writes: PLAYER_RESULTS[], PLAYER_TIMES[], CURRENT_STATE
;   Flow:   clear → compute idx → sound → player loop
;           (bg → sprite → scramble → input per player) → STATE_JUDGE
;   Preserves: BX, CX, DX, SI, DI, BP
;   Clobbers:  AX
; ================================================================
SCR_ROUND_RUN PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    MOV  AX, @DATA
    MOV  DS, AX

    ; --- 1. Clear screen (black fallback if BG_ROUND.BIN missing) ---
    MOV  AL, 0
    CALL GFX_CLEAR

    ; --- 2. Compute global word index = DIFFICULTY * 10 + CURRENT_WORD ---
    MOV  AL, DIFFICULTY
    MOV  AH, 0
    MOV  BX, WORDS_PER_TIER
    MUL  BX                      ; AX = DIFFICULTY * 10
    MOV  BL, CURRENT_WORD
    MOV  BH, 0
    ADD  AX, BX                  ; AX = global index (0..29)
    MOV  GLOBAL_IDX, AX          ; preserve in memory (safe across calls)
    MOV  CL, 4
    SHL  AX, CL                  ; AX = offset into SCRAMBLE_TABLE
    MOV  SCRAMBLE_OFF, AX        ; save final offset now

    ; --- 3. Resolve correct word address ---
    ; SI = TIER_TABLE[DIFFICULTY*2] + CURRENT_WORD * WORD_RECORD_SIZE
    MOV  BL, DIFFICULTY
    MOV  BH, 0
    SHL  BX, 1                   ; word-indexed table
    MOV  SI, [TIER_TABLE+BX]     ; DS:SI = tier base
    MOV  AL, CURRENT_WORD
    MOV  AH, 0
    MOV  CX, WORD_RECORD_SIZE
    MUL  CX                      ; AX = CURRENT_WORD * 16
    ADD  SI, AX                  ; DS:SI = correct word string
    MOV  WORD_BASE, SI           ; save for comparison in player loop

    ; --- 4. Play word sound ---
    MOV  SI, GLOBAL_IDX         ; load global word index for sound lookup
    SHL  SI, 1                  ; *2 (word-indexed table)
    MOV  SI, [SOUND_TABLE + SI] ; DS:SI = pattern pointer
    CALL SND_PLAY_PATTERN

    ; --- 5. Player input loop ---
    MOV  CURRENT_PLAYER, 0

SRR_PLAYER_LOOP:
    ; --- Clear screen + reload background ---
    MOV  AL, 0
    CALL GFX_CLEAR                ; black fallback if BG_ROUND.BIN missing
    LEA  DX, BG_ROUND
    CALL GFX_LOAD_BG              ; ES = A000h

    ; --- Draw word sprite ---
    MOV  AX, GLOBAL_IDX
    MOV  CX, SPRITE_SIZE        ; 1024
    MUL  CX                     ; DX:AX = index * 1024 (DX=0)
    MOV  SI, AX
    ADD  SI, OFFSET SPRITE_TABLE ; DS:SI = sprite pixel data
    MOV  BX, 144                ; x (centered)
    MOV  DX, 35                 ; y
    CALL GFX_DRAW_SPRITE

    ; --- Draw scramble hint ---
    LEA  SI, STR_HINT
    MOV  BL, 6                   ; dark yellow
    MOV  CX, 100
    MOV  DX, 80
    CALL GFX_DRAW_STRING         ; clobbers AX! reload offset after

    MOV  AX, SCRAMBLE_OFF        ; reload after GFX clobbers AX
    LEA  SI, SCRAMBLE_TABLE
    ADD  SI, AX                  ; DS:SI = scrambled word
    MOV  BL, 1                   ; dark blue
    MOV  CX, 148
    MOV  DX, 80
    CALL GFX_DRAW_STRING

    ; --- 7a. "PLAYER N" banner (skip in 1P for cleaner UI) ---
    CMP  NUM_PLAYERS, 1
    JE   SRR_SKIP_BANNER

    MOV  AL, CURRENT_PLAYER
    OR   AL, AL
    JNZ  SRR_P2_BANNER
    LEA  SI, STR_PLAYER1
    JMP  SRR_DRAW_BANNER
SRR_P2_BANNER:
    LEA  SI, STR_PLAYER2
SRR_DRAW_BANNER:
    MOV  BL, 1
    MOV  CX, 130
    MOV  DX, 92
    CALL GFX_DRAW_STRING

SRR_SKIP_BANNER:
    ; --- "YOUR TURN!" ---
    MOV  BL, 1
    LEA  SI, STR_YOUR_TURN
    MOV  CX, 130
    MOV  DX, 106
    CALL GFX_DRAW_STRING

    ; --- "TYPE IT:" ---
    MOV  BL, 1
    LEA  SI, STR_TYPE
    MOV  CX, 130
    MOV  DX, 120
    CALL GFX_DRAW_STRING

    ; --- 7b. Record start tick ---
    MOV  AH, 0
    INT  1Ah                     ; CX:DX = tick count (DX = low word)
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    SHL  BX, 1                   ; word-indexed
    MOV  PLAYER_TIMES[BX], DX    ; save start tick

    ; --- 7c. Read player input with real-time echo ---
    ; Echo char at (111 + BX*8, 141)
    ; Buffer addressed via DS:DI+BX (avoids ES clobber from GFX calls)
    LEA  DI, INPUT_BUFFER
    XOR  BX, BX                  ; BX = current length

SRR_CHAR_LOOP:
    CALL INP_WAIT_KEY            ; AL = ASCII, AH = scan
    CMP  AL, 13                  ; Enter?
    JNE  SRR_NOT_ENTER
    JMP  SRR_INPUT_DONE
SRR_NOT_ENTER:
    CMP  AL, 8                   ; Backspace?
    JE   SRR_BACKSPACE

    CMP  BX, 16                  ; max chars
    JAE  SRR_CHAR_LOOP

    ; Convert to uppercase
    CMP  AL, 'a'
    JB   SRR_STORE
    CMP  AL, 'z'
    JA   SRR_STORE
    SUB  AL, 32

SRR_STORE:
    MOV  [DI+BX], AL             ; store in buffer (DS:@DATA)
    MOV  ECHO_IDX, BL            ; save index for backspace
    MOV  ECHO_CHR, AL            ; save char (clobbered by save loop)

    ; Echo char — save ALL regs GFX clobbers
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES
    PUSH BX                      ; save index

    ; --- Save 8x8 background at (111 + idx*8, 141) ---
    SHL  BX, 1
    SHL  BX, 1
    SHL  BX, 1                   ; BX = idx * 8
    ADD  BX, 111
    MOV  ECHO_XW, BX             ; X = 111 + idx*8

    ; DI = Y*320 + X
    MOV  AX, 141
    MOV  DX, 320
    MUL  DX                      ; AX = 141*320
    ADD  AX, ECHO_XW
    MOV  DI, AX                  ; DI = VRAM offset

    ; SI = OFFSET ECHO_SAVE + idx*64
    MOV  AL, ECHO_IDX
    MOV  AH, 64
    MUL  AH                      ; AX = idx * 64
    LEA  SI, ECHO_SAVE
    ADD  SI, AX                  ; DS:SI = save slot

    ; Copy 8x8 from VRAM → save buffer
    PUSH ES
    MOV  AX, 0A000h
    MOV  ES, AX                  ; ES = video memory
    MOV  AH, 8                   ; 8 rows
SRR_SAV_ROW:
    MOV  CX, 8
SRR_SAV_COL:
    MOV  AL, ES:[DI]
    MOV  [SI], AL
    INC  DI
    INC  SI
    LOOP SRR_SAV_COL
    ADD  DI, 320-8
    DEC  AH
    JNZ  SRR_SAV_ROW
    POP  ES

    ; --- Draw character ---
    MOV  AL, ECHO_CHR            ; restore char
    MOV  CX, ECHO_XW
    MOV  DX, 141
    MOV  BL, 1                   ; dark blue
    CALL GFX_DRAW_CHAR

    POP  BX                      ; restore index
    POP  ES
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  AX

    INC  BX                      ; advance length
    JMP  SRR_CHAR_LOOP

SRR_BACKSPACE:
    OR   BX, BX
    JNZ  SRR_BS_DO               ; something to delete
    JMP  SRR_CHAR_LOOP           ; nothing — near jump
SRR_BS_DO:
    DEC  BX
    MOV  ECHO_IDX, BL            ; save idx for restore

    PUSH AX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    PUSH ES

    ; --- Restore 8x8 background from save buffer ---
    ; SI = OFFSET ECHO_SAVE + idx*64
    MOV  AL, ECHO_IDX
    MOV  AH, 64
    MUL  AH                      ; AX = idx * 64
    LEA  SI, ECHO_SAVE
    ADD  SI, AX                  ; DS:SI = save slot

    ; Compute X = 111 + idx*8
    MOV  AL, ECHO_IDX
    XOR  AH, AH
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1                   ; AX = idx * 8
    ADD  AX, 111                 ; AX = X

    ; DI = Y*320 + X
    MOV  DX, 141
    PUSH AX
    MOV  AX, 320
    MUL  DX                      ; AX = 141*320
    POP  DX                      ; DX = X
    ADD  AX, DX                  ; AX = Y*320 + X
    MOV  DI, AX

    ; Copy 8x8 from save buffer → VRAM
    MOV  AX, 0A000h
    MOV  ES, AX
    MOV  AH, 8
SRR_RST_ROW:
    MOV  CX, 8
SRR_RST_COL:
    MOV  AL, [SI]
    MOV  ES:[DI], AL
    INC  SI
    INC  DI
    LOOP SRR_RST_COL
    ADD  DI, 320-8
    DEC  AH
    JNZ  SRR_RST_ROW

    POP  ES
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  AX
    JMP  SRR_CHAR_LOOP

SRR_INPUT_DONE:
    MOV  BYTE PTR [DI+BX], 0    ; null terminate

    ; --- 7d. Compare input against correct word ---
    MOV  SI, WORD_BASE           ; DS:SI = correct word
    PUSH DS
    POP  ES                      ; ES = DS
    LEA  DI, INPUT_BUFFER        ; ES:DI = user input
    CALL STR_COMPARE
    JE   SRR_RIGHT

    ; Wrong answer
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    MOV  PLAYER_RESULTS[BX], 0
    JMP  SRR_NEXT

SRR_RIGHT:
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    MOV  PLAYER_RESULTS[BX], 1

    ; --- 7e. Compute elapsed ticks ---
    MOV  AH, 0
    INT  1Ah                     ; CX:DX = tick count
    SHL  BX, 1                   ; word-indexed
    MOV  AX, DX
    SUB  AX, PLAYER_TIMES[BX]    ; AX = elapsed ticks
    MOV  PLAYER_TIMES[BX], AX    ; store elapsed ticks

SRR_NEXT:
    INC  CURRENT_PLAYER
    MOV  AL, CURRENT_PLAYER
    CMP  AL, NUM_PLAYERS
    JAE  SRR_ALL_DONE
    JMP  SRR_PLAYER_LOOP
SRR_ALL_DONE:

    ; --- 8. Advance to JUDGE ---
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_JUDGE

    POP  BP
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    RET
SCR_ROUND_RUN ENDP

; ================================================================
; SCR_JUDGE_RUN — Judge all players, update scores/hearts.
;   Reads:  PLAYER_RESULTS[], PLAYER_TIMES[], CURRENT_WORD
;           DIFFICULTY, NUM_PLAYERS
;   Writes: SCORES[], HEARTS_ARR[], CURRENT_WORD, CURRENT_STATE
;   1P: sequential per-player loop (clear between each)
;   2P: shared screen — P1 left | P2 right with divider
;   Preserves: BX, CX, DX, SI, DI, BP
;   Clobbers:  AX
; ================================================================
SCR_JUDGE_RUN PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    MOV  AX, @DATA
    MOV  DS, AX

    CMP  NUM_PLAYERS, 2
    JNE  SJR_1P_PATH              ; 1P: continue below
    JMP  NEAR PTR SJR_2P_MODE     ; 2P: shared screen (out of short range)
SJR_1P_PATH:

    ; --- 1. Clear screen (black fallback if BG_ROUND.BIN missing) ---
    MOV  AL, 0
    CALL GFX_CLEAR

    ; --- 2. Per-player result loop ---
    MOV  CURRENT_PLAYER, 0

SJR_LOOP:
    ; --- Clear screen + reload background ---
    MOV  AL, 0
    CALL GFX_CLEAR                ; black fallback if BG_ROUND.BIN missing
    LEA  DX, BG_JUDGE
    CALL GFX_LOAD_BG              ; ES = A000h

    ; --- "PLAYER N" header (skip in 1P) ---
    CMP  NUM_PLAYERS, 1
    JE   SJR_CHECK_RESULT

    MOV  AL, CURRENT_PLAYER
    OR   AL, AL
    JNZ  SJR_P2_HEAD
    LEA  SI, STR_PLAYER1
    JMP  SJR_DRAW_HEAD
SJR_P2_HEAD:
    LEA  SI, STR_PLAYER2
SJR_DRAW_HEAD:
    MOV  BL, 1
    MOV  CX, 130
    MOV  DX, 30
    CALL GFX_DRAW_STRING

SJR_CHECK_RESULT:
    MOV  BL, CURRENT_PLAYER
    MOV  BH, 0
    CMP  PLAYER_RESULTS[BX], 1
    JNE  SJR_WRONG

    ; --- Correct answer ---
    PUSH BX                      ; save BX = byte index

    ; Draw "YES!"
    MOV  BL, 6                   ; dark yellow
    LEA  SI, STR_RIGHT
    MOV  CX, 120
    MOV  DX, 50
    CALL GFX_DRAW_STRING

    ; Compute score delta: 100 - (ticks * 2), min 10
    POP  BX                      ; BX = byte index
    PUSH BX
    SHL  BX, 1                   ; word index
    MOV  AX, PLAYER_TIMES[BX]    ; AX = elapsed ticks
    SHL  AX, 1                   ; AX = ticks * 2
    MOV  CX, 100
    SUB  CX, AX                  ; CX = 100 - (ticks * 2)
    CMP  CX, 10
    JGE  SJR_ADD_SCORE
    MOV  CX, 10                  ; minimum 10 points

SJR_ADD_SCORE:
    ADD  SCORES[BX], CX          ; add delta to total
    MOV  AX, SCORES[BX]          ; read score BEFORE GFX clobbers BX

    ; Draw "SCORE: " label
    PUSH AX                      ; save score value
    MOV  BL, 1
    LEA  SI, STR_SCORE
    MOV  CX, 120
    MOV  DX, 65
    CALL GFX_DRAW_STRING         ; clobbers BX, AX

    POP  AX                      ; AX = score value
    PUSH ES
    PUSH DS
    POP  ES                      ; ES = DS for NUM_TO_STR
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES                      ; ES = A000h
    MOV  BL, 1
    LEA  SI, NUM_BUF
    MOV  CX, 180
    MOV  DX, 65
    CALL GFX_DRAW_STRING

    POP  BX                      ; BX = byte index
    LEA  SI, SND_CORRECT_SFX
    CALL SND_PLAY_PATTERN
    JMP  SJR_NEXT_PLAYER

SJR_WRONG:
    ; --- Wrong answer: lose a heart ---
    DEC  HEARTS_ARR[BX]

    ; Draw "OOPS!"
    MOV  BL, 12                  ; red-ish
    LEA  SI, STR_WRONG
    MOV  CX, 120
    MOV  DX, 50
    CALL GFX_DRAW_STRING
    LEA  SI, SND_WRONG_SFX
    CALL SND_PLAY_PATTERN

SJR_NEXT_PLAYER:
    INC  CURRENT_PLAYER
    MOV  AL, CURRENT_PLAYER
    CMP  AL, NUM_PLAYERS
    JB   SJR_CONTINUE_LOOP        ; not done: loop back
    JMP  NEAR PTR SJR_LOOP_DONE   ; all done (out of short range)
SJR_CONTINUE_LOOP:
    JMP  SJR_LOOP

; ================================================================
; SJR_2P_MODE — 2-player judge: shared screen with divider
;   P1 on left, P2 on right, "|" divider at X=158
; ================================================================
SJR_2P_MODE:
    ; --- Clear screen + load background ---
    MOV  AL, 0
    CALL GFX_CLEAR
    LEA  DX, BG_JUDGE
    CALL GFX_LOAD_BG              ; ES = A000h

    ; ===== Player 1 (left side) =====

    ; Draw P1 header
    LEA  SI, STR_PLAYER1
    MOV  BL, 1
    MOV  CX, 75
    MOV  DX, 45
    CALL GFX_DRAW_STRING

    ; Check P1 result
    CMP  PLAYER_RESULTS, 1        ; PLAYER_RESULTS[0]
    JNE  SJR_2P_P1_WRONG

    ; --- P1 correct ---
    LEA  SI, STR_RIGHT
    MOV  BL, 6                    ; dark yellow
    MOV  CX, 80
    MOV  DX, 65
    CALL GFX_DRAW_STRING

    ; Compute P1 score delta
    MOV  AX, PLAYER_TIMES         ; P1 time (word at offset 0)
    SHL  AX, 1                    ; AX = ticks * 2
    MOV  CX, 100
    SUB  CX, AX                   ; CX = 100 - (ticks * 2)
    CMP  CX, 10
    JGE  SJR_2P_P1_ADD
    MOV  CX, 10                   ; minimum 10 points
SJR_2P_P1_ADD:
    ADD  SCORES, CX               ; SCORES[0] += delta

    ; Draw "SCORE:" label
    LEA  SI, STR_SCORE
    MOV  BL, 1
    MOV  CX, 65
    MOV  DX, 80
    CALL GFX_DRAW_STRING

    ; Draw P1 score value
    MOV  AX, SCORES
    PUSH ES
    PUSH DS
    POP  ES                       ; ES = DS for NUM_TO_STR
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES                       ; ES = A000h
    LEA  SI, NUM_BUF
    MOV  BL, 1
    MOV  CX, 130
    MOV  DX, 80
    CALL GFX_DRAW_STRING
    LEA  SI, SND_CORRECT_SFX
    CALL SND_PLAY_PATTERN
    JMP  SJR_2P_DIVIDER

SJR_2P_P1_WRONG:
    DEC  HEARTS_ARR                ; HEARTS_ARR[0]--
    LEA  SI, STR_WRONG
    MOV  BL, 12                   ; red-ish
    MOV  CX, 80
    MOV  DX, 65
    CALL GFX_DRAW_STRING
    LEA  SI, SND_WRONG_SFX
    CALL SND_PLAY_PATTERN

    ; ===== Divider =====
SJR_2P_DIVIDER:
    MOV  AL, '|'
    MOV  BL, 1
    MOV  CX, 158
    MOV  DX, 45
    CALL GFX_DRAW_CHAR
    MOV  AL, '|'
    MOV  CX, 158
    MOV  DX, 60
    CALL GFX_DRAW_CHAR
    MOV  AL, '|'
    MOV  CX, 158
    MOV  DX, 75
    CALL GFX_DRAW_CHAR

    ; ===== Player 2 (right side) =====

    ; Draw P2 header
    LEA  SI, STR_PLAYER2
    MOV  BL, 1
    MOV  CX, 195
    MOV  DX, 45
    CALL GFX_DRAW_STRING

    ; Check P2 result
    CMP  PLAYER_RESULTS+1, 1      ; PLAYER_RESULTS[1]
    JNE  SJR_2P_P2_WRONG

    ; --- P2 correct ---
    LEA  SI, STR_RIGHT
    MOV  BL, 6                    ; dark yellow
    MOV  CX, 200
    MOV  DX, 65
    CALL GFX_DRAW_STRING

    ; Compute P2 score delta
    MOV  AX, PLAYER_TIMES+2       ; P2 time (word at offset 2)
    SHL  AX, 1                    ; AX = ticks * 2
    MOV  CX, 100
    SUB  CX, AX                   ; CX = 100 - (ticks * 2)
    CMP  CX, 10
    JGE  SJR_2P_P2_ADD
    MOV  CX, 10                   ; minimum 10 points
SJR_2P_P2_ADD:
    ADD  SCORES+2, CX             ; SCORES[1] += delta

    ; Draw "SCORE:" label
    LEA  SI, STR_SCORE
    MOV  BL, 1
    MOV  CX, 185
    MOV  DX, 80
    CALL GFX_DRAW_STRING

    ; Draw P2 score value
    MOV  AX, SCORES+2
    PUSH ES
    PUSH DS
    POP  ES                       ; ES = DS for NUM_TO_STR
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES                       ; ES = A000h
    LEA  SI, NUM_BUF
    MOV  BL, 1
    MOV  CX, 250
    MOV  DX, 80
    CALL GFX_DRAW_STRING
    LEA  SI, SND_CORRECT_SFX
    CALL SND_PLAY_PATTERN
    JMP  SJR_2P_DONE

SJR_2P_P2_WRONG:
    DEC  HEARTS_ARR+1              ; HEARTS_ARR[1]--
    LEA  SI, STR_WRONG
    MOV  BL, 12                   ; red-ish
    MOV  CX, 200
    MOV  DX, 65
    CALL GFX_DRAW_STRING
    LEA  SI, SND_WRONG_SFX
    CALL SND_PLAY_PATTERN

SJR_2P_DONE:

SJR_LOOP_DONE:
    ; --- 3. Show current total scores ---
    ; Route: 1P uses x=120 column, 2P uses x=70 column (left-shifted)
    CMP  NUM_PLAYERS, 2
    JE   SJR_DISPLAY_2P

    ; === 1P score display (x=120, aligned with YES!/SCORE: above) ===
    MOV  BL, 1
    LEA  SI, STR_SCORE
    MOV  CX, 120
    MOV  DX, 100
    CALL GFX_DRAW_STRING

    ; P1 score
    MOV  AX, SCORES
    PUSH ES
    PUSH DS
    POP  ES
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES
    LEA  SI, NUM_BUF
    MOV  BL, 1
    MOV  CX, 188
    MOV  DX, 100
    CALL GFX_DRAW_STRING

    ; Hearts
    LEA  SI, STR_HEARTS
    MOV  BL, 1
    MOV  CX, 120
    MOV  DX, 115
    CALL GFX_DRAW_STRING

    MOV  CX, 192
    MOV  DX, 115
    MOV  AL, HEARTS_ARR
    ADD  AL, '0'
    MOV  BL, 1
    CALL GFX_DRAW_CHAR
    JMP  SJR_WAIT_KEY

    ; === 2P score display (x=70, left-shifted ~30px) ===
SJR_DISPLAY_2P:
    MOV  BL, 1
    LEA  SI, STR_SCORE
    MOV  CX, 70
    MOV  DX, 115
    CALL GFX_DRAW_STRING

    ; P1 score
    MOV  AX, SCORES
    PUSH ES
    PUSH DS
    POP  ES
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES
    LEA  SI, NUM_BUF
    MOV  BL, 1
    MOV  CX, 138
    MOV  DX, 115
    CALL GFX_DRAW_STRING

    ; P2 score
    MOV  BL, 1
    LEA  SI, STR_VS
    MOV  CX, 165
    MOV  DX, 115
    CALL GFX_DRAW_STRING

    MOV  AX, SCORES+2
    PUSH ES
    PUSH DS
    POP  ES
    LEA  DI, NUM_BUF
    CALL NUM_TO_STR
    POP  ES
    LEA  SI, NUM_BUF
    MOV  BL, 1
    MOV  CX, 195
    MOV  DX, 115
    CALL GFX_DRAW_STRING

    ; Hearts
    LEA  SI, STR_HEARTS
    MOV  BL, 1
    MOV  CX, 70
    MOV  DX, 130
    CALL GFX_DRAW_STRING

    ; P1 hearts count
    MOV  CX, 142
    MOV  DX, 130
    MOV  AL, HEARTS_ARR
    ADD  AL, '0'
    MOV  BL, 1
    CALL GFX_DRAW_CHAR

    ; P2 hearts
    MOV  CX, 195
    MOV  DX, 130
    MOV  AL, HEARTS_ARR+1
    ADD  AL, '0'
    CALL GFX_DRAW_CHAR

SJR_WAIT_KEY:
    ; --- 4. Wait for keypress ---
    CALL INP_WAIT_KEY

    ; --- 5. Advance word ---
    INC  CURRENT_WORD

    ; --- 6. End condition checks ---
    ; (a) Any player at 0 hearts?
    CMP  HEARTS_ARR, 0
    JE   SJR_END
    CMP  NUM_PLAYERS, 2
    JB   SJR_CHECK_WORDS
    CMP  HEARTS_ARR+1, 0
    JE   SJR_END

SJR_CHECK_WORDS:
    ; (b) All words consumed?
    MOV  AL, CURRENT_WORD
    CMP  AL, WORDS_PER_TIER
    JAE  SJR_END

    ; --- Continue playing ---
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_ROUND
    JMP  SJR_EXIT

SJR_END:
    MOV  CURRENT_STATE, STATE_SCORE

SJR_EXIT:
    POP  BP
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    RET
SCR_JUDGE_RUN ENDP

END
