IDEAL
MODEL tiny

CODESEG
ORG 100h

start:
    mov ax, 0013h
    int 10h
    push cs
    pop ds
    push cs
    pop es

menu_screen:
    mov ax, 0013h
    int 10h
    mov ah, 13h
    mov al, 01h
    mov bl, 0Fh
    mov cx, 13
    mov dh, 8
    mov dl, 13
    mov bp, offset msg_title
    int 10h

    mov ah, 13h
    mov bl, 0Ah
    mov cx, 15
    mov dh, 14
    mov dl, 12
    mov bp, offset msg_play
    int 10h
    
    mov ah, 13h
    mov bl, 04h
    mov cx, 15
    mov dh, 16
    mov dl, 12
    mov bp, offset msg_exit
    int 10h

wait_for_input:
    mov ah, 00h
    int 16h
    cmp al, '1'
    je bridge_to_game
    cmp al, '2'
    je bridge_to_exit
    jmp wait_for_input

bridge_to_game:
    jmp game_start
bridge_to_exit:
    jmp exit_program

game_start:
    mov [score], 0      
    mov [word_counter], 1 
    mov ax, 0013h
    int 10h

    mov ah, 13h
    mov al, 01h
    mov bl, 0Eh
    mov cx, 22
    mov dh, 1
    mov dl, 1
    mov bp, offset msg_name_input
    int 10h
    
    mov ah, 13h
    mov al, 01h
    mov bl, 0Fh
    mov cx, 18
    mov dh, 10
    mov dl, 11
    mov bp, offset msg_prompt
    int 10h

    mov dh, 13
    mov dl, 17      ; --- FIXED: Added mov here ---
    mov ah, 02h
    mov bh, 0
    int 10h
    mov [name_count], 0

char_loop:
    mov ah, 00h
    int 16h
    cmp al, 13          
    je name_done
    cmp al, 8           
    je handle_backspace_name
    cmp [name_count], 6 
    jae char_loop
    mov bx, offset player_name
    add bx, [name_count]
    mov [bx], al
    mov ah, 0Eh         
    mov bl, 0Eh         
    int 10h
    inc [name_count]
    jmp char_loop

handle_backspace_name:
    cmp [name_count], 0
    je char_loop
    dec [name_count]
    mov ah, 0Eh
    mov al, 8
    int 10h
    mov al, ' '
    int 10h
    mov al, 8
    int 10h
    jmp char_loop

name_done:
    mov cx, 6
    sub cx, [name_count]
    jz difficulty_screen
    mov bx, offset player_name
    add bx, [name_count]
pad_name:
    mov [byte ptr bx], ' '
    inc bx
    loop pad_name
    jmp difficulty_screen

difficulty_screen:
    mov ax, 0013h
    int 10h
    mov ah, 13h
    mov al, 01h
    mov bl, 0Fh
    mov cx, 17
    mov dh, 5
    mov dl, 11
    mov bp, offset msg_diff_title
    int 10h
    mov bl, 0Ah
    mov cx, 17
    mov dh, 10
    mov dl, 11
    mov bp, offset msg_easy
    int 10h
    mov bl, 0Eh
    mov cx, 18
    mov dh, 12
    mov dl, 11
    mov bp, offset msg_med
    int 10h
    mov bl, 0Ch
    mov cx, 16
    mov dh, 14
    mov dl, 11
    mov bp, offset msg_hard
    int 10h

wait_for_diff:
    mov ah, 00h
    int 16h
    cmp al, '1'
    je set_easy
    cmp al, '2'
    je set_med
    cmp al, '3'
    je set_hard
    jmp wait_for_diff

set_easy:
    mov [tier_offset], 0
    jmp game_spelling
set_med:
    mov [tier_offset], 70
    jmp game_spelling
set_hard:
    mov [tier_offset], 140
    jmp game_spelling

