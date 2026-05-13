; SHARED.INC — Project-wide constants
; Included by every .ASM

; --- Game states (v1.3 — STATE_LOGIN inserted, all higher states +1) ---
STATE_TITLE  EQU 0
STATE_LOGIN  EQU 1    ; v1.3 login screen
STATE_MODE   EQU 2
STATE_NAME   EQU 3
STATE_DIFF   EQU 4
STATE_INSTR  EQU 5
STATE_ROUND  EQU 6
STATE_JUDGE  EQU 7
STATE_END    EQU 8
STATE_QUIT   EQU 9

; --- Difficulty tiers ---
DIFF_EASY    EQU 0
DIFF_MED     EQU 1
DIFF_HARD    EQU 2

; --- Game parameters ---
MAX_PLAYERS      EQU 2
MAX_HEARTS       EQU 3
WORDS_PER_TIER   EQU 10
WORD_RECORD_SIZE EQU 16
SPRITE_SIZE      EQU 1024    ; 32x32 pixels
BG_SIZE          EQU 64000   ; 320x200 Mode 13h framebuffer

; --- Login (v1.3) ---
MAX_LOGIN_RETRIES EQU 3

; --- Leaderboard ---
LB_MAX_ENTRIES   EQU 5
LB_ENTRY_SIZE    EQU 8        ; name(3) + score(2) + difficulty(1) + padding(2)

; --- User accounts (v1.3) ---
MAX_USERS        EQU 5
USER_RECORD_SIZE EQU 8        ; name(3) + password(5)
