SYS_EXIT        equ 60
SYS_WRITE       equ 1
STD_OUT         equ 1
MIN_CHAR        equ '1' 
MAX_CHAR        equ 'Z'
MAX_ARG_LENGTH  equ 42
BUFF_SIZE       equ 4096
POS_L           equ 'L' - MIN_CHAR
POS_R           equ 'R' - MIN_CHAR
POS_T           equ 'T' - MIN_CHAR
POS_MAX         equ MAX_CHAR - MIN_CHAR + 1

global _start

section .bss

Lperm: resb 8                                       ; Address of L permutation on stack
Rperm: resb 8                                       ; Address of R permutation on stack
Tperm: resb 8                                       ; Address of T permutation on stack
Linv:  resb MAX_ARG_LENGTH                          ; Inversion of L permutation
Rinv:  resb MAX_ARG_LENGTH                          ; Inversion of R permutation
buff:  resb BUFF_SIZE + 1                           ; Buffer for input-output


section .text

%macro modulo 0
    mov         ebx, esi
    sub         ebx, POS_MAX
    cmp         esi, MAX_CHAR
    cmovg       esi, ebx
%endmacro

; Makro do obracania bebenkow. Uruchamiane przed kazdym zaszyfrowaniem litery.
; Wejscie: r10 - pozycja bebenka L, r12 - pozycja bebenka R;
; Uzywane: rax, rbx, r10, r12; 
%macro apply_rot 0
    xor         eax, eax                            ; Zerujemy eax, zeby moc zerowac rejestry cmov.

    inc         r12d                                ; Przekrec bebenek R.

    cmp         r12d, POS_MAX                       ; Modulo POS_MAX.
    cmovge      r12d, eax                    

    mov         ebx, 1                              ; Wrzucimy na eax, jesli znajdzie sie w obrotowej.

    cmp         r12d, POS_L                         ; Sprawdzamy czy bebenek R jest w pozycji obrotowej.
    cmove       eax, ebx  
    cmp         r12d, POS_R
    cmove       eax, ebx
    cmp         r12d, POS_T
    cmove       eax, ebx

    cmp         eax, 0                              ; Jesli eax jest zerem to zaden z warunkow nie zaszedl.
    je          %%skip                              ; Nie zmieniaj stanu L.

    inc         r10d                                ; Przekrec bebenek L.
    xor         eax, eax
    cmp         r10d, POS_MAX                       ; Modulo POS_MAX.
    cmovge      r10d, eax                           
%%skip:
%endmacro

; Rotejt, permutuj, cofnij. rsi - source(tu podmieniamy literke), rdi-permutacja do zaaplikowania, rdx - przesun i wroc o tyle
%macro add_perm_sub 0
    add         esi, edx
    modulo
    sub         esi, MIN_CHAR
    movzx       esi, byte[rdi + rsi]
    add         esi, POS_MAX
    sub         esi, edx
    modulo
%endmacro

process_single_str:                ; Sparsuj i zinvertuj jeden argument. rsi - source, rdi - target, r8 - ile liter ma byc
    xor         ecx, ecx
.check_chars_loop:
    cmp         ecx, r8d                 ; całe słowo wczytane, teraz musi być 0
    jl          .check_single_char
    cmp         byte[rsi + rcx], 0           ; NULL terminator, następny argument
    jne         fail                   ; zbyt długie słowo
    ret
.check_single_char:
    movzx       eax, byte[rsi + rcx]
    cmp         al, MIN_CHAR            ; czy w przedziale
    jl          fail
    cmp         al, MAX_CHAR
    jg          fail
    test        rdi, rdi                ; czy trzeba liczyć permutacje
    jz          .next_char               ; jesli nie, to nastepna literka
    lea         rdx, [rdi + rax - MIN_CHAR] ; zaladuj adres na docelowej permutacji
    cmp         byte[rdx], 0
    jne         fail
    mov         eax, ecx
    add         eax, MIN_CHAR
    mov         byte[rdx], al