game_spelling:
    mov ah, 00h
    int 1Ah
    mov ax, dx
    xor dx, dx
    div [word_pool_size]    
    mov ax, dx
    mov bl, 7           
    mul bl              
    add ax, [tier_offset]
    add ax, offset word_list
    mov [current_word_ptr], ax
    mov [spell_count], 0
    mov cx, 7
    mov di, offset user_buffer
    mov al, ' '
    rep stosb
    mov ax, 0013h
    int 10h
    mov ah, 00h
    int 1Ah
    mov [start_ticks], dx

game_loop:
    mov ah, 13h
    mov bl, 0Bh
    mov cx, 5
    mov dh, 1
    mov dl, 31
    mov bp, offset msg_word_ind
    int 10h
    mov ah, 02h
    mov dh, 1
    mov dl, 38
    int 10h
    mov ax, [word_counter]
    aam
    add ax, 3030h
    mov ah, 0Eh
    int 10h
    
    mov ah, 13h
    mov al, 01h
    mov bl, 0Eh
    mov cx, 30
    mov dh, 3
    mov dl, 5
    mov bp, offset msg_instr
    int 10h

    mov ah, 02h
    mov dh, 1
    mov dl, 1
    mov bh, 0
    int 10h
    mov al, [score]
    aam
    add ax, 3030h
    push ax
    mov al, ah
    mov ah, 0Eh
    int 10h
    pop ax
    mov ah, 0Eh
    int 10h

    mov ah, 13h
    mov al, 01h
    mov bl, 0Fh
    mov cx, 7
    mov dh, 10
    mov dl, 16
    mov bp, [current_word_ptr]
    int 10h

    mov ah, 01h
    int 16h
    jz game_loop_bridge 

    mov ah, 00h         
    int 16h
    cmp al, 13          
    je check_spelling
    cmp al, 8           
    je handle_backspace_spell
    cmp [spell_count], 6
    jae game_loop_bridge

    mov bx, offset user_buffer
    add bx, [spell_count]
    mov [bx], al
    mov ah, 02h         
    mov dh, 14
    mov dl, 16
    add dl, [byte ptr spell_count]
    mov bh, 0
    int 10h
    mov ah, 0Eh         
    mov bl, 0Ah         
    int 10h
    inc [spell_count]

game_loop_bridge:
    jmp game_loop

handle_backspace_spell:
    cmp [spell_count], 0
    je game_loop_bridge
    dec [spell_count]
    mov ah, 02h         
    mov dh, 14
    mov dl, 16
    add dl, [byte ptr spell_count]
    int 10h
    mov ah, 0Eh         
    mov al, ' '
    int 10h
    jmp game_loop_bridge

check_spelling:
    mov cx, 7
    mov si, offset user_buffer
    mov di, [current_word_ptr]
    repe cmpsb          
    je correct_answer   
    jmp incorrect_answer

correct_answer:
    call play_chime
    inc [score]         
    jmp next_word_logic

incorrect_answer:
    call play_sad_chime 
    jmp next_word_logic

next_word_logic:
    inc [word_counter]
    cmp [word_counter], 11 
    je win_transition
    jmp game_spelling      

win_transition:
    call update_leaderboard 
    jmp win_screen

win_screen:
    mov ax, 0013h
    int 10h
    mov ah, 13h
    mov al, 01h
    mov bl, 0Eh 
    mov cx, 8
    mov dh, 10
    mov dl, 16
    mov bp, offset msg_win
    int 10h
    mov ah, 00h
    int 16h
    jmp game_leaderboard

game_leaderboard:
    mov ax, 0013h
    int 10h
    mov ah, 13h
    mov al, 01h
    mov bl, 0Eh 
    mov cx, 11
    mov dh, 1
    mov dl, 14
    mov bp, offset msg_leaderboard
    int 10h

    mov ah, 13h
    mov bl, 0Fh
    mov cx, 15
    mov dh, 4
    mov dl, 12
    mov bp, offset msg_lb_header
    int 10h

    mov cx, 5
    mov si, offset lb_data
    mov dh, 6
