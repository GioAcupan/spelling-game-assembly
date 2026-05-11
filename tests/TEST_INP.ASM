; tests/TEST_INP.ASM — Smoke test for INPUT module
; Exercises INP_WAIT_KEY, INP_CHECK_KEY, INP_READ_STRING via DOS text output.

.MODEL SMALL
.STACK 1024

.DATA
    MSG_WAIT    DB 'PRESS ANY KEY:$'
    MSG_PRESSED DB 'YOU PRESSED: $'
    MSG_READ    DB 0Dh, 0Ah, 'TYPE SOMETHING (MAX 16):$'
    MSG_TYPED   DB 0Dh, 0Ah, 'YOU TYPED: $'
    MSG_CHECK   DB 0Dh, 0Ah, 'PRESS ANY KEY (CHECK KEY):$'
    MSG_CHKD    DB 'CHECK KEY PRESSED: $'
    MSG_DONE    DB 0Dh, 0Ah, 'TEST COMPLETE.$'
    MSG_CRLF    DB 0Dh, 0Ah, '$'

    INPUT_BUF   DB 17 DUP(?)    ; 16 chars + null terminator

.CODE
    EXTRN INP_WAIT_KEY:PROC, INP_CHECK_KEY:PROC, INP_READ_STRING:PROC

MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX

    ; --- Test 1: INP_WAIT_KEY ---
    LEA  DX, MSG_WAIT
    MOV  AH, 09h
    INT  21h

    CALL INP_WAIT_KEY          ; blocks until keypress
    PUSH AX                    ; save char + scancode

    LEA  DX, MSG_PRESSED
    MOV  AH, 09h
    INT  21h

    POP  AX
    MOV  DL, AL                ; print the ASCII char
    MOV  AH, 02h
    INT  21h

    LEA  DX, MSG_CRLF
    MOV  AH, 09h
    INT  21h

    ; --- Test 2: INP_READ_STRING ---
    LEA  DX, MSG_READ
    MOV  AH, 09h
    INT  21h

    PUSH DS
    POP  ES                    ; ES = DS = @DATA
    LEA  DI, INPUT_BUF
    MOV  CX, 16
    CALL INP_READ_STRING       ; CX = actual length

    PUSH CX                    ; save length

    LEA  DX, MSG_TYPED
    MOV  AH, 09h
    INT  21h

    POP  CX                    ; restore length
    MOV  BYTE PTR INPUT_BUF[CX], '$'   ; DOS 09h needs $, not null
    LEA  DX, INPUT_BUF
    MOV  AH, 09h
    INT  21h

    ; --- Test 3: INP_CHECK_KEY (polling loop) ---
    LEA  DX, MSG_CHECK
    MOV  AH, 09h
    INT  21h

T3_LOOP:
    CALL INP_CHECK_KEY
    JZ   T3_LOOP               ; ZF=1 means no key yet — keep polling

    PUSH AX                    ; save char

    LEA  DX, MSG_CRLF
    MOV  AH, 09h
    INT  21h

    LEA  DX, MSG_CHKD
    MOV  AH, 09h
    INT  21h

    POP  AX
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h

    ; --- Done ---
    LEA  DX, MSG_DONE
    MOV  AH, 09h
    INT  21h

    MOV  AH, 4Ch
    MOV  AL, 0
    INT  21h
MAIN ENDP

END MAIN
