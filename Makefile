all:
	nasm -f elf64 -w+all -w+error -o dcl.o -g dcl.asm
	ld --fatal-warnings -o dcl dcl.o
