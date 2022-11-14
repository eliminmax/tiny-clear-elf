# amd64 tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 3e00 0100 0000 7800 0100 0000 0000  ..>.....x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0000 0000 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0000 0000 0000  ................
00000060: a400 0000 0000 0000 a400 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 b801 0000 00bf 0100  ................
00000080: 0000 be9a 0001 00ba 0a00 0000 0f05 b83c  ...............<
00000090: 0000 00bf 0000 0000 0f05 1b5b 481b 5b4a  ...........[H.[J
000000a0: 1b5b 334a                                .[3J
```

## ASM

I created the following NASM source that should assemble into a byte-for-byte copy of the AMD64 `clear` executable

```asm
BITS 64
; ELF HEADER
; the meanings of the values of each object in the header are from elf.h
  ; e_ident
    db 0x7F,"ELF" ; EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    db 2          ; EI_CLASS: 2 is ELFCLASS64 - meaning it's a 64-bit object
    db 1          ; EI_DATA: 1 is ELFDATA2LSB - meaning that it's little-endian
    db 1          ; EI_VERSION: 1 is EV_CURRENT - it is the only valid value
    db 0          ; EI_OSABI: 0 is ELFOSABI_NONE - the generic SYSV ABI
    db 0          ; EI_ABIVERSION: used to differentiate between incompatible ABI Versions; unused here
    times 7 db 0  ; the remaining 7 bytes of the e_ident char array are unused and should be zeroed out
  ; e_type
    dw 2          ; ET_EXEC - Executable file
  ; e_machine
    dw 62         ; EM_X86_64 -  AMD
  ; e_version     ;
    dd 1          ; value can only be EV_CURRENT (1)
  ; e_entry
    dq 0x10078    ; the virtual memory address to transfer control at
                  ; because the beginning of the file is loaded to address 0x10000, and the actual instructions
                  ; begin 0x78 (120) bytes into the file, this is the value to set it to
  ; e_phoff
    dq 64         ; the offset (in bytes) from the start of the file to the program header table
                  ; because the program header table starts immediately after the elf header ends, this is set to
                  ; 64, as that's the size of a 64-bit ELF header
  ; e_shoff
    dq 0          ; the offset (in bytes) from the start of the file to the section header table
                  ; because there is no section header table, this is set to 0.
  ; e_flags
    dd 0          ; processor-specific flags, none are currently defined
  ; e_ehsize
    dw 64         ; the size of the ELF header, in bytes - 64 for 64-bit ELF files.
  ; e_phentsize
    dw 56         ; the size of an entry in the program header table, in bytes
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
  ; p_flags
    dd 5          ; segment permissions - PF_X + PF_R (0x1 + 0x100) - readable and executable
  ; p_offset
    dq 0          ; offset (in bytes) of start of segment in file
  ; p_vaddr
    dq 0x10000    ; load this segment into memory at the address 0x10000
  ; p_paddr
    dq 0          ; load this segment from physical address 0 in file
  ; p_filesz
    dq 164        ; size (in bytes) of the segment in the file
  ; p_memsz
    dq 164        ; size (in bytes) of memory to load the segment into
  ; p_align
    dq 2          ; segment alignment - segment addresses must be aligned to multiples of this value

; THE ACTUAL CODE
  ; setting EAX, EDI, and other 32-bit registers automatically zeroes out the higher 4 bytes to 0,
  ; so it's more efficient to set EAX than RAX, if the value fits
  mov eax,1       ; b8 01 00 00 00 - set the EAX register to 1
  mov edi,1       ; bf 01 00 00 00 - set the EDI register to 1
  mov esi,0x1009a ; be 9a 00 01 00 - set the ESI register to 0x1009a
  mov edx,10      ; ba 0a 00 00 00 - set the EDX register to 10
  syscall         ; 0f 05 - syscall
                    ; read the system call number from RAX - 1 is write
                    ; load the file descriptor to write to from RDI - 1 is stdout
                    ; load the bytes to write from the memory address in RSI - 0x1009a is 0x9a (154) bytes in
                    ; load the number of bytes to write from RDX
  mov eax,60      ; b8 3c 00 00 00 - set the EAX register to 60
  mov edi,0       ; bf 00 00 00 00 - set the EDI register to 0
  syscall         ; 0f 05 - syscall
                    ; read the system call number from RAX - 60 is exit
                    ; load the error code from RDI - 0 means no error
; THE DATA
db 0x1b,"[H",0x1b,"[J",0x1b,"[3J" ; this data is written to stdout by the first syscall.
                                  ; it consists of 3 escape sequences:
                                    ; \e[H moves the cursor to the first cell of the first row in the terminal.
                                    ; \e[J clears everything from the cursor to the end of the screen
                                    ; \e[3J clears the scrollback buffer
```
