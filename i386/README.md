# i386 tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0101 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 0300 0100 0000 5400 0200 3400 0000  ........T...4...
00000020: 0000 0000 0000 0000 3400 2000 0100 0000  ........4. .....
00000030: 0000 0000 0100 0000 0000 0000 0000 0200  ................
00000040: 0000 0000 8000 0000 8000 0000 0500 0000  ................
00000050: 0200 0000 b804 0000 00bb 0100 0000 b976  ...............v
00000060: 0002 00ba 0a00 0000 cd80 b801 0000 00bf  ................
00000070: 0000 0000 cd80 1b5b 481b 5b4a 1b5b 334a  .......[H.[J.[3J
```

## ASM

I created the following NASM source that should assemble into a byte-for-byte copy of the AMD64 `clear` executable

```asm
BITS 32
; ELF HEADER
; the meanings of the values of each object in the header are from elf.h
  ; e_ident
    db 0x7F,"ELF" ; EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    db 1          ; EI_CLASS: 1 is ELFCLASS32 - meaning it's a 32-bit object
    db 1          ; EI_DATA: 1 is ELFDATA2LSB - meaning that it's little-endian
    db 1          ; EI_VERSION: 1 is EV_CURRENT - it is the only valid value
    db 0          ; EI_OSABI: 0 is ELFOSABI_NONE - the generic SYSV ABI
    db 0          ; EI_ABIVERSION: used to differentiate between incompatible ABI Versions; unused here
    times 7 db 0  ; the remaining 7 bytes of the e_ident char array are unused and should be zeroed out
  ; e_type
    dw 2          ; ET_EXEC - Executable file
  ; e_machine
    dw 3          ; EM_386 - Intel 80386
  ; e_version     ;
    dd 1          ; value can only be EV_CURRENT (1)
  ; e_entry
    dd 0x20054    ; the virtual memory address to transfer control at
                  ; because the beginning of the file is loaded to address 0x20000, and the actual instructions
                  ; begin 0x54 (84) bytes into the file, this is the value to set it to
  ; e_phoff
    dd 52         ; the offset (in bytes) from the start of the file to the program header table
                  ; because the program header table starts immediately after the elf header ends, this is set to
                  ; 52, as that's the size of a 32-bit ELF header
  ; e_shoff
    dd 0          ; the offset (in bytes) from the start of the file to the section header table
                  ; because there is no section header table, this is set to 0.
  ; e_flags
    dd 0          ; processor-specific flags, none are currently defined
  ; e_ehsize
    dw 52         ; the size of the ELF header, in bytes - 52 for 32-bit ELF files.
  ; e_phentsize
    dw 32         ; the size of an entry in the program header table, in bytes
  ; e_phnum
    dw 1          ; the number of entries in the program header table
  ; e_shentsize
    dw 0          ; the size of entries in the section header table - zero, as there is no section header table
  ; e_shnum
    dw 0          ; the number of entries in the section header table
  ; e_shstrndx
    dw 0          ; the index of the section header table entry names - zero, as there is no section header table
; PROGRAM HEADER TABLE
  ; p_type
    dd 1          ; PT_LOAD (1) - a loadable program segment
  ; p_offset
    dd 0          ; offset (in bytes) of start of segment in file
  ; p_vaddr
    dd 0x20000    ; load this segment into memory at the address 0x20000
  ; p_paddr
    dd 0          ; load this segment from physical address 0 in file
  ; p_filesz
    dd 128        ; size (in bytes) of the segment in the file
  ; p_memsz
    dd 128        ; size (in bytes) of memory to load the segment into
  ; p_flags
    dd 5          ; segment permissions - PF_X + PF_R (0x1 + 0x100) - readable and executable
  ; p_align
    dd 2          ; segment alignment - segment addresses must be aligned to multiples of this value

; THE ACTUAL CODE
  mov eax,4       ; b8 04 00 00 00 - set the EAX register to 4
  mov ebx,1       ; bb 01 00 00 00 - set the EBX register to 1
  mov ecx,0x20076 ; b9 76 00 02 00 - set the ECX register to 0x20076
  mov edx,10      ; ba 0a 00 00 00 - set the EDX register to 10
  int 0x80        ; cd 80 - syscall
                    ; read the system call number from EAX - 4 is write
                    ; load the file descriptor to write to from EBX - 1 is stdout
                    ; load the bytes to write from the memory address in ECX - 0x20076 is 0x76 (118) bytes in
                    ; load the number of bytes to write from EDX
  mov eax,0x1     ; b8 01 00 00 00 - set the EAX register to 1
  mov ebx,0x0     ; bf 00 00 00 00 - set the EBX register to 0
  int 0x80        ; cd 80  - syscall
                    ; read the system call number from EAX - 1 is exit
                    ; load the error code from EBX - 0 means no error

; THE DATA
db 0x1b,"[H",0x1b,"[J",0x1b,"[3J" ; this data is written to stdout by the first syscall.
                                  ; it consists of 3 escape sequences:
                                    ; \e[H moves the cursor to the first cell of the first row in the terminal.
                                    ; \e[J clears everything from the cursor to the end of the screen
                                    ; \e[3J clears the scrollback buffer
```
