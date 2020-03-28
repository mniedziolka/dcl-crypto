SYS_EXIT        equ 60
MIN_CHAR        equ 49 
MAX_CHAR        equ 90
MAX_ARG_LENGTH  equ 42

global _start

section .rodata

section .text

_start:
    cmp     QWORD[rsp], 5          ; sprawdz czy dobra liczba argumentow
    jne     fail                   ; niepoprawna liczba argumentow -> wyjdz z niezerowym
    lea     rbp, [rsp + 16]         ; adres args[1]
check_args_loop:
    mov     rsi, [rbp]
    test    rsi, rsi
    jz      calc_inverse_perm      ; Napotkano zerowy wskaźnik, nie ma więcej argumentów.
    xor     r8d, r8d               ; wyzeruj licznik pojedynczego argumentu
check_chars_loop:
    cmp     r8d, MAX_ARG_LENGTH    ; całe słowo wczytane, teraz musi być 0
    jl      check_single_char
    add     rbp, 8                 ; przejdz do nastepnego argumentu (rsi zostaje na starym)
    cmp     rsi, 0                 ; NULL terminator, następny argument
    je      check_args_loop
    jmp     fail                   ; jesli nie skoczylismy poprzednim to znaczy że za długie
check_single_char:
    cmp     byte[rsi], MIN_CHAR          ; czy w przedziale
    jl      fail
    cmp     byte[rsi], MAX_CHAR
    jg      fail
    inc     rsi                    ; następna literka
    inc     r8d                    ; licznik++
    jnp     check_chars_loop
calc_inverse_perm:
read_input:   
    xor     edi, edi               ; wyczysc edi, exit z 0
    jmp     exit
fail:
    mov     edi, 1          ; exit z codem 1
exit:
    mov     rax, SYS_EXIT
    syscall