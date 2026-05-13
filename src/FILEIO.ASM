; FILEIO.ASM — Leaderboard & User Account Persistence (v1.3)
; 3 leaderboard procs (unchanged from v1.2) + 3 user-account procs (v1.3).
; All file I/O via INT 21h DOS services.
; Uses FN_SCORES / FN_USERS filename strings from DATA.ASM.
; All persistent buffers (LEADERBOARD, USER_TABLE, USER_COUNT) are
; EXTRN from MAIN.ASM.

.MODEL SMALL

.DATA
    INCLUDE SHARED.INC
    EXTRN LEADERBOARD:BYTE
    EXTRN USER_TABLE:BYTE, USER_COUNT:BYTE
    ; Filename strings (local — only FILEIO uses these)
    FN_SCORES DB 'SCORES.DAT',0
    FN_USERS  DB 'USERS.DAT',0

    FILE_HANDLE   DW 0

.CODE
    PUBLIC FILE_LOAD_SCORES, FILE_SAVE_SCORES, FILE_INSERT_SCORE
    PUBLIC USER_LOAD, USER_AUTH, USER_SAVE

;---------------------------------------------------------------
; FILE_LOAD_SCORES — Load SCORES.DAT into LEADERBOARD.
; If file missing or short, LEADERBOARD is zero-filled.
; In:  none
; Out: LEADERBOARD populated (or zeroed)
; Preserves: nothing critical
; Clobbers:  AX, BX, CX, DX, DI
;---------------------------------------------------------------
FILE_LOAD_SCORES PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    ; Zero LEADERBOARD (40 bytes)
    PUSH DS
    POP  ES                    ; ES = DS for STOSB
    LEA  DI, LEADERBOARD
    MOV  CX, LB_MAX_ENTRIES * LB_ENTRY_SIZE
    XOR  AL, AL
    CLD
    REP  STOSB

    ; Open SCORES.DAT for reading
    MOV  AH, 3Dh
    MOV  AL, 0                 ; read-only
    LEA  DX, FN_SCORES         ; DS:DX = "SCORES.DAT",0
    INT  21h
    JC   FLS_DONE              ; file missing → LEADERBOARD stays zeroed

    MOV  FILE_HANDLE, AX

    ; Read 40 bytes into LEADERBOARD
    MOV  AH, 3Fh
    MOV  BX, FILE_HANDLE
    MOV  CX, LB_MAX_ENTRIES * LB_ENTRY_SIZE
    LEA  DX, LEADERBOARD       ; DS:DX = buffer
    INT  21h

    ; Close file
    MOV  AH, 3Eh
    MOV  BX, FILE_HANDLE
    INT  21h

FLS_DONE:
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
FILE_LOAD_SCORES ENDP

;---------------------------------------------------------------
; FILE_SAVE_SCORES — Write LEADERBOARD to SCORES.DAT.
; In:  LEADERBOARD valid
; Out: SCORES.DAT created/overwritten with 40 bytes
; Preserves: nothing critical
; Clobbers:  AX, BX, CX, DX
;---------------------------------------------------------------
FILE_SAVE_SCORES PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Create/truncate SCORES.DAT
    MOV  AH, 3Ch
    XOR  CX, CX                ; normal attribute
    LEA  DX, FN_SCORES
    INT  21h
    JC   FSS_DONE

    MOV  FILE_HANDLE, AX

    ; Write 40 bytes from LEADERBOARD
    MOV  AH, 40h
    MOV  BX, FILE_HANDLE
    MOV  CX, LB_MAX_ENTRIES * LB_ENTRY_SIZE
    LEA  DX, LEADERBOARD
    INT  21h

    ; Close file
    MOV  AH, 3Eh
    MOV  BX, FILE_HANDLE
    INT  21h

FSS_DONE:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
FILE_SAVE_SCORES ENDP

;---------------------------------------------------------------
; FILE_INSERT_SCORE — Insert entry into sorted (descending) LEADERBOARD.
; Walks entries to find slot: empty OR new score > existing score.
; Shifts entries down to make room, inserts at found position.
; In:  DS:SI = name (3 uppercase ASCII bytes)
;      BX    = score (16-bit unsigned)
;      AL    = difficulty (0=Easy, 1=Med, 2=Hard)
; Out: LEADERBOARD updated if score qualifies
; Preserves: SI, DI
; Clobbers:  AX, BX, CX, DX, BP, flags
;---------------------------------------------------------------
FILE_INSERT_SCORE PROC
    PUSH SI
    PUSH DI
    PUSH BP

    ; Save score and difficulty for later write
    ; DL is safe — shift loop clobbers AX, not DX
    MOV  BP, BX                ; BP = score
    MOV  DL, AL                ; DL = difficulty

    ; Search for insertion point (DI = byte offset into LEADERBOARD)
    XOR  DI, DI

