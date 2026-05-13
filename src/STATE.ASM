; STATE.ASM — State dispatcher
; Exports GAME_TICK: reads CURRENT_STATE, calls the matching screen handler.

.MODEL SMALL
.DATA
    INCLUDE SHARED.INC
    EXTRN CURRENT_STATE:BYTE

.CODE
    EXTRN SCR_TITLE_RUN:PROC
    EXTRN SCR_LOGIN_RUN:PROC
    EXTRN SCR_MODE_RUN:PROC
    EXTRN SCR_NAME_RUN:PROC
    EXTRN SCR_DIFF_RUN:PROC
    EXTRN SCR_INSTR_RUN:PROC
    EXTRN SCR_ROUND_RUN:PROC
    EXTRN SCR_JUDGE_RUN:PROC
    EXTRN SCR_END_RUN:PROC

    PUBLIC GAME_TICK

;-----------------------------------------------------------
; GAME_TICK — Dispatch CURRENT_STATE to the right screen handler.
; In:  (none) — reads CURRENT_STATE
; Out: (none)
; Preserves: BX, CX, DX, SI, DI, BP
; Clobbers:  AX
;-----------------------------------------------------------
GAME_TICK PROC
    MOV AL, CURRENT_STATE

    CMP AL, STATE_TITLE
    JE  GT_TITLE
    CMP AL, STATE_LOGIN
    JE  GT_LOGIN
    CMP AL, STATE_MODE
    JE  GT_MODE
    CMP AL, STATE_NAME
    JE  GT_NAME
    CMP AL, STATE_DIFF
    JE  GT_DIFF
    CMP AL, STATE_INSTR
    JE  GT_INSTR
    CMP AL, STATE_ROUND
    JE  GT_ROUND
    CMP AL, STATE_JUDGE
    JE  GT_JUDGE
    CMP AL, STATE_END
    JE  GT_END
    ; STATE_QUIT or unknown state — fall through to return
    RET

GT_TITLE:
    CALL SCR_TITLE_RUN
    RET
GT_LOGIN:
    CALL SCR_LOGIN_RUN
    RET
GT_MODE:
    CALL SCR_MODE_RUN
    RET
GT_NAME:
    CALL SCR_NAME_RUN
    RET
GT_DIFF:
    CALL SCR_DIFF_RUN
    RET
GT_INSTR:
    CALL SCR_INSTR_RUN
    RET
GT_ROUND:
    CALL SCR_ROUND_RUN
    RET
GT_JUDGE:
    CALL SCR_JUDGE_RUN
    RET
GT_END:
    CALL SCR_END_RUN
    RET
GAME_TICK ENDP

END
