; SCRINTRO.ASM — Intro flow screens (v1.4 spec)
; Public: SCR_TITLE_RUN, SCR_LOGIN_RUN, SCR_MODE_RUN,
;         SCR_NAME_RUN, SCR_DIFF_RUN, SCR_INSTR_RUN

.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    EXTRN CURRENT_STATE:BYTE
    EXTRN NUM_PLAYERS:BYTE, CURRENT_PLAYER:BYTE
    EXTRN DIFFICULTY:BYTE
    EXTRN PLAYER_NAMES:BYTE
    EXTRN SESSION_USER:BYTE, USER_TABLE:BYTE, USER_COUNT:BYTE
    EXTRN LOGIN_RETRIES:BYTE
    EXTRN USERNAME_BUF:BYTE, PASSWORD_BUF:BYTE

    EXTRN STR_TITLE:BYTE, STR_INSTR:BYTE
    EXTRN STR_DIFF_PROMPT:BYTE, STR_EASY:BYTE, STR_MED:BYTE, STR_HARD:BYTE
    EXTRN STR_MODE_PROMPT:BYTE, STR_1P:BYTE, STR_2P:BYTE
    EXTRN STR_PLAYER1:BYTE, STR_PLAYER2:BYTE
    EXTRN BG_TITLE:BYTE, BG_MODE:BYTE, BG_NAME:BYTE, BG_DIFF:BYTE, BG_INSTR:BYTE
    EXTRN BG_LOGIN:BYTE

    PROMPT_KEY    DB 'PRESS ANY KEY',0
    PROMPT_NAME   DB 'ENTER INITIALS:',0
    STR_LOGIN     DB 'LOGIN',0
    STR_USERNAME  DB 'NAME (3 CHARS):',0
    STR_PASSWORD  DB 'PASSWORD (5 CHARS):',0
    STR_WELCOME   DB 'WELCOME BACK!',0
    STR_NEW_USER  DB 'NEW PLAYER!',0
    STR_WRONG_PW  DB 'WRONG PASSWORD!',0
    STR_USERS_FULL DB 'USERS FULL!',0

    ; SCI_ECHO_INPUT scratch variables
    ECHO_COL  DB 0
    ECHO_ROW  DB 0
    ECHO_CLR  DB 0
    ECHO_CHAR DB 0
    ECHO_IDX  DB 0
    ECHO_XW   DW 0
    ECHO_SAVE DB 320 DUP(0)   ; 5 slots × 64 bytes bg save

    EXTRN SND_TITLE_JINGLE:WORD

.CODE
    EXTRN GFX_LOAD_BG:PROC, GFX_CLEAR:PROC, GFX_DRAW_STRING:PROC
    EXTRN GFX_DRAW_CHAR:PROC
    EXTRN INP_WAIT_KEY:PROC, INP_READ_STRING:PROC
    EXTRN SND_PLAY_PATTERN:PROC, SND_DELAY:PROC
    EXTRN USER_AUTH:PROC, USER_SAVE:PROC

    PUBLIC SCR_TITLE_RUN, SCR_LOGIN_RUN, SCR_MODE_RUN
    PUBLIC SCR_NAME_RUN, SCR_DIFF_RUN, SCR_INSTR_RUN
    PUBLIC SCI_ECHO_INPUT

;-----------------------------------------------------------
; SCI_ECHO_INPUT — Read string with GFX_DRAW_CHAR echo at pixel position.
; Replaces INP_READ_STRING when screen-positioned echo is needed.
; In:  BL = echo X start, BH = echo color, DL = echo Y
;      ES:DI = buffer, CX = max length
; Out: buffer null-terminated, CX = actual length
; Preserves: SI, DI, BP
; Clobbers: AX, BX, CX, DX
;-----------------------------------------------------------
SCI_ECHO_INPUT PROC
    PUSH BP
    PUSH SI
    PUSH DI

    MOV  ECHO_CLR, BH        ; save echo color
    MOV  ECHO_ROW, DL        ; save echo Y
    MOV  ECHO_COL, BL        ; save echo start X
    XOR  BX, BX              ; BX = char index

SEI_LOOP:
    CALL INP_WAIT_KEY        ; AL = char, AH = scancode
    CMP  AL, 13              ; Enter?
    JNE  SEI_NOT_ENTER
    JMP  SEI_DONE
SEI_NOT_ENTER:
    CMP  AL, 8               ; Backspace?
    JNE  SEI_NOT_BACK
    JMP  SEI_BACK
