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
        extern  ExitProcess

; -------------------------------------------------------------------
; Layout constants (screen is 1-based for ANSI cursor moves)
; -------------------------------------------------------------------
FIELD_ROW0      equ 3               ; screen row of the first board row
FIELD_COL0      equ 20             ; screen col of the first board cell
STAT_COL        equ 9              ; column where stat numbers start

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

msg_over:       db "GAME OVER"
over_len        equ $ - msg_over

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

; ===================================================================
; Uninitialised buffers
; ===================================================================
        section .bss

mcbuf:          resb 32            ; scratch for a cursor-move escape
inbuf:          resb 640           ; 32 INPUT_RECORDs x 20 bytes

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