FIS_SEEK:
    CMP  DI, LB_MAX_ENTRIES * LB_ENTRY_SIZE
    JAE  FIS_DONE              ; past end → doesn't qualify

    ; Empty slot?
    CMP  BYTE PTR [LEADERBOARD + DI], 0
    JE   FIS_SHIFT             ; empty → insert here

    ; New score > existing score? (descending order)
    CMP  BP, WORD PTR [LEADERBOARD + DI + 3]
    JA   FIS_SHIFT             ; BP > existing → insert here

    ADD  DI, LB_ENTRY_SIZE
    JMP  FIS_SEEK

FIS_SHIFT:
    ; Shift entries down from bottom up to DI
    ; Start at last entry offset, copy each entry one slot down
    MOV  CX, (LB_MAX_ENTRIES - 1) * LB_ENTRY_SIZE   ; CX = 32

FIS_SHIFT_LOOP:
    CMP  CX, DI
    JBE  FIS_WRITE             ; reached insertion point

    ; Copy entry at [CX-8] to [CX]
    PUSH SI                    ; preserve name pointer during copy
    MOV  SI, CX
    SUB  SI, LB_ENTRY_SIZE
    ADD  SI, OFFSET LEADERBOARD

    MOV  AX, [SI]
    MOV  [SI + 8], AX
    MOV  AX, [SI + 2]
    MOV  [SI + 10], AX
    MOV  AX, [SI + 4]
    MOV  [SI + 12], AX
    MOV  AX, [SI + 6]
    MOV  [SI + 14], AX
    POP  SI

    SUB  CX, LB_ENTRY_SIZE
    JMP  FIS_SHIFT_LOOP

FIS_WRITE:
    ; Write name (3 bytes from DS:SI)
    MOV  AL, [SI]
    MOV  [LEADERBOARD + DI], AL
    MOV  AL, [SI + 1]
    MOV  [LEADERBOARD + DI + 1], AL
    MOV  AL, [SI + 2]
    MOV  [LEADERBOARD + DI + 2], AL

    ; Write score (BP)
    MOV  WORD PTR [LEADERBOARD + DI + 3], BP

    ; Write difficulty (DL — saved from AL before shift loop)
    MOV  BYTE PTR [LEADERBOARD + DI + 5], DL

    ; Zero padding bytes
    MOV  WORD PTR [LEADERBOARD + DI + 6], 0

FIS_DONE:
    POP  BP
    POP  DI
    POP  SI
    RET
FILE_INSERT_SCORE ENDP

;---------------------------------------------------------------
; USER_LOAD — Load USERS.DAT into USER_TABLE. Called once at boot.
; If file missing, USER_TABLE stays zeroed, USER_COUNT = 0.
; In:  none
; Out: USER_TABLE populated, USER_COUNT set
; Preserves: nothing critical
; Clobbers:  AX, BX, CX, DX, DI
;---------------------------------------------------------------
USER_LOAD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    ; Zero USER_TABLE
    PUSH DS
    POP  ES                    ; ES = DS for STOSB
    LEA  DI, USER_TABLE
    MOV  CX, MAX_USERS * USER_RECORD_SIZE
    XOR  AL, AL
    CLD
    REP  STOSB

    ; Open USERS.DAT for reading
    MOV  AH, 3Dh
    MOV  AL, 0                 ; read-only
    LEA  DX, FN_USERS
    INT  21h
    JC   UL_NONE               ; file missing → table zeroed, count = 0

    MOV  FILE_HANDLE, AX

    ; Read into USER_TABLE
    MOV  AH, 3Fh
    MOV  BX, FILE_HANDLE
    MOV  CX, MAX_USERS * USER_RECORD_SIZE
    LEA  DX, USER_TABLE
    INT  21h
    ; AX = bytes actually read

    ; USER_COUNT = bytes_read / USER_RECORD_SIZE
    XOR  AH, AH
    MOV  CL, USER_RECORD_SIZE
    DIV  CL                    ; AL = AX / 8
    MOV  BYTE PTR [USER_COUNT], AL

    ; Close file
    MOV  AH, 3Eh
    MOV  BX, FILE_HANDLE
    INT  21h
    JMP  UL_DONE

UL_NONE:
    MOV  BYTE PTR [USER_COUNT], 0

UL_DONE:
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
USER_LOAD ENDP

