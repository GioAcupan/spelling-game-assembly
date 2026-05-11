; DATA.ASM — Word list (3 tiers), sprite data, sound patterns, UI strings
; Pure data module — no .CODE. All symbols exported via PUBLIC.

.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

    ; ================================================================
    ; WORD LISTS — 3 separate fixed-width arrays (16 bytes/word)
    ; Address formula: tier_base + (index * WORD_RECORD_SIZE)
    ; DIFFICULTY byte in MAIN.ASM selects which tier base to use.
    ; ================================================================

    ; --- Easy tier (3-4 letter words) ---
    PUBLIC EASY_WORDS
EASY_WORDS DB 'CAT',0,  12 DUP(0)   ; index 0
    DB 'DOG',0,  12 DUP(0)   ; index 1
    DB 'EGG',0,  12 DUP(0)   ; index 2
    DB 'SUN',0,  12 DUP(0)   ; index 3
    DB 'HAT',0,  12 DUP(0)   ; index 4
    DB 'BAG',0,  12 DUP(0)   ; index 5
    DB 'CUP',0,  12 DUP(0)   ; index 6
    DB 'PIG',0,  12 DUP(0)   ; index 7
    DB 'HEN',0,  12 DUP(0)   ; index 8
    DB 'ANT',0,  12 DUP(0)   ; index 9

    ; --- Medium tier (5-6 letter words) ---
    PUBLIC MED_WORDS
MED_WORDS DB 'APPLE',0,  10 DUP(0) ; index 0
    DB 'GRAPE',0,  10 DUP(0) ; index 1
    DB 'TRAIN',0,  10 DUP(0) ; index 2
    DB 'CHAIR',0,  10 DUP(0) ; index 3
    DB 'CLOCK',0,  10 DUP(0) ; index 4
    DB 'BREAD',0,  10 DUP(0) ; index 5
    DB 'TIGER',0,  10 DUP(0) ; index 6
    DB 'HORSE',0,  10 DUP(0) ; index 7
    DB 'CLOUD',0,  10 DUP(0) ; index 8
    DB 'PLANT',0,  10 DUP(0) ; index 9

    ; --- Hard tier (7+ letter words) ---
    PUBLIC HARD_WORDS
HARD_WORDS DB 'ORANGE',0,  9 DUP(0) ; index 0
    DB 'SCHOOL',0,  9 DUP(0) ; index 1
    DB 'BRIDGE',0,  9 DUP(0) ; index 2
    DB 'CHICKEN',0, 8 DUP(0) ; index 3
    DB 'RAINBOW',0, 8 DUP(0) ; index 4
    DB 'PENGUIN',0, 8 DUP(0) ; index 5
    DB 'BLANKET',0, 8 DUP(0) ; index 6
    DB 'THUNDER',0, 8 DUP(0) ; index 7
    DB 'LANTERN',0, 8 DUP(0) ; index 8
    DB 'DOLPHIN',0, 8 DUP(0) ; index 9

    ; ================================================================
    ; TIER POINTER TABLE — lets SCR_GAME resolve tier base at runtime
    ; Usage: MOV BX, DIFFICULTY; SHL BX,1; MOV SI,[TIER_TABLE+BX]
    ; ================================================================
    PUBLIC TIER_TABLE
TIER_TABLE DW OFFSET EASY_WORDS    ; DIFF_EASY = 0
    DW OFFSET MED_WORDS     ; DIFF_MED  = 1
    DW OFFSET HARD_WORDS    ; DIFF_HARD = 2

    ; [TEST 2] SOUND PATTERNS + SOUND_TABLE commented out — testing OFFSET hypothesis
PUBLIC SOUND_TABLE
SOUND_TABLE DW 0

    ; ================================================================
    ; UI STRINGS — null-terminated, drawn by GFX_DRAW_STRING
    ; ================================================================
    PUBLIC STR_TITLE, STR_INSTR, STR_GAMEOVER, STR_WIN
    PUBLIC STR_DIFF_PROMPT, STR_EASY, STR_MED, STR_HARD

STR_TITLE       DB 'SPELLING FUN!',0
STR_INSTR       DB 'TYPE WHAT YOU HEAR. PRESS ENTER.',0
STR_GAMEOVER    DB 'GAME OVER',0
STR_WIN         DB 'YOU DID IT!',0
STR_DIFF_PROMPT DB 'CHOOSE DIFFICULTY:',0
STR_EASY        DB '1. EASY',0
STR_MED         DB '2. MEDIUM',0
STR_HARD        DB '3. HARD',0
    ; ================================================================
    ; SPRITE TABLE — [TEST 3] stub, 30KB sprite data removed
    ; ================================================================
    PUBLIC SPRITE_TABLE
SPRITE_TABLE DB 0

.CODE
DATA_DUMMY PROC
    RET
DATA_DUMMY ENDP
END
