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
00000060: 9400 0000 0000 0000 9400 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 6a01 5889 c7be 8e00  ........j.X.....
00000080: 0100 6a06 5a0f 056a 3c58 31ff 0f05 1b63  ..j.Z..j<X1....c
00000090: 1b5b 334a                                .[3J
```

## Breakdown

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 64-bit ELF file, the ELF header is 64 bytes, and one entry in the Program Header table is 56 bytes long. The string to print is 6 bytes long.

### Disassembly

```asm
# ELF ehdr
  # e_ident
    # EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    .ascii "\x7f""ELF"
    # EI_CLASS: 2 is ELFCLASS64 - meaning it's a 64-bit object
    .byte 0x2
    # EI_DATA: 1 is ELFDATA2LSB - meaning that values are little-endian encoded
    .byte 0x1
    # EI_VERSION: 1 is EV_CURRENT - the only valid value
    .byte 0x1
    # EI_OSABI: 0 is ELFOSABI_NONE - the generic SYSV ABI
    .byte 0x0
    # EI_ABIVERSION: used to distinguish between incompatible ABI versions. Unused for the SYSV ABI
    .byte 0x0
    # The remaining 7 bytes are unused, and should be set to 0
    .4byte 0x0
    .2byte 0x0
    .byte 0x0
  # e_type
    # ET_EXEC - executable file
    .2byte 0x2
  # e_machine
    # EM_X86_64
    .2byte 0x3e
  # e_version
    # EV_CURRENT - the only valid value
    .4byte 0x1
  # e_entry
    # The virtual memory address to transfer control at. The file is loaded into memory address 0x10000, and the code starts 0x78 bytes into the file
    .8byte 0x10078
  # e_phoff
    # the offset from the beginning of the file to the program header table
    .8byte 0x40
  # e_shoff
    # the offset from the beginning of the file to the section header table - zero, as there is no section header table
    .8byte 0x0
  # e_flags
    # processor-specific flags. None are in use here.
    .4byte 0x0
  # e_ehsize
    # the size (in bytes) of the ELF header. for a 64-bit ELF, this will always be 64
    .2byte 0x40
  # e_phentsize
    # the size (in bytes) of an entry in the program header table.
    .2byte 0x38
  # e_phnum
    # the number of entries in the program header table
    .2byte 0x1
  # e_shentsize
    # the size of an entry in the section header table, or 0 if there is no section header table
    .2byte 0x0
  # e_shnum
    # the number of entries in the section header table
    .2byte 0x0
  # e_shstrndx
    # the index of the section header table entry names - zero, as there is no section header table
    .2byte 0x0

# Program Header Table
  # Program header entry
    # p_type - PT_LOAD (1) - a loadable program segment
    .4byte 0x1
    # p_flags - segment permissions - PF_X + PF_R (0x1 + 0x100) - readable and executable
    .4byte 0x5
    # p_offset - offset (in bytes) of start of segment in file
    .8byte 0x0
    # p_vaddr - load this segment into memory at the address 0x10000
    .8byte 0x010000
    # p_paddr - load this segment from physical address 0 in file
    .8byte 0x0
    # p_filesz - size (in bytes) of the segment in the file
    .8byte 0x94
    # p_memsz - size (in bytes) of memory to load the segment into
    .8byte 0x94
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .8byte 0x2

# The actual code
  # first syscall: write(1, 0x10097, 6)
    # On 64-bit x86 systems, write is syscall 1.
    # pushing and popping like this takes 3 bytes, where `mov` takes 5
    pushq $0x1
    pop %rax
    # STDOUT is file descriptor #1
    # because rax is set to 1, by using the 32-bit version of the register to register mov to copy eax to edi,
    # it only needs 2 bytes
    mov %eax, %edi
    # the memory address with the data to print is 0x1008e.
    movl $0x1008e, %esi
    # Write 6 bytes of data
    pushq $0x6
    pop %rdx
    # syscall ask the kernel to perform the syscall specified in RAX, with arguments from RDI, RSI, RDX, and others
    syscall
  # Second syscall: exit(0)
    # on 64-bit x86 systems, exit is syscall 60.
    pushq $0x3c
    pop %rax
    # 31 ff - set the EDI register to 0 by XOR'ing it to itself
    # error code 0 - no error
    xor %edi, %edi
    # syscall again
    syscall

# The escape sequences
  .ascii "\x1b""c""\x1b""[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 64-bit x86 version of the GNU assembler (`gas`, or just `as`). The problem is that it adds its own ELF header, program, and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-x86-64-linux-gnu` package.

On `amd64` systems, one should instead use the `binutils` package, as the `binutils-x86-64-linux-gnu` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

```sh
# On non-amd64 Debian systems with binutils-x86-64-linux-gnu installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On amd64 Debian systems, it's harmless.
PATH="/usr/x86-linux-gnu/bin:$PATH"

# assemble
as -march=generic64 -o clear.o clear.S -no-pad-sections
# -march=generic64 ensures that the instructions are valid on all Debian amd64 systems

# link
ld -o clear.wrapped clear.o

# extract
objcopy -O binary clear.wrapped clear
```