SEI_NOT_BACK:
    CMP  BX, CX              ; buffer full? (unsigned)
    JAE  SEI_LOOP

    ; Uppercase
    CMP  AL, 'a'
    JB   SEI_STORE
    CMP  AL, 'z'
    JA   SEI_STORE
    SUB  AL, 32

SEI_STORE:
    MOV  ES:[DI+BX], AL      ; store in buffer (ES=DS from caller)
    MOV  ECHO_CHAR, AL       ; save char for echo
    MOV  ECHO_IDX, BL        ; save idx for bg save offset

    PUSH BX                  ; char index
    PUSH CX                  ; max length
    PUSH ES                  ; ES=DS
    PUSH SI
    PUSH DI

    ; --- Save 8x8 background at echo position ---
    ; Compute echo X = ECHO_COL + idx*8
    MOV  AL, ECHO_IDX
    XOR  AH, AH
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1               ; AX = idx * 8
    MOV  CL, ECHO_COL
    XOR  CH, CH
    ADD  AX, CX              ; AX = echo X
    MOV  ECHO_XW, AX         ; stash for GFX_DRAW_CHAR

    ; DI = Y*320 + X (in A000h)
    MOV  AX, 320
    MOV  DL, ECHO_ROW
    XOR  DH, DH
    MUL  DX                  ; AX = Y*320 (fits 16-bit)
    ADD  AX, ECHO_XW         ; AX = Y*320 + X
    MOV  DI, AX

    ; SI = ECHO_SAVE + idx*64
    MOV  AL, ECHO_IDX
    MOV  AH, 64
    MUL  AH                  ; AX = idx * 64
    LEA  SI, ECHO_SAVE
    ADD  SI, AX

    ; Read 8x8 from A000h:ES:DI → DS:SI
    PUSH ES                  ; stash original ES (DS)
    MOV  AX, 0A000h
    MOV  ES, AX
    MOV  AH, 8               ; 8 rows
SEI_SAV_ROW:
    MOV  CX, 8               ; 8 cols
SEI_SAV_COL:
    MOV  AL, ES:[DI]
    MOV  [SI], AL
    INC  DI
    INC  SI
    LOOP SEI_SAV_COL
    ADD  DI, 320-8
    DEC  AH
    JNZ  SEI_SAV_ROW
    POP  ES                  ; restore ES=DS

    ; --- Draw character ---
    ; DI, SI, ES, CX, BX still on stack

    MOV  CX, ECHO_XW         ; CX = echo X
    MOV  DL, ECHO_ROW
    XOR  DH, DH
    MOV  BL, ECHO_CLR
    MOV  AL, ECHO_CHAR
    CALL GFX_DRAW_CHAR       ; ES → A000h, clobbers DI, SI

    POP  DI                  ; restore buffer pointer
    POP  SI                  ; restore caller SI
    POP  ES                  ; restore ES=DS
    POP  CX                  ; restore max length
    POP  BX                  ; restore char index
    INC  BX
    JMP  SEI_LOOP

SEI_BACK:
    OR   BX, BX
    JNZ  SEI_DO_BACK          ; something to delete
    JMP  SEI_LOOP             ; nothing to delete
SEI_DO_BACK:
    DEC  BX                  ; back up one char
    MOV  ECHO_IDX, BL        ; save idx for restore offset

    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    PUSH ES

    ; --- Restore 8x8 background from save buffer ---
    ; SI = ECHO_SAVE + idx*64
    MOV  AL, ECHO_IDX
    MOV  AH, 64
    MUL  AH                  ; AX = idx * 64
    LEA  SI, ECHO_SAVE
    ADD  SI, AX              ; DS:SI = save buffer slot

    ; Compute echo X = ECHO_COL + idx*8
    MOV  AL, ECHO_IDX
    XOR  AH, AH
    SHL  AX, 1
    SHL  AX, 1
    SHL  AX, 1               ; AX = idx * 8
    MOV  CL, ECHO_COL
    XOR  CH, CH
    ADD  AX, CX              ; AX = echo X

    ; DI = Y*320 + X (in A000h)
    PUSH AX                  ; stash echo X
    MOV  AX, 320
    MOV  DL, ECHO_ROW
    XOR  DH, DH
    MUL  DX                  ; AX = Y*320
    POP  DX                  ; DX = echo X
    ADD  AX, DX              ; AX = Y*320 + X
    MOV  DI, AX

    ; Write 8x8 from DS:SI → A000h:ES:DI
    MOV  AX, 0A000h
    MOV  ES, AX
    MOV  AH, 8
