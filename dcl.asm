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

; Makro do modulowania. Pilnuje by liczba była ponizej maksymalnej wartosci.
; Wejscie: rsi - litera;
; Uzywane: rsi, rbx;
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

    add         r12d, 1                             ; Przekrec bebenek R.

    cmp         r12d, POS_MAX                       ; Modulo POS_MAX.
    cmovge      r12d, eax                    

    mov         ebx, 1                              ; Wrzucimy na eax, jesli znajdzie sie w obrotowej.

    cmp         r12d, POS_L                         ; Sprawdzamy czy bebenek R jest w pozycji obrotowej.
    cmove       eax, ebx  
    cmp         r12d, POS_R
    cmove       eax, ebx
    cmp         r12d, POS_T
    cmove       eax, ebx

    test        eax, eax                            ; Jesli eax jest zerem to zaden z warunkow nie zaszedl.
    je          %%skip                              ; Nie zmieniaj stanu L.

    add         r10d, 1                             ; Przekrec bebenek L.
    xor         eax, eax
    cmp         r10d, POS_MAX                       ; Modulo POS_MAX.
    cmovge      r10d, eax                           
%%skip:
%endmacro


; Wykonaj Q_i, P_i, Q_{i^(-1)}.
; Wejscie: rsi - litera,
;          rdx - wartosc przesuniecia
;          rdi - permutacja
; Uzywane: rsi, rdx, rdi
add_perm_sub:
    add         esi, edx
    modulo
    sub         esi, MIN_CHAR
    movzx       esi, byte[rdi + rsi]
    add         esi, POS_MAX
    sub         esi, edx
    modulo
    ret


; Funkcja parsujaca pojedynczy ciag bajtow. Jesli rdi jest niezerowe to liczy odwrotnosc permutacji.
; Wejscie: rsi - adres slowa do sprawdzenia,
;          rdi - adres slowa do zapisania permutacji odwrotnej, jesli pusty to pomin,
;          r8  - dlugosc slowa;
; Uzywane: rsi, rdi, r8, rcx, rax, rbx, rdx
process_single_str:
    xor         ecx, ecx
.check_chars_loop:
    cmp         ecx, r8d                            ; Sprawdz czy przeszlismy cale slowo.
    jl          .check_single_char
    cmp         byte[rsi + rcx], 0                  ; Slowo musi byc zakonczone zerem.
    jne         fail                                ; Ponad r8 znakow.
    ret
.check_single_char:
    movzx       eax, byte[rsi + rcx]                ; Wczytaj litere.

    xor         edx, edx                            ; Jesli edx pozostanie zerem, to przedzial sie zgadza.
    mov         ebx, 1

    cmp         al, MIN_CHAR                        ; Sprawdz czy litera w przedziale.
    cmovl       edx, ebx
    cmp         al, MAX_CHAR
    cmovg       edx, ebx

    test        edx, edx                            ; Jesli edx niezerowe, litera spoza zakresu.
    jnz         fail

    test        rdi, rdi                            ; Sprawdz czy trzeba liczyc permutacje odwrotna.
    jz          .next_char                          ; Jesli nie, to przejdz do nastepnej literki.

    lea         rdx, [rdi + rax - MIN_CHAR]         ; Adres litery w docelowej permutacji.

    cmp         byte[rdx], 0                        ; Jesli nie zero, to znaczy ze na rsi nie ma permutacji.
    jne         fail

    mov         eax, ecx
    add         eax, MIN_CHAR
    mov         byte[rdx], al                       ; Zaladuj odpowiednia litere na docelowa permutacje.

.next_char:
    add         ecx, 1
    jmp         .check_chars_loop


