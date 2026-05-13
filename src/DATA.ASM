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
    ; SCRAMBLE TABLE — 30 scrambled words (v1.4)
    ; Same stride as word lists: WORD_RECORD_SIZE (16 bytes)
    ; Index: DIFFICULTY * WORDS_PER_TIER + CURRENT_WORD
    ; Each entry is a hardcoded scramble — distinct from original,
    ; length-matched, ideally not a real word.
    ; ================================================================
SCRAMBLE_TABLE DB 'ATC',0, 12 DUP(0)       ; CAT
    DB 'ODG',0, 12 DUP(0)       ; DOG
    DB 'GGE',0, 12 DUP(0)       ; EGG
    DB 'NSU',0, 12 DUP(0)       ; SUN
    DB 'ATH',0, 12 DUP(0)       ; HAT
    DB 'GBA',0, 12 DUP(0)       ; BAG
    DB 'PCU',0, 12 DUP(0)       ; CUP
    DB 'IPG',0, 12 DUP(0)       ; PIG
    DB 'NEH',0, 12 DUP(0)       ; HEN
    DB 'TNA',0, 12 DUP(0)       ; ANT
    DB 'PAPEL',0,  10 DUP(0)    ; APPLE
    DB 'PAGER',0,  10 DUP(0)    ; GRAPE
    DB 'ARTNI',0,  10 DUP(0)    ; TRAIN
    DB 'HARCI',0,  10 DUP(0)    ; CHAIR
    DB 'COLCK',0,  10 DUP(0)    ; CLOCK
    DB 'DABRE',0,  10 DUP(0)    ; BREAD
    DB 'GRITE',0,  10 DUP(0)    ; TIGER
    DB 'ROHES',0,  10 DUP(0)    ; HORSE
    DB 'DOCUL',0,  10 DUP(0)    ; CLOUD
    DB 'TALPN',0,  10 DUP(0)    ; PLANT
    DB 'GORANE',0,  9 DUP(0)    ; ORANGE
    DB 'OOLCSH',0,  9 DUP(0)    ; SCHOOL
    DB 'DRIBGE',0,  9 DUP(0)    ; BRIDGE
    DB 'HICKENC',0, 8 DUP(0)    ; CHICKEN
    DB 'BOWRAIN',0, 8 DUP(0)    ; RAINBOW
    DB 'GUINPEN',0, 8 DUP(0)    ; PENGUIN
    DB 'KETBLAN',0, 8 DUP(0)    ; BLANKET
    DB 'DERTHUN',0, 8 DUP(0)    ; THUNDER
    DB 'TERNLAN',0, 8 DUP(0)    ; LANTERN
    DB 'PHINDOL',0, 8 DUP(0)    ; DOLPHIN

    ; ================================================================
    ; TIER POINTER TABLE — lets SCR_GAME resolve tier base at runtime
    ; Usage: MOV BX, DIFFICULTY; SHL BX,1; MOV SI,[TIER_TABLE+BX]
    ; ================================================================
    PUBLIC TIER_TABLE
TIER_TABLE DW OFFSET EASY_WORDS    ; DIFF_EASY = 0
    DW OFFSET MED_WORDS     ; DIFF_MED  = 1
    DW OFFSET HARD_WORDS    ; DIFF_HARD = 2

    ; [TEST 2] SOUND PATTERNS + SOUND_TABLE commented out — testing OFFSET hypothesis
    ; TODO: v1.2 spec requires 30 sound patterns (one per word), each a sequence
    ;       of (frequency, duration_ms) pairs terminated by freq=0.
PUBLIC SOUND_TABLE
SOUND_TABLE DW 0

    ; --- Title jingle (v1.3) — C-E-G-C ascending, ~750ms ---
SND_TITLE_JINGLE DW 262, 175
    DW 330, 175
    DW 392, 175
    DW 523, 225
    DW 0

    ; --- Win jingle (v1.3) — triumphant C5 fanfare, ~880ms ---
SND_WIN_JINGLE DW 523, 150
    DW 0, 30
    DW 523, 150
    DW 0, 30
    DW 523, 150
    DW 0, 30
    DW 523, 340
    DW 0

    ; --- Lose jingle (v1.3) — descending sad, ~1100ms ---
SND_LOSE_JINGLE DW 330, 250
    DW 277, 250
    DW 262, 300
    DW 220, 300
    DW 0

    ; ================================================================
    ; UI STRINGS — null-terminated, drawn by GFX_DRAW_STRING
    ; ================================================================
    PUBLIC STR_TITLE, STR_INSTR, STR_GAMEOVER, STR_WIN
    PUBLIC STR_DIFF_PROMPT, STR_EASY, STR_MED, STR_HARD
    PUBLIC STR_MODE_PROMPT, STR_1P, STR_2P
    PUBLIC STR_PLAYER1, STR_PLAYER2, STR_YOUR_TURN
    PUBLIC STR_VS, STR_WINNER, STR_TIE
    PUBLIC STR_HINT
    PUBLIC BG_TITLE, BG_MODE, BG_NAME, BG_DIFF, BG_INSTR, BG_ROUND, BG_END
    PUBLIC BG_LOGIN
    PUBLIC SCRAMBLE_TABLE
    PUBLIC SND_TITLE_JINGLE, SND_WIN_JINGLE, SND_LOSE_JINGLE

STR_TITLE       DB 'SPELLING FUN!',0
STR_INSTR       DB 'TYPE WHAT YOU HEAR. PRESS ENTER.',0
STR_GAMEOVER    DB 'GAME OVER',0
STR_WIN         DB 'YOU DID IT!',0
STR_DIFF_PROMPT DB 'CHOOSE DIFFICULTY:',0
STR_EASY        DB '1. EASY',0
STR_MED         DB '2. MEDIUM',0
STR_HARD        DB '3. HARD',0

    ; --- 2-player UI strings (v1.2) ---
STR_MODE_PROMPT DB 'CHOOSE MODE:',0
STR_1P          DB '1. ONE PLAYER',0
STR_2P          DB '2. TWO PLAYERS',0
STR_PLAYER1     DB 'PLAYER 1',0
STR_PLAYER2     DB 'PLAYER 2',0
STR_YOUR_TURN   DB 'YOUR TURN!',0
STR_VS          DB ' VS ',0
STR_WINNER      DB 'WINNER: ',0
STR_TIE         DB 'ITS A TIE!',0
STR_HINT        DB 'HINT: ',0

    ; --- Background filenames (v1.2) ---
BG_TITLE  DB 'TITLE.BIN',0
BG_MODE   DB 'MODE.BIN',0
BG_NAME   DB 'NAME.BIN',0
BG_DIFF   DB 'DIFF.BIN',0
BG_INSTR  DB 'INSTR.BIN',0
BG_ROUND  DB 'ROUND.BIN',0
BG_END    DB 'END.BIN',0
BG_LOGIN  DB 'LOGIN.BIN',0

    ; ================================================================
    ; SPRITE TABLE — [TEST 3] stub, 30KB sprite data removed
    ; TODO: v1.2 spec requires 30 sprites (10 per tier), each 32x32,
    ;       exported as raw byte arrays and pasted here.
    ; ================================================================
    PUBLIC SPRITE_TABLE
SPRITE_TABLE DB 0

END