SEI_RST_ROW:
    MOV  CX, 8
SEI_RST_COL:
    MOV  AL, [SI]
    MOV  ES:[DI], AL
    INC  SI
    INC  DI
    LOOP SEI_RST_COL
    ADD  DI, 320-8
    DEC  AH
    JNZ  SEI_RST_ROW

    POP  ES
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    JMP  SEI_LOOP

SEI_DONE:
    MOV  BYTE PTR ES:[DI+BX], 0   ; null-terminate
    MOV  CX, BX              ; return length

    POP  DI
    POP  SI
    POP  BP
    RET
SCI_ECHO_INPUT ENDP

;-----------------------------------------------------------
; SCR_TITLE_RUN — Title screen. Any key → STATE_LOGIN.
; v1.3: jingle call deferred (SND_TITLE_JINGLE not in DATA.ASM yet).
; In:  (none) — reads BG_TITLE, STR_TITLE, PROMPT_KEY
; Out: CURRENT_STATE = STATE_LOGIN; ES = A000h
; Preserves: BP, SI, DI
; Clobbers: AX, BX, CX, DX
;-----------------------------------------------------------
SCR_TITLE_RUN PROC
    PUSH BP
    PUSH SI
    PUSH DI

    ; DS = @DATA inherited from caller

    MOV  AL, 0                   ; clear bg (fallback when .BIN missing)
    CALL GFX_CLEAR
    LEA  DX, BG_TITLE            ; DS:DX = filename
    CALL GFX_LOAD_BG             ; ES = A000h after call

    ; --- Title jingle ---
    LEA  SI, SND_TITLE_JINGLE
    CALL SND_PLAY_PATTERN

    CALL INP_WAIT_KEY

    MOV  CURRENT_STATE, STATE_LOGIN

    POP  DI
    POP  SI
    POP  BP
    RET
SCR_TITLE_RUN ENDP

;-----------------------------------------------------------
; SCR_LOGIN_RUN — Login screen. Auth against USERS.DAT.
; Handles retry loop and welcome/error messages internally.
; In:  (none) — reads USER_TABLE, USER_COUNT
; Out: CURRENT_STATE = STATE_MODE (success) or STATE_TITLE (bail)
;      SESSION_USER written; USER_TABLE may be modified; ES = A000h
; Preserves: BP, SI, DI
; Clobbers: AX, BX, CX, DX
;-----------------------------------------------------------
SCR_LOGIN_RUN PROC
    PUSH BP
    PUSH SI
    PUSH DI

    MOV  LOGIN_RETRIES, 0

SLR_RENDER:
    MOV  AL, 0                   ; black fallback
    CALL GFX_CLEAR               ; ES = A000h after call
    LEA  DX, BG_LOGIN
    CALL GFX_LOAD_BG             ; ES = A000h after call

SLR_PROMPT:
    ; --- Read username (3 chars) ---
    PUSH DS
    POP  ES                      ; ES = DS for buffer access
    LEA  DI, USERNAME_BUF
    MOV  BL, 167                 ; echo X
    MOV  BH, 1                   ; dark blue
    MOV  DL, 97                  ; echo Y
    MOV  CX, 3
    CALL SCI_ECHO_INPUT

    ; --- Read password (5 chars) ---
    PUSH DS
    POP  ES
    LEA  DI, PASSWORD_BUF
    MOV  BL, 167
    MOV  BH, 1
    MOV  DL, 118                 ; echo Y
    MOV  CX, 5
    CALL SCI_ECHO_INPUT

    ; --- Auth ---
    LEA  SI, USERNAME_BUF        ; DS:SI = username
    LEA  DI, PASSWORD_BUF        ; DS:DI = password
    CALL USER_AUTH               ; AX = 0(OK), 1(new), 2(wrong), 3(full)

    CMP  AX, 0
    JE   SLR_OK
    CMP  AX, 1
    JE   SLR_NEW
    CMP  AX, 3
    JE   SLR_FULL

    ; --- AX == 2: wrong password ---
    INC  LOGIN_RETRIES
    LEA  SI, STR_WRONG_PW
    MOV  BL, 12                  ; red-ish
    MOV  CX, 60
    MOV  DX, 150
    CALL GFX_DRAW_STRING
    MOV  CX, 1200
    CALL SND_DELAY

    MOV  AL, LOGIN_RETRIES
    CMP  AL, MAX_LOGIN_RETRIES
    JAE  SLR_BAIL_TITLE
    JMP  SLR_RENDER