.next_char:
    inc         ecx                    ; licznik++
    jmp         .check_chars_loop

_start:
    cmp         qword[rsp], 5          ; sprawdz czy dobra liczba argumentow
    jne         fail                   ; niepoprawna liczba argumentow -> wyjdz z niezerowym
    mov         r8d, MAX_ARG_LENGTH
    lea         rbp, [rsp + 16]         ; adres args[1]
    mov         rsi, [rbp]
    mov         [Lperm], rsi             ; zapisz adres permutacji L
    mov         rdi, Linv
    call        process_single_str
    add         rbp, 8
    mov         rsi, [rbp]
    mov         [Rperm], rsi             ; zapisz adres permutacji R
    mov         rdi, Rinv
    call        process_single_str
    add         rbp, 8
    mov         rsi, [rbp]
    mov         [Tperm], rsi             ; zapisz adres permutacji T
    xor         edi, edi               ; wyczysc rdi, bo nie potrzebujemy inwersji T
    call        process_single_str
    xor         ecx, ecx                ; licznik
.check_T_permutation:                ; iterujemy sie po T i patrzymy czy poprawne zlozenie
    cmp         ecx, MAX_ARG_LENGTH
    je          .check_key
    xor         eax, eax
    mov         al, byte[rsi + rcx]     ; na al jest literka
    lea         r8, [rsi + rax - MIN_CHAR] ; zaladuj na r8 adres literki w permutacji
    cmp         al, byte[r8]
    je          fail                    ; punkt staly
    mov         edx, ecx                ; powinien byc wyzerowany
    add         edx, MIN_CHAR
    cmp         dl, byte[rsi + rax - MIN_CHAR]
    jne         fail                    ; nie ma dwuelementowego cyklu
    inc         ecx
    jmp         .check_T_permutation
.check_key:
    add         rbp, 8
    mov         rsi, [rbp]
    xor         edi, edi
    mov         r8d, 2                   ; ostatni argument ma tylko dwie literki
    call        process_single_str              
    movzx       r10d, byte[rsi]         ; L bembenek
    sub         r10d, MIN_CHAR
    inc         rsi
    movzx       r12d, byte[rsi]
    sub         r12d, MIN_CHAR
    inc         rsi
    cmp         byte[rsi], 0            ; sprawdzamy czy klucz szyfrowania nie jest zbyt dlugi
    jne         fail
.read_input:
    xor         eax, eax
    xor         edi, edi
    mov         rsi, buff
    mov         edx, BUFF_SIZE
    syscall
    mov         r11d, eax
    mov         rsi, buff
    mov         byte[buff + r11], 0
    mov         edi, 0
    mov         r8d, r11d
    call        process_single_str
    xor         ecx, ecx                ; wyzeruj licznik
.encode_buffer:
    apply_rot

    movzx       esi, byte[buff + rcx]

    mov         rdi, [Rperm]
    mov         edx, r12d
    add_perm_sub

    mov         rdi, [Lperm]
    mov         edx, r10d
    add_perm_sub

    mov         rdi, [Tperm]
    xor         edx, edx 
    add_perm_sub

    mov         rdi, Linv
    mov         edx, r10d
    add_perm_sub

    mov         rdi, Rinv
    mov         edx, r12d
    add_perm_sub

    mov         byte[buff + rcx], sil

    inc         ecx
    cmp         ecx, r11d                ; jesli przejrzelismy cale wejscie to print
    jl          .encode_buffer
.print_output:
    mov         eax, SYS_WRITE
    mov         edi, STD_OUT
    mov         rsi, buff
    mov         edx, r11d
    syscall
    cmp         edx, BUFF_SIZE
    jge         .read_input
    xor         edi, edi               ; wyczysc edi, exit z 0
    jmp         exit
fail:
    mov         edi, 1                 ; exit z codem 1
exit:
    mov         eax, SYS_EXIT
    syscall