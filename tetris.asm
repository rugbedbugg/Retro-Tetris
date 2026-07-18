; ===================================================================
; TUI Tetris  --  x86-64, NASM, Windows console
; -------------------------------------------------------------------
; Renders with ANSI escape codes (monochrome green) and talks to the
; Win32 console API directly. No C runtime is linked; the entry point
; is `main` and the program terminates through ExitProcess.
; ===================================================================

        default rel

; -------------------------------------------------------------------
; Win32 imports (resolved from kernel32.lib at link time)
; -------------------------------------------------------------------
        extern  GetStdHandle
        extern  GetConsoleMode
        extern  SetConsoleMode
        extern  WriteFile
        extern  ReadConsoleInputA
        extern  GetNumberOfConsoleInputEvents
        extern  GetTickCount64
        extern  Sleep
        extern  CreateFileA
        extern  ReadFile
        extern  CloseHandle
        extern  ExitProcess

; -------------------------------------------------------------------
; Layout constants (screen is 1-based for ANSI cursor moves)
; -------------------------------------------------------------------
FIELD_ROW0      equ 3               ; screen row of the first board row
FIELD_COL0      equ 20             ; screen col of the first board cell
STAT_COL        equ 9              ; column where stat numbers start
NEXT_ROW        equ 12             ; top row of the next-piece preview
NEXT_COL        equ 44             ; left column of the next-piece preview

; ===================================================================
; Read-only data
; ===================================================================
        section .rdata

