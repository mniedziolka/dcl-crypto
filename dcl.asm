SYS_EXIT        equ 60
SYS_READ        equ 0
SYS_WRITE       equ 1
STD_IN          equ 0
STD_OUT         equ 1
MIN_CHAR        equ 49 
MAX_CHAR        equ 90
MAX_ARG_LENGTH  equ 42
BUFF_SIZE       equ 4096
POS_L           equ 76 - MIN_CHAR
POS_R           equ 82 - MIN_CHAR
POS_T           equ 84 - MIN_CHAR
POS_MAX         equ 42

global _start

section .bss

Lperm: resb 8                   ; Address of L permutation on stack
Rperm: resb 8                   ; Address of R permutation on stack
Tperm: resb 8                   ; Address of T permutation on stack
Linv:  resb MAX_ARG_LENGTH      ; Inversion of L permutation
Rinv:  resb MAX_ARG_LENGTH      ; Inversion of R permutation
buff:  resb 4097                ; Buffer for input-output


section .text

%macro modulo 0
    cmp     rax, MAX_CHAR
    jle     %%skip    
    sub     rax, POS_MAX
%%skip:
%endmacro

%macro apply_rot 0
    inc     r11
    cmp     r11, POS_MAX                       ; czy sie przekrecilo
    jle     %%in_range
    xor     r11, r11                           
%%in_range:
    cmp     r11, POS_L
    je      %%rot_L    
    cmp     r11, POS_R
    je      %%rot_L
    cmp     r11, POS_T
    jne     %%skip
%%rot_L:
    inc     r10
    cmp     r10, POS_MAX
    jle     %%skip
    xor     r10, r10
%%skip:
%endmacro

process_single_arg:                ; Sparsuj i zinvertuj jeden argument. rsi - source, rdi - target, r8 - ile liter ma byc
    xor     rcx, rcx
check_chars_loop:
    cmp     rcx, r8                 ; całe słowo wczytane, teraz musi być 0
    jl      check_single_char
    cmp     byte[rsi + rcx], 0           ; NULL terminator, następny argument
    jne     fail                   ; zbyt długie słowo
    ret
check_single_char:
    movzx   rax, byte[rsi + rcx]
    cmp     al, MIN_CHAR            ; czy w przedziale
    jl      fail
    cmp     al, MAX_CHAR
    jg      fail
    test    rdi, rdi                ; czy trzeba liczyć permutacje
    jz      next_char               ; jesli nie, to nastepna literka
    lea     rdx, [rdi + rax - MIN_CHAR] ; zaladuj adres na docelowej permutacji
    cmp     byte[rdx], 0
    jne     fail
    mov     [rdx], eax
next_char:
    inc     rcx                    ; licznik++
    jmp     check_chars_loop

add_perm_sub:                       ; Rotejt, permutuj, cofnij. rsi - source(tu podmieniamy literke), rdi-permutacja do zaaplikowania, rdx - przesun i wroc o tyle
    xor     rax, rax
    mov     al, byte[rsi]
    add     eax, edx
    modulo
    sub     eax, MIN_CHAR
    movzx   rax, byte[rdi + rax]
    add     eax, MIN_CHAR
    sub     eax, edx
    modulo
    mov     byte[rsi], al
    ret

_start:
    cmp     qword[rsp], 5          ; sprawdz czy dobra liczba argumentow
    jne     fail                   ; niepoprawna liczba argumentow -> wyjdz z niezerowym
    mov     r8, MAX_ARG_LENGTH
    lea     rbp, [rsp + 16]         ; adres args[1]
    mov     rsi, [rbp]
    mov     [Lperm], rsi             ; zapisz adres permutacji L
    mov     rdi, Linv
    call    process_single_arg
    add     rbp, 8
    mov     rsi, [rbp]
    mov     [Rperm], rsi             ; zapisz adres permutacji R
    mov     rdi, Rinv
    call    process_single_arg
    add     rbp, 8
    mov     rsi, [rbp]
    mov     [Tperm], rsi             ; zapisz adres permutacji T
    xor     rdi, rdi               ; wyczysc rdi, bo nie potrzebujemy inwersji T
    call    process_single_arg
    xor     rcx, rcx                ; licznik
check_T_permutation:                ; iterujemy sie po T i patrzymy czy poprawne zlozenie
    cmp     rcx, MAX_ARG_LENGTH
    je      check_key
    xor     rax, rax
    mov     al, byte[rsi + rcx]     ; na al jest literka
    lea     r8, [rsi + rax - MIN_CHAR] ; zaladuj na r8 adres literki w permutacji
    cmp     al, byte[r8]
    je      fail                    ; punkt staly
    mov     rdx, rcx                ; powinien byc wyzerowany
    add     rdx, MIN_CHAR
    cmp     dl, byte[rsi + rax - MIN_CHAR]
    jne     fail                    ; nie ma dwuelementowego cyklu
    inc     rcx
    jmp     check_T_permutation
check_key:
    add     rbp, 8
    mov     rsi, [rbp]
    xor     rdi, rdi
    mov     r8, 2                   ; ostatni argument ma tylko dwie literki
    call    process_single_arg
    xor     r10, r10               
    mov     r10b, byte[rsi]         ; L bembenek
    sub     r10b, MIN_CHAR
    inc     rsi
    xor     r11, r11
    mov     r11b, byte[rsi]
    sub     r11b, MIN_CHAR
read_input:
    xor     eax, eax
    xor     edi, edi
    mov     rsi, buff
    mov     edx, BUFF_SIZE
    syscall
    mov     r12, rax
    mov     rsi, buff
    mov     byte[buff + r12], 0
    mov     rdi, 0
    mov     r8, r12
    call    process_single_arg
    xor     rcx, rcx                ; wyzeruj licznik
encode_buffer:
    apply_rot

    lea     rsi, [buff + rcx]

    mov     rdi, [Rperm]
    mov     rdx, r11
    call    add_perm_sub

    mov     rdi, [Lperm]
    mov     rdx, r10
    call    add_perm_sub

    mov     rdi, [Tperm]
    xor     rdx, rdx 
    call    add_perm_sub

    mov     rdi, Linv
    mov     rdx, r10
    call    add_perm_sub

    mov     rdi, Rinv
    mov     rdx, r11
    call    add_perm_sub

    inc     rcx
    cmp     rcx, r12                ; jesli przejrzelismy cale wejscie to print
    jl      encode_buffer
print_output:
    mov     eax, SYS_WRITE
    mov     edi, STD_OUT
    mov     rsi, buff
    mov     rdx, r12
    syscall
    cmp     r12, BUFF_SIZE
    jge     read_input
    xor     rdi, rdi               ; wyczysc edi, exit z 0
    jmp     exit
fail:
    mov     edi, 1                 ; exit z codem 1
exit:
    mov     rax, SYS_EXIT
    syscall