SLR_FULL:
    LEA  SI, STR_USERS_FULL
    MOV  BL, 12
    MOV  CX, 60
    MOV  DX, 150
    CALL GFX_DRAW_STRING
    MOV  CX, 2000
    CALL SND_DELAY
    JMP  SLR_BAIL_TITLE

SLR_NEW:
    LEA  SI, STR_NEW_USER
    JMP  SLR_PROCEED

SLR_OK:
    LEA  SI, STR_WELCOME

SLR_PROCEED:
    MOV  BL, 10                  ; green-ish
    MOV  CX, 60
    MOV  DX, 150
    CALL GFX_DRAW_STRING

    ; --- Save SESSION_USER ← USERNAME_BUF ---
    PUSH DS
    POP  ES                      ; ES = DS
    LEA  SI, USERNAME_BUF
    LEA  DI, SESSION_USER
    MOV  CX, 3
    CLD
    REP  MOVSB                   ; ES:DI ← DS:SI, 3 bytes

    ; --- Persist USER_TABLE (rewrites file; no-op cost on auth-OK) ---
    CALL USER_SAVE

    MOV  CX, 1500
    CALL SND_DELAY

    MOV  CURRENT_STATE, STATE_MODE
    POP  DI
    POP  SI
    POP  BP
    RET

SLR_BAIL_TITLE:
    MOV  CURRENT_STATE, STATE_TITLE
    POP  DI
    POP  SI
    POP  BP
    RET
SCR_LOGIN_RUN ENDP

;-----------------------------------------------------------
; SCR_MODE_RUN — 1P or 2P select. Sets NUM_PLAYERS.
; v1.3: pre-fills PLAYER_NAMES[0] from SESSION_USER.
;       1P skips name entry (→ STATE_DIFF), 2P starts at Player 2.
; In:  (none) — reads SESSION_USER, BG_MODE, STR_MODE_PROMPT
; Out: NUM_PLAYERS, CURRENT_PLAYER, PLAYER_NAMES[0] set
;      CURRENT_STATE = STATE_DIFF (1P) or STATE_NAME (2P); ES = A000h
; Preserves: BP, SI, DI
; Clobbers: AX, BX, CX, DX
;-----------------------------------------------------------
SCR_MODE_RUN PROC
    PUSH BP
    PUSH SI
    PUSH DI

    MOV  AL, 0                   ; clear bg (fallback when .BIN missing)
    CALL GFX_CLEAR
    LEA  DX, BG_MODE
    CALL GFX_LOAD_BG             ; ES = A000h

SMR_WAIT:
    CALL INP_WAIT_KEY
    CMP  AL, '1'
    JE   SMR_1P
    CMP  AL, '2'
    JE   SMR_2P
    JMP  SMR_WAIT

SMR_1P:
    MOV  NUM_PLAYERS, 1
    JMP  SMR_PREFILL
SMR_2P:
    MOV  NUM_PLAYERS, 2

SMR_PREFILL:
    ; --- v1.3: Copy SESSION_USER → PLAYER_NAMES[0] ---
    PUSH DS
    POP  ES                      ; ES = DS
    LEA  SI, SESSION_USER
    LEA  DI, PLAYER_NAMES
    MOV  CX, 3
    CLD
    REP  MOVSB

    ; --- 1P: skip name entry (CURRENT_PLAYER stays 0) ---
    CMP  NUM_PLAYERS, 1
    JNE  SMR_2P_PATH
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_DIFF
    POP  DI
    POP  SI
    POP  BP
    RET

SMR_2P_PATH:
    ; 2P: enter name entry with CURRENT_PLAYER=1 (skip Player 1)
    MOV  CURRENT_PLAYER, 1
    MOV  CURRENT_STATE, STATE_NAME
    POP  DI
    POP  SI
    POP  BP
    RET
SCR_MODE_RUN ENDP