; ESC[2J clear, ESC[H home, ESC[?25l hide cursor, ESC[1;32m bright green
init_seq:       db 27,"[2J",27,"[H",27,"[?25l",27,"[1;32m"
init_len        equ $ - init_seq

; ESC[0m reset, ESC[?25h show cursor, ESC[26;1H park cursor below field
cleanup_seq:    db 27,"[0m",27,"[?25h",27,"[26;1H"
cleanup_len     equ $ - cleanup_seq

top_border:     db "<!====================!>"
top_len         equ $ - top_border
bot_border:     db "<!\/\/\/\/\/\/\/\/\/\/!>"
bot_len         equ $ - bot_border
left_mark:      db "<!"
right_mark:     db "!>"

lbl_lines:      db "LINES:"
lbl_level:      db "LEVEL:"
lbl_score:      db "SCORE:"
two_spaces:     db "  "

c_title:        db "CONTROLS"
c_title_len     equ $ - c_title
c_line1:        db "7 / 9  MOVE"
c_line1_len     equ $ - c_line1
c_line2:        db "8      ROTATE"
c_line2_len     equ $ - c_line2
c_line3:        db "4      SOFT DROP"
c_line3_len     equ $ - c_line3
c_line4:        db "SPACE  HARD DROP"
c_line4_len     equ $ - c_line4
c_line5:        db "Q/ESC  QUIT"
c_line5_len     equ $ - c_line5
lbl_next:       db "NEXT"
lbl_next_len    equ $ - lbl_next

msg_over:       db "GAME OVER"
over_len        equ $ - msg_over

fname_scores:   db "scores.txt",0

; -------------------------------------------------------------------
; Tetromino shapes: 7 pieces, 4 rotations each, as 4x4 cell grids.
; A set cell (1) is part of the piece; the piece id (1..7) is what
; gets written into the board when it locks.
;   index = (id-1)*64 + rot*16 + row*4 + col
; -------------------------------------------------------------------
pieces:
        ; --- I (id 1) ---
        db 0,0,0,0
        db 1,1,1,1
        db 0,0,0,0
        db 0,0,0,0
        db 0,0,1,0
        db 0,0,1,0
        db 0,0,1,0
        db 0,0,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 1,1,1,1
        db 0,0,0,0
        db 0,1,0,0
        db 0,1,0,0
        db 0,1,0,0
        db 0,1,0,0
        ; --- O (id 2) ---
        db 0,0,0,0
        db 0,1,1,0
        db 0,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,1,1,0
        db 0,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,1,1,0
        db 0,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,1,1,0
        db 0,1,1,0
        db 0,0,0,0
        ; --- T (id 3) ---
        db 0,1,0,0
        db 1,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,1,0,0
        db 0,1,1,0
        db 0,1,0,0
        db 0,0,0,0
        db 0,0,0,0
        db 1,1,1,0
        db 0,1,0,0
        db 0,0,0,0
        db 0,1,0,0
        db 1,1,0,0
        db 0,1,0,0
        db 0,0,0,0
        ; --- S (id 4) ---
        db 0,1,1,0
        db 1,1,0,0
        db 0,0,0,0
        db 0,0,0,0
        db 1,0,0,0
        db 1,1,0,0
        db 0,1,0,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,1,1,0
        db 1,1,0,0
        db 0,0,0,0
        db 0,1,0,0
        db 0,1,1,0
        db 0,0,1,0
        db 0,0,0,0
        ; --- Z (id 5) ---
        db 1,1,0,0
        db 0,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,0,1,0
        db 0,1,1,0
        db 0,1,0,0
        db 0,0,0,0
        db 0,0,0,0
        db 1,1,0,0
        db 0,1,1,0
        db 0,0,0,0
        db 0,1,0,0
        db 1,1,0,0
        db 1,0,0,0
        db 0,0,0,0
        ; --- J (id 6) ---
        db 1,0,0,0
        db 1,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,1,1,0
        db 0,1,0,0
        db 0,1,0,0
        db 0,0,0,0
        db 0,0,0,0
        db 1,1,1,0
        db 0,0,1,0
        db 0,0,0,0
        db 0,1,0,0
        db 0,1,0,0
        db 1,1,0,0
        db 0,0,0,0
        ; --- L (id 7) ---
        db 0,0,1,0
        db 1,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 0,1,0,0
        db 0,1,0,0
        db 0,1,1,0
        db 0,0,0,0
        db 0,0,0,0
        db 1,1,1,0
        db 1,0,0,0
        db 0,0,0,0
        db 1,1,0,0
        db 0,1,0,0
        db 0,1,0,0
        db 0,0,0,0

; points awarded for clearing 0..4 lines at once (scaled by level)
points_tbl:     dd 0, 100, 300, 500, 800

; ===================================================================
; Writable data
; ===================================================================
        section .data

hOut:           dq 0               ; console output handle
hIn:            dq 0               ; console input handle
outMode:        dd 0               ; saved output console mode
inMode:         dd 0               ; saved input console mode
dwWritten:      dd 0               ; bytes-written sink for WriteFile
numRead:        dd 0               ; events-read sink for ReadConsoleInput
numEvents:      dd 0               ; pending input events (poll)
poll_i:         dd 0               ; input record index during a poll

seed:           dd 0               ; xorshift32 state
score:          dd 0
lines:          dd 0
level:          dd 1
drop_ms:        dd 800             ; gravity interval for the current level
grav_acc:       dd 0               ; milliseconds accumulated toward a drop
last_tick:      dq 0               ; GetTickCount64 value at the previous frame

cur_id:         dd 0               ; active piece (id 1..7)
cur_rot:        dd 0
cur_x:          dd 0               ; board col of the piece's 4x4 box
cur_y:          dd 0               ; board row of the piece's 4x4 box
next_id:        dd 0               ; queued piece

; scratch copy of the active piece used to trial a move before committing
tst_id:         dd 0
tst_rot:        dd 0
tst_x:          dd 0
tst_y:          dd 0

game_over:      db 0
quit_flag:      db 0

sb_handle:      dq 0               ; scores file handle
sbtext_len:     dq 0               ; bytes to write back to the file
sb_count:       dd 0               ; number of scoreboard entries in memory

; ===================================================================
; Uninitialised buffers
; ===================================================================
        section .bss

mcbuf:          resb 32            ; scratch for a cursor-move escape
numbuf:         resb 16            ; scratch for a decimal number
inbuf:          resb 640           ; 32 INPUT_RECORDs x 20 bytes
board:          resb 200           ; 10 x 20 cells, 0 = empty, 1..7 = piece
scratch:        resb 200           ; board + falling piece, built each frame
rowbuf:         resb 64            ; one rendered board row
filebuf:        resb 4096          ; raw scores.txt contents while parsing
sbtext:         resb 512           ; scores.txt contents while writing back
sb_score:       resd 40            ; scoreboard entries (parallel arrays)
sb_lines:       resd 40
sb_level:       resd 40

; ===================================================================
; Code
; ===================================================================
        section .text

; -------------------------------------------------------------------
; main : entry point
; -------------------------------------------------------------------
        global  main
main:
        sub     rsp, 56             ; 32-byte shadow + 16-byte alignment

        ; --- grab the console handles ---
        mov     ecx, -11            ; STD_OUTPUT_HANDLE
        call    GetStdHandle
        mov     [hOut], rax
        mov     ecx, -10            ; STD_INPUT_HANDLE
        call    GetStdHandle
        mov     [hIn], rax

        ; --- enable ANSI (virtual terminal) processing on output ---
        mov     rcx, [hOut]
        lea     rdx, [outMode]
        call    GetConsoleMode
        mov     rcx, [hOut]
        mov     edx, [outMode]
        or      edx, 0x0005         ; PROCESSED_OUTPUT | VT_PROCESSING
        call    SetConsoleMode

        ; --- put input in raw mode (no line buffering, no echo) ---
        mov     rcx, [hIn]
        lea     rdx, [inMode]
        call    GetConsoleMode
        mov     rcx, [hIn]
        xor     edx, edx            ; clears LINE_INPUT and ECHO_INPUT
        call    SetConsoleMode

        call    draw_static
        call    game_init
        call    update_speed

        call    GetTickCount64
        mov     [last_tick], rax
        mov     dword [grav_acc], 0

.loop:
        ; accumulate the time that passed since the previous frame
        call    GetTickCount64
        mov     rcx, [last_tick]
        mov     [last_tick], rax
        sub     rax, rcx
        add     [grav_acc], eax

        ; handle any pending keypresses
        call    poll_input
        cmp     byte [quit_flag], 1
        je      .cleanup

        ; drop the piece once per elapsed gravity interval
.gravity:
        mov     eax, [grav_acc]
        mov     ecx, [drop_ms]
        cmp     eax, ecx
        jb      .draw
        sub     [grav_acc], ecx
        call    step_down
        cmp     byte [game_over], 1
        je      .over
        jmp     .gravity

.draw:
        call    render
        mov     ecx, 16             ; ~60 polls/sec
        call    Sleep
        jmp     .loop

.over:
        call    record_score        ; save this run before the banner
        call    draw_gameover
        call    wait_key

.cleanup:
        lea     rdx, [cleanup_seq]
        mov     r8d, cleanup_len
        call    write_str
        mov     rcx, [hIn]
        mov     edx, [inMode]       ; restore the original input mode
        call    SetConsoleMode
        xor     ecx, ecx
        call    ExitProcess

; -------------------------------------------------------------------
; draw_static : paint the parts of the screen that never change
;   (frame, stat labels, controls legend). Drawn once at startup.
; -------------------------------------------------------------------
draw_static:
        sub     rsp, 56

        ; clear screen, hide cursor, switch to green
        lea     rdx, [init_seq]
        mov     r8d, init_len
        call    write_str

        ; left/right side markers down each of the 20 board rows
        xor     r13d, r13d
.sides:
        mov     ecx, r13d
        add     ecx, FIELD_ROW0
        mov     edx, FIELD_COL0 - 2
        call    move_cursor
        lea     rdx, [left_mark]
        mov     r8d, 2
        call    write_str

        mov     ecx, r13d
        add     ecx, FIELD_ROW0
        mov     edx, FIELD_COL0 + 20
        call    move_cursor
        lea     rdx, [right_mark]
        mov     r8d, 2
        call    write_str

        inc     r13d
        cmp     r13d, 20
        jl      .sides

        ; top and bottom edges of the frame
        mov     ecx, FIELD_ROW0 - 1
        mov     edx, FIELD_COL0 - 2
        call    move_cursor
        lea     rdx, [top_border]
        mov     r8d, top_len
        call    write_str

        mov     ecx, FIELD_ROW0 + 20
        mov     edx, FIELD_COL0 - 2
        call    move_cursor
        lea     rdx, [bot_border]
        mov     r8d, bot_len
        call    write_str

        ; stat labels down the left panel
        mov     ecx, 3
        mov     edx, 2
        call    move_cursor
        lea     rdx, [lbl_lines]
        mov     r8d, 6
        call    write_str
        mov     ecx, 4
        mov     edx, 2
        call    move_cursor
        lea     rdx, [lbl_level]
        mov     r8d, 6
        call    write_str
        mov     ecx, 5
        mov     edx, 2
        call    move_cursor
        lea     rdx, [lbl_score]
        mov     r8d, 6
        call    write_str

        ; controls legend down the right panel
        mov     ecx, 3
        mov     edx, 44
        call    move_cursor
        lea     rdx, [c_title]
        mov     r8d, c_title_len
        call    write_str
        mov     ecx, 5
        mov     edx, 44
        call    move_cursor
        lea     rdx, [c_line1]
        mov     r8d, c_line1_len
        call    write_str
        mov     ecx, 6
        mov     edx, 44
        call    move_cursor
        lea     rdx, [c_line2]
        mov     r8d, c_line2_len
        call    write_str
        mov     ecx, 7
        mov     edx, 44
        call    move_cursor
        lea     rdx, [c_line3]
        mov     r8d, c_line3_len
        call    write_str
        mov     ecx, 8
        mov     edx, 44
        call    move_cursor
        lea     rdx, [c_line4]
        mov     r8d, c_line4_len
        call    write_str
        mov     ecx, 9
        mov     edx, 44
        call    move_cursor
        lea     rdx, [c_line5]
        mov     r8d, c_line5_len
        call    write_str

        mov     ecx, NEXT_ROW - 1
        mov     edx, NEXT_COL
        call    move_cursor
        lea     rdx, [lbl_next]
        mov     r8d, lbl_next_len
        call    write_str

        add     rsp, 56
        ret

; -------------------------------------------------------------------
; wait_key : block until the user presses a key (used on exit screens)
; -------------------------------------------------------------------
wait_key:
        sub     rsp, 56
.again:
        mov     rcx, [hIn]
        lea     rdx, [inbuf]
        mov     r8d, 32
        lea     r9, [numRead]
        call    ReadConsoleInputA   ; blocks until at least one event

        ; scan the batch for a key-down event
        xor     r10d, r10d
.scan:
        cmp     r10d, [numRead]
        jge     .again
        mov     eax, r10d
        imul    eax, eax, 20        ; INPUT_RECORD is 20 bytes
        lea     r11, [inbuf]
        add     r11, rax
        movzx   eax, word [r11]     ; EventType
        cmp     eax, 1              ; KEY_EVENT
        jne     .next
        mov     eax, [r11 + 4]      ; bKeyDown
        test    eax, eax
        jnz     .done
.next:
        inc     r10d
        jmp     .scan
.done:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; write_str : write R8D bytes at RDX to the console/output handle.
;   Uses WriteFile so output can also be redirected to a file.
;   Clobbers only volatile registers.
; -------------------------------------------------------------------
write_str:
        sub     rsp, 56
        mov     rcx, [hOut]
        ; rdx = buffer, r8 = length already in place
        lea     r9, [dwWritten]
        mov     qword [rsp + 32], 0 ; lpOverlapped = NULL
        call    WriteFile
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; move_cursor : position the cursor at row ECX, col EDX (1-based).
;   Emits ESC[<row>;<col>H. Clobbers RDI and volatile registers.
; -------------------------------------------------------------------
move_cursor:
        sub     rsp, 56
        mov     r10d, ecx           ; stash row (ECX/EDX get reused below)
        mov     r11d, edx           ; stash col

        lea     rdi, [mcbuf]
        mov     byte [rdi], 27      ; ESC
        inc     rdi
        mov     byte [rdi], '['
        inc     rdi
        mov     eax, r10d
        call    u32_to_ascii
        mov     byte [rdi], ';'
        inc     rdi
        mov     eax, r11d
        call    u32_to_ascii
        mov     byte [rdi], 'H'
        inc     rdi

        lea     rax, [mcbuf]
        sub     rdi, rax            ; RDI now holds the byte count
        mov     r8, rdi
        lea     rdx, [mcbuf]
        call    write_str

        add     rsp, 56
        ret

; -------------------------------------------------------------------
; u32_to_ascii : write EAX as decimal digits to [RDI], advancing RDI.
;   Leaf routine. Digits are gathered low-to-high on the stack, then
;   emitted in the correct order. Clobbers EAX, ECX, EDX, R9.
; -------------------------------------------------------------------
u32_to_ascii:
        mov     ecx, 10             ; divisor
        xor     r9d, r9d            ; digit counter
.gather:
        xor     edx, edx
        div     ecx                 ; EAX /= 10, EDX = next digit
        add     dl, '0'
        push    rdx
        inc     r9d
        test    eax, eax
        jnz     .gather
.emit:
        pop     rdx
        mov     [rdi], dl
        inc     rdi
        dec     r9d
        jnz     .emit
        ret

; -------------------------------------------------------------------
; print_uint : print EAX as decimal at the current cursor, then two
;   spaces to erase any leftover digits from a previously wider value.
; -------------------------------------------------------------------
print_uint:
        sub     rsp, 56
        lea     rdi, [numbuf]
        call    u32_to_ascii        ; digits into numbuf, RDI advanced
        lea     rax, [numbuf]
        sub     rdi, rax            ; RDI = number of digits
        mov     r8, rdi
        lea     rdx, [numbuf]
        call    write_str
        lea     rdx, [two_spaces]
        mov     r8d, 2
        call    write_str
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; rng_next : xorshift32 pseudo-random generator. Returns EAX. Leaf.
; -------------------------------------------------------------------
rng_next:
        mov     eax, [seed]
        mov     edx, eax
        shl     edx, 13
        xor     eax, edx
        mov     edx, eax
        shr     edx, 17
        xor     eax, edx
        mov     edx, eax
        shl     edx, 5
        xor     eax, edx
        mov     [seed], eax
        ret

; -------------------------------------------------------------------
; rng_piece : return EAX = a random piece id in 1..7.
; -------------------------------------------------------------------
rng_piece:
        sub     rsp, 56
        call    rng_next
        xor     edx, edx
        mov     ecx, 7
        div     ecx                 ; EDX = EAX mod 7  -> 0..6
        lea     eax, [edx + 1]
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; piece_cell : AL = test piece's 4x4 cell at (R10=row, R11=col).
;   Leaf. Preserves R10/R11; clobbers EAX, ECX, EDX.
; -------------------------------------------------------------------
piece_cell:
        mov     eax, [tst_id]
        dec     eax
        imul    eax, eax, 64
        mov     edx, [tst_rot]
        imul    edx, edx, 16
        add     eax, edx
        mov     edx, r10d
        imul    edx, edx, 4
        add     eax, edx
        add     eax, r11d
        lea     rcx, [pieces]
        movzx   eax, byte [rcx + rax]
        ret

; -------------------------------------------------------------------
; copy_cur_to_tst : mirror the active piece into the test slots so a
;   candidate move/rotation can be validated before committing. Leaf.
; -------------------------------------------------------------------
copy_cur_to_tst:
        mov     eax, [cur_id]
        mov     [tst_id], eax
        mov     eax, [cur_rot]
        mov     [tst_rot], eax
        mov     eax, [cur_x]
        mov     [tst_x], eax
        mov     eax, [cur_y]
        mov     [tst_y], eax
        ret

; -------------------------------------------------------------------
; spawn_piece : promote the queued piece to active and queue a fresh
;   one, positioned top-centre.
; -------------------------------------------------------------------
spawn_piece:
        sub     rsp, 56
        mov     eax, [next_id]
        mov     [cur_id], eax
        call    rng_piece
        mov     [next_id], eax
        mov     dword [cur_rot], 0
        mov     dword [cur_x], 3
        mov     dword [cur_y], 0
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; poll_input : drain the console input queue (non-blocking) and act on
;   any key-down events. Does nothing if the queue is empty.
; -------------------------------------------------------------------
poll_input:
        sub     rsp, 56
        mov     rcx, [hIn]
        lea     rdx, [numEvents]
        call    GetNumberOfConsoleInputEvents
        mov     eax, [numEvents]
        test    eax, eax
        jz      .none               ; nothing waiting

        mov     rcx, [hIn]
        lea     rdx, [inbuf]
        mov     r8d, 32
        lea     r9, [numRead]
        call    ReadConsoleInputA

        mov     dword [poll_i], 0
.rec:
        mov     eax, [poll_i]
        cmp     eax, [numRead]
        jge     .none
        imul    eax, eax, 20        ; INPUT_RECORD stride
        lea     r11, [inbuf]
        add     r11, rax
        movzx   eax, word [r11]     ; EventType
        cmp     eax, 1              ; KEY_EVENT
        jne     .next
        mov     eax, [r11 + 4]      ; bKeyDown
        test    eax, eax
        jz      .next               ; ignore key-release
        movzx   eax, word [r11 + 10]; wVirtualKeyCode
        call    dispatch_key
.next:
        inc     dword [poll_i]
        jmp     .rec
.none:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; dispatch_key : run the action bound to virtual-key code EAX.
;   Arrow keys and the numeric-keypad layout both work.
; -------------------------------------------------------------------
dispatch_key:
        sub     rsp, 56
        mov     ecx, eax            ; keep the key; calls clobber EAX
        cmp     ecx, 0x25           ; Left arrow
        je      .left
        cmp     ecx, 0x37           ; '7'
        je      .left
        cmp     ecx, 0x67           ; Numpad 7
        je      .left
        cmp     ecx, 0x27           ; Right arrow
        je      .right
        cmp     ecx, 0x39           ; '9'
        je      .right
        cmp     ecx, 0x69           ; Numpad 9
        je      .right
        cmp     ecx, 0x26           ; Up arrow
        je      .rotate
        cmp     ecx, 0x38           ; '8'
        je      .rotate
        cmp     ecx, 0x68           ; Numpad 8
        je      .rotate
        cmp     ecx, 0x28           ; Down arrow
        je      .soft
        cmp     ecx, 0x34           ; '4'
        je      .soft
        cmp     ecx, 0x64           ; Numpad 4
        je      .soft
        cmp     ecx, 0x20           ; Space
        je      .hard
        cmp     ecx, 0x1B           ; Esc
        je      .quit
        cmp     ecx, 0x51           ; 'Q'
        je      .quit
        jmp     .done
.left:
        call    move_left
        jmp     .done
.right:
        call    move_right
        jmp     .done
.rotate:
        call    rotate
        jmp     .done
.soft:
        call    soft_drop
        jmp     .done
.hard:
        call    hard_drop
        jmp     .done
.quit:
        mov     byte [quit_flag], 1
.done:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; move_left / move_right : shift the piece one column if there is room.
; -------------------------------------------------------------------
move_left:
        sub     rsp, 56
        call    copy_cur_to_tst
        dec     dword [tst_x]
        call    collides
        test    al, al
        jnz     .blocked
        mov     eax, [tst_x]
        mov     [cur_x], eax
.blocked:
        add     rsp, 56
        ret

move_right:
        sub     rsp, 56
        call    copy_cur_to_tst
        inc     dword [tst_x]
        call    collides
        test    al, al
        jnz     .blocked
        mov     eax, [tst_x]
        mov     [cur_x], eax
.blocked:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; rotate : turn the piece 90 degrees clockwise. If the turned piece
;   overlaps a wall, try nudging it one column right, then one column
;   left of its origin (a simple wall kick) before giving up.
; -------------------------------------------------------------------
rotate:
        sub     rsp, 56
        call    copy_cur_to_tst
        mov     eax, [cur_rot]
        inc     eax
        and     eax, 3              ; wrap 0..3
        mov     [tst_rot], eax

        call    collides
        test    al, al
        jz      .commit             ; fits where it stands
        inc     dword [tst_x]       ; kick one column right
        call    collides
        test    al, al
        jz      .commit
        mov     eax, [cur_x]        ; kick one column left of the origin
        dec     eax
        mov     [tst_x], eax
        call    collides
        test    al, al
        jz      .commit
        add     rsp, 56             ; no room even after kicking
        ret
.commit:
        mov     eax, [tst_rot]
        mov     [cur_rot], eax
        mov     eax, [tst_x]        ; keep any kick offset
        mov     [cur_x], eax
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; soft_drop : nudge the piece down one row on demand.
; -------------------------------------------------------------------
soft_drop:
        sub     rsp, 56
        call    step_down
        mov     dword [grav_acc], 0 ; restart the gravity timer
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; hard_drop : drop the piece straight to the bottom and lock it.
; -------------------------------------------------------------------
hard_drop:
        sub     rsp, 56
.fall:
        call    copy_cur_to_tst
        inc     dword [tst_y]
        call    collides
        test    al, al
        jnz     .land               ; next row down is blocked
        mov     eax, [tst_y]
        mov     [cur_y], eax
        jmp     .fall
.land:
        call    step_down           ; can no longer fall -> lock + spawn
        mov     dword [grav_acc], 0 ; the fresh piece starts its fall clean
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; collides : AL = 1 if the test piece (tst_*) overlaps a wall, the
;   floor, or a filled board cell; 0 otherwise. Cells above the top
;   edge are allowed so a piece can rotate/enter from off-screen.
; -------------------------------------------------------------------
collides:
        sub     rsp, 56
        xor     r10d, r10d
.row:
        xor     r11d, r11d
.col:
        call    piece_cell
        test    al, al
        jz      .next               ; empty piece cell -> nothing to test
        mov     eax, [tst_x]
        add     eax, r11d           ; board col
        js      .hit                ; past the left wall
        cmp     eax, 10
        jge     .hit                ; past the right wall
        mov     ecx, [tst_y]
        add     ecx, r10d           ; board row
        cmp     ecx, 20
        jge     .hit                ; below the floor
        cmp     ecx, 0
        jl      .next               ; above the top -> allowed
        imul    ecx, ecx, 10
        add     ecx, eax
        lea     r8, [board]
        movzx   edx, byte [r8 + rcx]
        test    dl, dl
        jnz     .hit                ; cell already occupied
.next:
        inc     r11d
        cmp     r11d, 4
        jl      .col
        inc     r10d
        cmp     r10d, 4
        jl      .row
        xor     al, al
        add     rsp, 56
        ret
.hit:
        mov     al, 1
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; lock_piece : write the active piece's cells into the board.
; -------------------------------------------------------------------
lock_piece:
        sub     rsp, 56
        call    copy_cur_to_tst
        xor     r10d, r10d
.row:
        xor     r11d, r11d
.col:
        call    piece_cell
        test    al, al
        jz      .next
        mov     eax, [cur_y]
        add     eax, r10d
        cmp     eax, 0
        jl      .next
        cmp     eax, 20
        jge     .next
        mov     edx, [cur_x]
        add     edx, r11d
        imul    eax, eax, 10
        add     eax, edx
        mov     edx, [cur_id]
        lea     r8, [board]
        mov     [r8 + rax], dl
.next:
        inc     r11d
        cmp     r11d, 4
        jl      .col
        inc     r10d
        cmp     r10d, 4
        jl      .row
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; step_down : move the piece down one row. If it cannot fall, lock it,
;   spawn the next piece, and flag game over if that one has no room.
; -------------------------------------------------------------------
step_down:
        sub     rsp, 56
        call    copy_cur_to_tst
        inc     dword [tst_y]
        call    collides
        test    al, al
        jnz     .lock
        mov     eax, [tst_y]        ; room below -> commit the drop
        mov     [cur_y], eax
        add     rsp, 56
        ret
.lock:
        call    lock_piece
        call    clear_lines
        call    spawn_piece
        call    copy_cur_to_tst
        call    collides
        test    al, al
        jz      .done
        mov     byte [game_over], 1
.done:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; update_speed : set the gravity interval from the current level.
;   Starts at 800 ms and shortens by 70 ms per level, floored at 80.
;   Leaf.
; -------------------------------------------------------------------
update_speed:
        mov     eax, [level]
        dec     eax
        imul    eax, eax, 70
        mov     ecx, 800
        sub     ecx, eax
        cmp     ecx, 80
        jge     .ok
        mov     ecx, 80
.ok:
        mov     [drop_ms], ecx
        ret

; -------------------------------------------------------------------
; draw_gameover : overlay the GAME OVER banner across the field.
; -------------------------------------------------------------------
draw_gameover:
        sub     rsp, 56
        mov     ecx, FIELD_ROW0 + 9
        mov     edx, FIELD_COL0 + 6
        call    move_cursor
        lea     rdx, [msg_over]
        mov     r8d, over_len
        call    write_str
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; game_init : clear the board and state, then spawn the first piece.
; -------------------------------------------------------------------
game_init:
        sub     rsp, 56
        lea     r8, [board]
        xor     eax, eax
.clr:
        mov     byte [r8 + rax], 0
        inc     eax
        cmp     eax, 200
        jl      .clr

        mov     dword [score], 0
        mov     dword [lines], 0
        mov     dword [level], 1
        mov     dword [drop_ms], 800
        mov     dword [grav_acc], 0
        mov     byte  [game_over], 0
        mov     byte  [quit_flag], 0

        ; seed the RNG from the millisecond clock (never zero)
        call    GetTickCount64
        mov     [seed], eax
        cmp     dword [seed], 0
        jne     .seeded
        mov     dword [seed], 1
.seeded:
        call    rng_piece
        mov     [next_id], eax
        call    spawn_piece
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; render : draw the playfield interior (board + falling piece) and the
;   stat numbers. The static frame is drawn separately, once.
; -------------------------------------------------------------------
render:
        sub     rsp, 56

        ; --- copy the board into the scratch grid ---
        xor     eax, eax
        lea     r8, [board]
        lea     r9, [scratch]
.copy:
        mov     cl, [r8 + rax]
        mov     [r9 + rax], cl
        inc     eax
        cmp     eax, 200
        jl      .copy

        ; --- stamp the falling piece into the scratch grid ---
        call    copy_cur_to_tst
        xor     r10d, r10d          ; row within the 4x4 box
.srow:
        xor     r11d, r11d          ; col within the 4x4 box
.scol:
        call    piece_cell
        test    al, al
        jz      .snext
        mov     eax, [cur_y]
        add     eax, r10d           ; board row
        js      .snext              ; still above the top -> not drawn
        cmp     eax, 20
        jge     .snext
        mov     edx, [cur_x]
        add     edx, r11d           ; board col
        imul    eax, eax, 10
        add     eax, edx
        mov     edx, [cur_id]
        lea     r8, [scratch]
        mov     [r8 + rax], dl
.snext:
        inc     r11d
        cmp     r11d, 4
        jl      .scol
        inc     r10d
        cmp     r10d, 4
        jl      .srow

        ; --- draw the 20 board rows ---
        xor     r13d, r13d          ; board row index
.rowdraw:
        mov     ecx, r13d
        add     ecx, FIELD_ROW0
        mov     edx, FIELD_COL0
        call    move_cursor

        mov     eax, r13d
        imul    eax, eax, 10
        mov     r14d, eax           ; scratch base index for this row
        xor     r15d, r15d          ; board col index
        lea     rdi, [rowbuf]
.cell:
        mov     eax, r14d
        add     eax, r15d
        lea     r8, [scratch]
        movzx   eax, byte [r8 + rax]
        test    al, al
        jz      .empty
        mov     byte [rdi], '['     ; filled cell
        mov     byte [rdi + 1], ']'
        jmp     .putnext
.empty:
        mov     byte [rdi], ' '     ; empty cell shown as a dot
        mov     byte [rdi + 1], '.'
.putnext:
        add     rdi, 2
        inc     r15d
        cmp     r15d, 10
        jl      .cell

        lea     rdx, [rowbuf]
        mov     r8d, 20             ; 10 cells x 2 chars
        call    write_str

        inc     r13d
        cmp     r13d, 20
        jl      .rowdraw

        ; --- draw the stat numbers ---
        mov     ecx, 3
        mov     edx, STAT_COL
        call    move_cursor
        mov     eax, [lines]
        call    print_uint
        mov     ecx, 4
        mov     edx, STAT_COL
        call    move_cursor
        mov     eax, [level]
        call    print_uint
        mov     ecx, 5
        mov     edx, STAT_COL
        call    move_cursor
        mov     eax, [score]
        call    print_uint

        call    draw_next

        add     rsp, 56
        ret

; -------------------------------------------------------------------
; draw_next : show the queued piece (rotation 0) in the preview box.
; -------------------------------------------------------------------
draw_next:
        sub     rsp, 56
        mov     eax, [next_id]      ; preview the queued piece...
        mov     [tst_id], eax
        mov     dword [tst_rot], 0  ; ...in its spawn orientation

        xor     r13d, r13d          ; row within the 4x4 box
.nrow:
        mov     ecx, r13d
        add     ecx, NEXT_ROW
        mov     edx, NEXT_COL
        call    move_cursor

        mov     r10d, r13d          ; piece_cell reads row in R10
        xor     r11d, r11d          ; col within the 4x4 box
        lea     rdi, [rowbuf]
.ncell:
        call    piece_cell
        test    al, al
        jz      .nempty
        mov     byte [rdi], '['
        mov     byte [rdi + 1], ']'
        jmp     .nput
.nempty:
        mov     byte [rdi], ' '     ; blank, not a dot, outside the field
        mov     byte [rdi + 1], ' '
.nput:
        add     rdi, 2
        inc     r11d
        cmp     r11d, 4
        jl      .ncell

        lea     rdx, [rowbuf]
        mov     r8d, 8              ; 4 cells x 2 chars
        call    write_str

        inc     r13d
        cmp     r13d, 4
        jl      .nrow
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; remove_row : delete board row ECX by shifting every row above it
;   down one, then clearing the top row. Leaf.
; -------------------------------------------------------------------
remove_row:
        mov     r8d, ecx            ; i = row to remove
.shift:
        test    r8d, r8d
        jz      .top
        lea     rsi, [board]        ; src = row i-1
        mov     eax, r8d
        dec     eax
        imul    eax, eax, 10
        add     rsi, rax
        lea     rdi, [board]        ; dest = row i
        mov     eax, r8d
        imul    eax, eax, 10
        add     rdi, rax
        mov     ecx, 10
        cld
        rep     movsb               ; copy 10 cells downward
        dec     r8d
        jmp     .shift
.top:
        lea     rdi, [board]        ; clear the now-empty top row
        xor     eax, eax
        mov     ecx, 10
        rep     stosb
        ret

; -------------------------------------------------------------------
; clear_lines : remove every full row, then update the line count,
;   score, level and gravity speed. Cleared rows this call go in R12.
; -------------------------------------------------------------------
clear_lines:
        sub     rsp, 56
        xor     r12d, r12d          ; lines cleared this call
        mov     r10d, 19            ; scan from the bottom row upward
.check:
        cmp     r10d, 0
        jl      .score
        mov     eax, r10d
        imul    eax, eax, 10
        mov     esi, eax            ; base index of this row
        xor     r11d, r11d
.scan:
        mov     eax, esi
        add     eax, r11d
        lea     r8, [board]
        movzx   edx, byte [r8 + rax]
        test    dl, dl
        jz      .notfull            ; a hole -> row is not complete
        inc     r11d
        cmp     r11d, 10
        jl      .scan
        ; the row is full: remove it and re-test the same index
        mov     ecx, r10d
        call    remove_row
        inc     dword [lines]
        inc     r12d
        jmp     .check
.notfull:
        dec     r10d
        jmp     .check
.score:
        test    r12d, r12d
        jz      .done
        ; score += points_tbl[cleared] * level
        lea     rcx, [points_tbl]
        mov     eax, [rcx + r12*4]
        imul    eax, dword [level]
        add     [score], eax
        ; level = lines / 10 + 1
        mov     eax, [lines]
        xor     edx, edx
        mov     ecx, 10
        div     ecx
        inc     eax
        mov     [level], eax
        call    update_speed
.done:
        add     rsp, 56
        ret

; ===================================================================
; Scoreboard : persist a ranked top-10 of past runs in scores.txt
; ===================================================================

; -------------------------------------------------------------------
; record_score : load the saved scores, add this run, sort, keep the
;   top 10, and write them back.
; -------------------------------------------------------------------
record_score:
        sub     rsp, 56
        call    load_scores
        mov     ecx, [sb_count]
        cmp     ecx, 40
        jge     .sorted             ; table full, don't append
        lea     r8, [sb_score]      ; append the current run
        mov     eax, [score]
        mov     [r8 + rcx*4], eax
        lea     r8, [sb_lines]
        mov     eax, [lines]
        mov     [r8 + rcx*4], eax
        lea     r8, [sb_level]
        mov     eax, [level]
        mov     [r8 + rcx*4], eax
        inc     dword [sb_count]
.sorted:
        call    sort_scores
        cmp     dword [sb_count], 10
        jle     .save
        mov     dword [sb_count], 10; keep only the best ten
.save:
        call    save_scores
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; load_scores : read scores.txt into the in-memory arrays. A missing
;   file just means an empty board.
; -------------------------------------------------------------------
load_scores:
        sub     rsp, 56
        mov     dword [sb_count], 0
        lea     rcx, [fname_scores]
        mov     edx, 0x80000000     ; GENERIC_READ
        mov     r8d, 1              ; FILE_SHARE_READ
        xor     r9, r9
        mov     qword [rsp + 32], 3 ; OPEN_EXISTING
        mov     qword [rsp + 40], 0x80  ; FILE_ATTRIBUTE_NORMAL
        mov     qword [rsp + 48], 0
        call    CreateFileA
        cmp     rax, -1             ; INVALID_HANDLE_VALUE -> no file
        je      .none
        mov     [sb_handle], rax

        mov     rcx, [sb_handle]
        lea     rdx, [filebuf]
        mov     r8d, 4095
        lea     r9, [numRead]
        mov     qword [rsp + 32], 0 ; lpOverlapped = NULL
        call    ReadFile
        mov     eax, [numRead]      ; NUL-terminate the buffer
        lea     rcx, [filebuf]
        mov     byte [rcx + rax], 0

        mov     rcx, [sb_handle]
        call    CloseHandle
        call    parse_scores
.none:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; parse_scores : read whitespace-separated (score,lines,level) triples
;   out of filebuf into the arrays. RSI walks the buffer.
; -------------------------------------------------------------------
parse_scores:
        sub     rsp, 56
        lea     rsi, [filebuf]
.rec:
        cmp     dword [sb_count], 40
        jge     .done
        call    skip_nondigit
        mov     al, [rsi]           ; a record must start with a digit
        cmp     al, '0'
        jb      .done               ; NUL or trailing junk -> stop
        cmp     al, '9'
        ja      .done
        call    parse_uint          ; score
        mov     ecx, [sb_count]
        lea     r8, [sb_score]
        mov     [r8 + rcx*4], eax
        call    skip_nondigit
        call    parse_uint          ; lines
        mov     ecx, [sb_count]
        lea     r8, [sb_lines]
        mov     [r8 + rcx*4], eax
        call    skip_nondigit
        call    parse_uint          ; level
        mov     ecx, [sb_count]
        lea     r8, [sb_level]
        mov     [r8 + rcx*4], eax
        inc     dword [sb_count]
        jmp     .rec
.done:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; skip_nondigit : advance RSI past any non-digit bytes, stopping at a
;   digit or the NUL terminator. Leaf.
; -------------------------------------------------------------------
skip_nondigit:
        mov     al, [rsi]
        test    al, al
        jz      .stop
        cmp     al, '0'
        jb      .skip
        cmp     al, '9'
        ja      .skip
        ret                         ; sitting on a digit
.skip:
        inc     rsi
        jmp     skip_nondigit
.stop:
        ret

; -------------------------------------------------------------------
; parse_uint : read a decimal number at RSI into EAX, advancing RSI.
;   Leaf.
; -------------------------------------------------------------------
parse_uint:
        xor     eax, eax
.next:
        mov     dl, [rsi]
        cmp     dl, '0'
        jb      .stop
        cmp     dl, '9'
        ja      .stop
        imul    eax, eax, 10
        movzx   edx, dl
        sub     edx, '0'
        add     eax, edx
        inc     rsi
        jmp     .next
.stop:
        ret

; -------------------------------------------------------------------
; sort_scores : selection sort the entries by score, highest first.
; -------------------------------------------------------------------
sort_scores:
        sub     rsp, 56
        xor     r10d, r10d          ; i
.outer:
        mov     eax, [sb_count]
        dec     eax
        cmp     r10d, eax
        jge     .done               ; i >= count-1
        mov     r11d, r10d          ; index of the largest score so far
        lea     ecx, [r10 + 1]      ; j = i+1
.inner:
        cmp     ecx, [sb_count]
        jge     .placed
        lea     r8, [sb_score]
        mov     eax, [r8 + rcx*4]
        mov     edx, [r8 + r11*4]
        cmp     eax, edx
        jle     .nextj
        mov     r11d, ecx           ; found a larger score
.nextj:
        inc     ecx
        jmp     .inner
.placed:
        cmp     r11d, r10d
        je      .nexti
        call    swap_entries
.nexti:
        inc     r10d
        jmp     .outer
.done:
        add     rsp, 56
        ret

; -------------------------------------------------------------------
; swap_entries : swap scoreboard entries R10 and R11 across all three
;   parallel arrays. Leaf. Preserves R10/R11.
; -------------------------------------------------------------------
swap_entries:
        lea     r8, [sb_score]
        mov     eax, [r8 + r10*4]
        mov     edx, [r8 + r11*4]
        mov     [r8 + r10*4], edx
        mov     [r8 + r11*4], eax
        lea     r8, [sb_lines]
        mov     eax, [r8 + r10*4]
        mov     edx, [r8 + r11*4]
        mov     [r8 + r10*4], edx
        mov     [r8 + r11*4], eax
        lea     r8, [sb_level]
        mov     eax, [r8 + r10*4]
        mov     edx, [r8 + r11*4]
        mov     [r8 + r10*4], edx
        mov     [r8 + r11*4], eax
        ret

; -------------------------------------------------------------------
; save_scores : format the entries as "score lines level" lines and
;   overwrite scores.txt.
; -------------------------------------------------------------------
save_scores:
        sub     rsp, 56
        lea     rdi, [sbtext]       ; build the file text
        xor     r10d, r10d
.line:
        cmp     r10d, [sb_count]
        jge     .write
        lea     r8, [sb_score]
        mov     eax, [r8 + r10*4]
        call    u32_to_ascii
        mov     byte [rdi], ' '
        inc     rdi
        lea     r8, [sb_lines]
        mov     eax, [r8 + r10*4]
        call    u32_to_ascii
        mov     byte [rdi], ' '
        inc     rdi
        lea     r8, [sb_level]
        mov     eax, [r8 + r10*4]
        call    u32_to_ascii
        mov     byte [rdi], 10      ; newline
        inc     rdi
        inc     r10d
        jmp     .line
.write:
        lea     rax, [sbtext]
        sub     rdi, rax            ; total byte count
        mov     [sbtext_len], rdi

        lea     rcx, [fname_scores]
        mov     edx, 0x40000000     ; GENERIC_WRITE
        xor     r8d, r8d            ; no sharing
        xor     r9, r9
        mov     qword [rsp + 32], 2 ; CREATE_ALWAYS
        mov     qword [rsp + 40], 0x80
        mov     qword [rsp + 48], 0
        call    CreateFileA
        cmp     rax, -1
        je      .done
        mov     [sb_handle], rax

        mov     rcx, [sb_handle]
        lea     rdx, [sbtext]
        mov     r8d, [sbtext_len]
        lea     r9, [dwWritten]
        mov     qword [rsp + 32], 0
        call    WriteFile

        mov     rcx, [sb_handle]
        call    CloseHandle
.done:
        add     rsp, 56
        ret

