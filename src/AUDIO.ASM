; AUDIO.ASM — PC speaker tone generation
; Plays frequency/duration patterns via PIT channel 2 (ports 42h/43h/61h).

.MODEL SMALL
.DATA
    INCLUDE SHARED.INC

.CODE
    PUBLIC SND_PLAY_TONE, SND_SILENCE, SND_DELAY, SND_PLAY_PATTERN

;-----------------------------------------------------------
; SND_PLAY_TONE — Program PIT channel 2 for a square wave
;                 at the given frequency and enable speaker.
; In:  BX = frequency in Hz (e.g., 440 = A4)
; Out: Speaker playing continuous tone
; Preserves: AX, BX, DX
; Clobbers:  flags
;-----------------------------------------------------------
SND_PLAY_TONE PROC
    PUSH AX
    PUSH BX
    PUSH DX

    ; Compute divisor = 1193180 / frequency
    ; 1193180 = 0012_34DCh
    MOV  DX, 12h
    MOV  AX, 34DCh
    DIV  BX                   ; AX = divisor (quotient)

    ; Program PIT channel 2: square wave, both bytes, binary
    PUSH AX                   ; save divisor for byte-by-byte output
    MOV  AL, 0B6h             ; ch2, lo/hi byte, mode 3, 16-bit binary
    OUT  43h, AL
    POP  AX
    OUT  42h, AL              ; divisor low byte
    MOV  AL, AH
    OUT  42h, AL              ; divisor high byte

    ; Enable speaker: set bits 0-1 of port 61h (gate + data)
    IN   AL, 61h
    OR   AL, 03h
    OUT  61h, AL

    POP  DX
    POP  BX
    POP  AX
    RET
SND_PLAY_TONE ENDP

;-----------------------------------------------------------
; SND_SILENCE — Disable PC speaker.
; In:  (none)
; Out: Speaker silent
; Preserves: AX
; Clobbers:  flags
;-----------------------------------------------------------
SND_SILENCE PROC
    PUSH AX
    IN   AL, 61h
    AND  AL, 0FCh             ; clear bits 0 and 1
    OUT  61h, AL
    POP  AX
    RET
SND_SILENCE ENDP

;-----------------------------------------------------------
; SND_DELAY — Busy-wait for the given number of milliseconds
;             using BIOS tick counter polling (INT 1Ah).
;             ~55ms resolution; handles 16-bit wrap safely.
; In:  CX = milliseconds
; Out: (none)
; Preserves: AX, BX, CX, DX
; Clobbers:  BP, flags
;-----------------------------------------------------------
SND_DELAY PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH BP                   ; scratch: holds start tick

    ; Convert ms to BIOS ticks: ticks = (ms * 182 + 9999) / 10000
    MOV  AX, CX               ; AX = ms
    MOV  BX, 182
    MUL  BX                   ; DX:AX = ms * 182
    ADD  AX, 9999
    ADC  DX, 0                ; DX:AX = ms * 182 + 9999  (round up)
    MOV  BX, 10000
    DIV  BX                   ; AX = ticks needed
    INC  AX                   ; at least 1 tick (~55ms minimum)
    MOV  BX, AX               ; BX = target tick count

    ; Read starting BIOS tick count
    MOV  AH, 00h
    INT  1Ah                  ; CX:DX = 32-bit tick counter
    MOV  BP, DX               ; BP = start (low word)

SD_WAIT:
    MOV  AH, 00h
    INT  1Ah                  ; DX = current tick (low word)
    MOV  AX, DX
    SUB  AX, BP               ; AX = elapsed ticks (unsigned, wrap-safe)
    CMP  AX, BX
    JB   SD_WAIT

    POP  BP
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SND_DELAY ENDP

;-----------------------------------------------------------
; SND_PLAY_PATTERN — Play a sequence of (freq, dur_ms) pairs.
; Pattern format: array of DW frequency, DW duration_ms,
; terminated by frequency=0.
; In:  DS:SI = pointer to pattern
; Out: Pattern played to completion, speaker silenced
; Preserves: AX, BX, CX, DX, SI
; Clobbers:  flags
;-----------------------------------------------------------
SND_PLAY_PATTERN PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

SPP_LOOP:
    MOV  BX, [SI]             ; frequency (word, little-endian)
    OR   BX, BX
    JZ   SPP_DONE             ; 0 = terminator
    ADD  SI, 2
    MOV  CX, [SI]             ; duration in ms
    ADD  SI, 2                ; advance past pair

    CALL SND_PLAY_TONE
    CALL SND_DELAY
    CALL SND_SILENCE

    ; Small gap between tones to prevent bleed
    MOV  CX, 30
    CALL SND_DELAY

    JMP  SPP_LOOP

SPP_DONE:
    CALL SND_SILENCE
    POP  SI
    POP  CX
    POP  BX
    POP  AX
    RET
SND_PLAY_PATTERN ENDP

END