;---------------------------------------------------------------
; USER_AUTH — Check or register a user.
; Walks USER_TABLE searching for matching name, then validates
; password. Registers new users if table has room.
; In:  DS:SI = 3-byte username (uppercase ASCII)
;      DS:DI = 5-byte password (uppercase ASCII)
; Out: AX = 0  → existing user, password correct
;      AX = 1  → new user, registered into USER_TABLE
;      AX = 2  → existing user, wrong password
;      AX = 3  → no such user, USER_TABLE full
; Side effect: on AX=1, USER_TABLE and USER_COUNT updated.
;              Caller should call USER_SAVE to persist.
; Preserves: SI, DI
; Clobbers:  AX, BX, CX, DX, flags
;---------------------------------------------------------------
USER_AUTH PROC
    PUSH SI
    PUSH DI
    PUSH BX
    PUSH CX
    PUSH DX

    ; ES = DS for string comparisons
    PUSH DS
    POP  ES

    ; Walk USER_TABLE entries
    XOR  BX, BX                ; BX = byte offset into USER_TABLE
    MOV  DL, BYTE PTR [USER_COUNT]

UA_SEARCH:
    OR   DL, DL
    JZ   UA_NOT_FOUND

    ; Compare 3-byte name: DS:SI (input) vs [USER_TABLE + BX]
    PUSH SI
    PUSH DI
    LEA  DI, [USER_TABLE + BX]
    MOV  CX, 3
    REPE CMPSB
    POP  DI
    POP  SI
    JNE  UA_NEXT               ; name mismatch

    ; Name matched! Compare 5-byte password
    PUSH SI
    PUSH DI
    MOV  SI, DI                ; SI = input password
    LEA  DI, [USER_TABLE + BX + 3]
    MOV  CX, 5
    REPE CMPSB
    POP  DI
    POP  SI
    JNE  UA_BADPW

    ; Password correct
    MOV  AX, 0
    JMP  UA_DONE

UA_BADPW:
    MOV  AX, 2
    JMP  UA_DONE

UA_NEXT:
    ADD  BX, USER_RECORD_SIZE
    DEC  DL
    JMP  UA_SEARCH

UA_NOT_FOUND:
    ; Check if table is full
    CMP  BYTE PTR [USER_COUNT], MAX_USERS
    JB   UA_REGISTER
    MOV  AX, 3
    JMP  UA_DONE

UA_REGISTER:
    ; Compute offset for new entry: USER_COUNT * USER_RECORD_SIZE
    MOV  AL, BYTE PTR [USER_COUNT]
    MOV  AH, USER_RECORD_SIZE
    MUL  AH                    ; AX = USER_COUNT * 8
    MOV  BX, AX                ; BX = byte offset

    ; Copy 3-byte name from SI
    MOV  AL, [SI]
    MOV  [USER_TABLE + BX], AL
    MOV  AL, [SI + 1]
    MOV  [USER_TABLE + BX + 1], AL
    MOV  AL, [SI + 2]
    MOV  [USER_TABLE + BX + 2], AL

    ; Copy 5-byte password from DI
    MOV  AL, [DI]
    MOV  [USER_TABLE + BX + 3], AL
    MOV  AL, [DI + 1]
    MOV  [USER_TABLE + BX + 4], AL
    MOV  AL, [DI + 2]
    MOV  [USER_TABLE + BX + 5], AL
    MOV  AL, [DI + 3]
    MOV  [USER_TABLE + BX + 6], AL
    MOV  AL, [DI + 4]
    MOV  [USER_TABLE + BX + 7], AL

    INC  BYTE PTR [USER_COUNT]
    MOV  AX, 1

UA_DONE:
    POP  DX
    POP  CX
    POP  BX
    POP  DI
    POP  SI
    RET
USER_AUTH ENDP

;---------------------------------------------------------------
; USER_SAVE — Write USER_TABLE back to USERS.DAT.
; Creates/truncates file, writes USER_COUNT * USER_RECORD_SIZE bytes.
; In:  none (reads USER_TABLE, USER_COUNT)
; Out: USERS.DAT written. Errors silent.
; Preserves: nothing critical
; Clobbers:  AX, BX, CX, DX
;---------------------------------------------------------------
USER_SAVE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Create/truncate USERS.DAT
    MOV  AH, 3Ch
    XOR  CX, CX                ; normal attribute
    LEA  DX, FN_USERS
    INT  21h
    JC   US_DONE

    MOV  FILE_HANDLE, AX

    ; Compute bytes to write: USER_COUNT * USER_RECORD_SIZE
    MOV  AL, BYTE PTR [USER_COUNT]
    MOV  AH, USER_RECORD_SIZE
    MUL  AH                    ; AX = count * 8
    MOV  CX, AX

    ; Write USER_TABLE
    MOV  AH, 40h
    MOV  BX, FILE_HANDLE
    LEA  DX, USER_TABLE
    INT  21h

    ; Close file
    MOV  AH, 3Eh
    MOV  BX, FILE_HANDLE
    INT  21h

US_DONE:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
USER_SAVE ENDP

END