;-----------------------------------------------------------
; SCR_NAME_RUN — Read 3 initials for one player.
; Re-entrant via state machine: reads CURRENT_PLAYER, writes
; PLAYER_NAMES[CURRENT_PLAYER*3], increments CURRENT_PLAYER.
; Stays in STATE_NAME until all players done, then STATE_DIFF.
; In:  (none) — reads CURRENT_PLAYER, NUM_PLAYERS
; Out: PLAYER_NAMES[CP] written; CURRENT_PLAYER advanced
;      CURRENT_STATE = STATE_NAME (more players) or STATE_DIFF
; Preserves: BP, SI, DI
; Clobbers: AX, BX, CX, DX
;-----------------------------------------------------------
SCR_NAME_RUN PROC
    PUSH BP
    PUSH SI
    PUSH DI

    MOV  AL, 0                   ; clear bg (fallback when .BIN missing)
    CALL GFX_CLEAR
    LEA  DX, BG_NAME
    CALL GFX_LOAD_BG             ; ES = A000h

    ; --- Compute destination: PLAYER_NAMES + CURRENT_PLAYER*3 ---
    MOV  AL, CURRENT_PLAYER
    MOV  AH, 0
    MOV  CX, 3
    MUL  CX                       ; AX = CURRENT_PLAYER * 3
    LEA  DI, PLAYER_NAMES
    ADD  DI, AX                   ; DS:DI = name slot for this player

    ; --- Read 3 chars with echo at (132, 97) ---
    PUSH DS
    POP  ES                      ; ES = DS for buffer access
    MOV  BL, 132                 ; echo X
    MOV  BH, 1                   ; dark blue
    MOV  DL, 97                  ; echo Y
    MOV  CX, 3
    CALL SCI_ECHO_INPUT

    ; --- Advance CURRENT_PLAYER ---
    INC  CURRENT_PLAYER
    MOV  AL, CURRENT_PLAYER
    CMP  AL, NUM_PLAYERS
    JB   SNR_KEEP                 ; unsigned: more players remain

    ; All players done — reset and advance
    MOV  CURRENT_PLAYER, 0
    MOV  CURRENT_STATE, STATE_DIFF
    POP  DI
    POP  SI
    POP  BP
    RET

SNR_KEEP:
    ; Stay in STATE_NAME; STATE.ASM calls us again with new CURRENT_PLAYER
    POP  DI
    POP  SI
    POP  BP
    RET
SCR_NAME_RUN ENDP

;-----------------------------------------------------------
; SCR_DIFF_RUN — Difficulty select (1=Easy, 2=Medium, 3=Hard).
; In:  (none) — reads BG_DIFF, STR_DIFF_PROMPT, etc.
; Out: DIFFICULTY set; CURRENT_STATE = STATE_INSTR; ES = A000h
; Preserves: BP, SI, DI
; Clobbers: AX, BX, CX, DX
;-----------------------------------------------------------
SCR_DIFF_RUN PROC
    PUSH BP
    PUSH SI
    PUSH DI

    MOV  AL, 0                   ; clear bg (fallback when .BIN missing)
    CALL GFX_CLEAR
    LEA  DX, BG_DIFF
    CALL GFX_LOAD_BG             ; ES = A000h

SDR_WAIT:
    CALL INP_WAIT_KEY
    CMP  AL, '1'
    JE   SDR_EASY
    CMP  AL, '2'
    JE   SDR_MED
    CMP  AL, '3'
    JE   SDR_HARD
    JMP  SDR_WAIT

SDR_EASY:
    MOV  DIFFICULTY, DIFF_EASY
    JMP  SDR_DONE
SDR_MED:
    MOV  DIFFICULTY, DIFF_MED
    JMP  SDR_DONE
SDR_HARD:
    MOV  DIFFICULTY, DIFF_HARD

SDR_DONE:
    MOV  CURRENT_STATE, STATE_INSTR
    POP  DI
    POP  SI
    POP  BP
    RET
SCR_DIFF_RUN ENDP

;-----------------------------------------------------------
; SCR_INSTR_RUN — Show instructions. Any key → STATE_ROUND.
; In:  (none) — reads BG_INSTR, STR_INSTR
; Out: CURRENT_STATE = STATE_ROUND; ES = A000h
; Preserves: BP, SI, DI
; Clobbers: AX, BX, CX, DX
;-----------------------------------------------------------
SCR_INSTR_RUN PROC
    PUSH BP
    PUSH SI
    PUSH DI

    MOV  AL, 0                   ; clear bg (fallback when .BIN missing)
    CALL GFX_CLEAR
    LEA  DX, BG_INSTR
    CALL GFX_LOAD_BG             ; ES = A000h

    CALL INP_WAIT_KEY

    MOV  CURRENT_STATE, STATE_ROUND
    POP  DI
    POP  SI
    POP  BP
    RET
SCR_INSTR_RUN ENDP

END
