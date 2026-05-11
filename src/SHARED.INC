; SHARED.INC — Project-wide constants
; Included by every .ASM

; --- Game states (v1.2 — STATE_MODE inserted, all higher states +1) ---
STATE_TITLE  EQU 0
STATE_MODE   EQU 1
STATE_NAME   EQU 2
STATE_DIFF   EQU 3
STATE_INSTR  EQU 4
STATE_ROUND  EQU 5
STATE_JUDGE  EQU 6
STATE_END    EQU 7
STATE_QUIT   EQU 8

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

; --- Leaderboard ---
LB_MAX_ENTRIES  EQU 5
LB_ENTRY_SIZE   EQU 8        ; name(3) + score(2) + difficulty(1) + padding(2)