lb_display_loop:
    push cx
    push dx
    
    mov ah, 13h
    mov al, 01h
    mov bl, 0Ah
    mov cx, 6
    mov dl, 12
    mov bp, si
    int 10h

    pop dx
    push dx
    mov ah, 02h
    mov dl, 23
    int 10h
    
    mov al, [si+6] 
    aam
    add ax, 3030h
    push ax
    mov al, ah
    mov ah, 0Eh
    int 10h
    pop ax
    mov ah, 0Eh
    int 10h

    add si, 7 
    pop dx
    inc dh
    pop cx
    loop lb_display_loop

    mov ah, 00h
    int 16h
    jmp menu_screen

exit_program:
    mov ax, 0003h
    int 10h
    mov ah, 4Ch
    int 21h

proc update_leaderboard
    mov cx, 5
    mov di, offset lb_data
find_slot:
    mov al, [score]
    cmp al, [byte ptr di+6]
    ja insert_here
    add di, 7
    loop find_slot
    ret

insert_here:
    push cx
    cmp cx, 1
    je skip_shift
    
    mov si, offset lb_data
    add si, 27 
    
shift_loop:
    mov bx, si
    cmp si, di
    jb skip_shift
    
    push cx
    mov cx, 7
copy_entry:
    mov al, [si+6]
    mov [si+13], al
    dec si
    loop copy_entry
    pop cx
    jmp shift_loop

skip_shift:
    pop cx
    mov si, offset player_name
    mov cx, 6
    rep movsb
    mov al, [score]
    stosb
    ret
endp update_leaderboard

proc play_chime
    mov al, 0B6h
    out 43h, al
    mov ax, 1193
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 03h
    out 61h, al
    mov cx, 01h
    mov dx, 86A0h
    mov ah, 86h
    int 15h
    mov ax, 905
    out 42h, al
    mov al, ah
    out 42h, al
    mov cx, 01h
    mov dx, 86A0h
    mov ah, 86h
    int 15h
    in al, 61h
    and al, 0FCh
    out 61h, al
    ret
endp play_chime

proc play_sad_chime
    mov al, 0B6h
    out 43h, al
    mov ax, 3000
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 03h
    out 61h, al
    mov cx, 02h
    mov dx, 0D40h
    mov ah, 86h
    int 15h
    mov ax, 4500
    out 42h, al
    mov al, ah
    out 42h, al
    mov cx, 04h
    mov dx, 0D40h
    mov ah, 86h
    int 15h
    in al, 61h
    and al, 0FCh
    out 61h, al
    ret
endp play_sad_chime

; --- Data ---
start_ticks      dw 0
max_ticks        dw 546
tier_offset      dw 0
word_pool_size   dw 10
current_word_ptr dw 0
spell_count      dw 0
score            db 0 
word_counter     dw 1
user_buffer      db 7 dup(' ')

word_list        db 'CAT    ', 'DOG    ', 'EGG    ', 'SUN    ', 'HAT    ', 'BAG    ', 'CUP    ', 'PIG    ', 'HEN    ', 'ANT    '
                 db 'APPLE  ', 'GRAPE  ', 'TRAIN  ', 'CHAIR  ', 'CLOCK  ', 'BREAD  ', 'TIGER  ', 'HORSE  ', 'CLOUD  ', 'PLANT  '
                 db 'ORANGE ', 'SCHOOL ', 'BRIDGE ', 'CHICKEN', 'RAINBOW', 'PENGUIN', 'BLANKET', 'THUNDER', 'LANTERN', 'DOLPHIN'

name_count       dw 0
player_name      db 7 dup(' ')
lb_data          db 35 dup(0)

msg_lb_header    db 'NAME      SCORE'
msg_title        db 'SPELLING GAME'
msg_play         db 'Press 1 to Play'
msg_exit         db 'Press 2 to Exit'
msg_name_input   db 'Please enter your name'
msg_prompt       db 'ENTER NAME (MAX 6):'
msg_win          db 'You win!'
msg_diff_title   db 'SELECT DIFFICULTY'
msg_easy         db '1. EASY   (Short)'
msg_med          db '2. MEDIUM (Medium)'
msg_hard         db '3. HARD   (Long)'
msg_instr        db "Please enter the object's name"
msg_leaderboard  db 'Leaderboard'
msg_word_ind     db 'WORD '

END start