_start:
    cmp         qword[rsp], 5                       ; Sprawdzenie liczby argumentow.
    jne         fail

    lea         rbp, [rsp + 16]                     ; Zaladuj adres args[1] na stosie.

    mov         r8d, MAX_ARG_LENGTH
    mov         rsi, [rbp]                          
    mov         [Lperm], rsi                        ; Zapisz adres permutacji L w pamieci.
    mov         rdi, Linv
    call        process_single_str                  ; Sprawdz L permutacje, policz odwrotnosc.

    add         rbp, 8
    mov         rsi, [rbp]
    mov         [Rperm], rsi                        ; Zapisz adres permutacji R.
    mov         rdi, Rinv
    call        process_single_str                  ; Sprawdz R permutacje, policz odwrotnosc.

    add         rbp, 8
    mov         rsi, [rbp]
    mov         [Tperm], rsi                        ; Zapisz adres permutacji T.
    xor         edi, edi                            ; Nie potrzebujemy odwrotnosci T.
    call        process_single_str                  ; Sprawdz T permutacje.

    xor         ecx, ecx
.check_T_permutation:                               ; Sprawdz czy T jest zlozeniem dwu-elementowych cykli.
    cmp         ecx, MAX_ARG_LENGTH
    je          .check_key

    xor         eax, eax
    mov         al, byte[rsi + rcx]                 ; Na rax wczytaj kolejna litere.

    cmp         al, byte[rsi + rax - MIN_CHAR]      ; Sprawdz czy nie ma punktu stalego.
    je          fail                           

    mov         edx, ecx
    add         edx, MIN_CHAR
    cmp         dl, byte[rsi + rax - MIN_CHAR]      ; Sprawdz czy cykl jest dlugosci dwa.
    jne         fail

    add         ecx, 1
    jmp         .check_T_permutation
.check_key:                                         ; Sprawdz klucz szyfrowania.
    add         rbp, 8
    mov         rsi, [rbp]
    xor         edi, edi
    mov         r8d, 2                              ; Ostatni argument ma dwie litery.
    call        process_single_str

    movzx       r10d, byte[rsi]                     ; Zapisz stan poczatkowy bebenka L.
    sub         r10d, MIN_CHAR

    add         rsi, 1
    movzx       r12d, byte[rsi]                     ; Zapisz stan poczatkowy bebenka R.
    sub         r12d, MIN_CHAR
.read_input:
    xor         eax, eax
    xor         edi, edi
    mov         rsi, buff
    mov         edx, BUFF_SIZE
    syscall                                         ; SYS_READ

    xor         edi, edi
    test        eax, eax                            ; Jesli blok pusty to zakoncz program.
    jz          exit

    mov         r11d, eax
    mov         rsi, buff
    mov         byte[buff + r11], 0
    mov         edi, 0
    mov         r8d, r11d
    call        process_single_str                  ; Sprawdz czy litery na wejsciu sa poprawne.

    xor         ecx, ecx
.encode_buffer:
    apply_rot

    lea         r15, [buff + rcx]                   ; Wczytaj litere do zaszyfrowania.

    movzx       esi, byte[r15]

    mov         rdi, [Rperm]
    mov         edx, r12d
    call add_perm_sub

    mov         rdi, [Lperm]
    mov         edx, r10d
    call add_perm_sub

    mov         rdi, [Tperm]
    xor         edx, edx 
    call add_perm_sub

    mov         rdi, Linv
    mov         edx, r10d
    call add_perm_sub

    mov         rdi, Rinv
    mov         edx, r12d
    call add_perm_sub

    mov         byte[r15], sil

    add         ecx, 1
    cmp         ecx, r11d
    jl          .encode_buffer
.print_output:
    mov         eax, SYS_WRITE
    mov         edi, STD_OUT
    mov         rsi, buff
    mov         edx, r11d
    syscall                                         ; SYS_WRITE

    cmp         edx, BUFF_SIZE
    jge         .read_input
    xor         edi, edi                            ; Kod wyjscia 0.
    jmp         exit
fail:
    mov         edi, 1                              ; Kod wyjscia 1.
exit:
    mov         eax, SYS_EXIT
    syscall