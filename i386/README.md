# i386 tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0101 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 0300 0100 0000 5400 0200 3400 0000  ........T...4...
00000020: 0000 0000 0000 0000 3400 2000 0100 0000  ........4. .....
00000030: 0000 0000 0100 0000 0000 0000 0000 0200  ................
00000040: 0000 0000 7500 0000 7500 0000 0500 0000  ....u...u.......
00000050: 0200 0000 6a04 586a 015b b96b 0002 006a  ....j.Xj.[.k...j
00000060: 0a5a cd80 6a01 5831 dbcd 801b 5b48 1b5b  .Z..j.X1....[H.[
00000070: 4a1b 5b33 4a                             J.[3J
```

## Breakdown

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 32-bit ELF file, the ELF header is 32 bytes, and one entry in the Program Header table is 32 bytes long. The string to print is 10 bytes long.

### Disassembly

```asm
# ELF ehdr
  # e_ident
    # EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    .ascii "\x7f""ELF"
    # EI_CLASS: 1 is ELFCLASS32 - meaning it's a 32-bit object
    .byte 0x1
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
    # EM_386 - Intel 80386
    .2byte 0x3
  # e_version
    # EV_CURRENT - the only valid value
    .4byte 0x1
  # e_entry
    # The virtual memory to transfer control at. The file is loaded into memory address 0x20000, and the code starts 0x54 bytes into the file
    .4byte 0x20054
  # e_phoff
    # the offset from the beginning of the file to the program header table
    .4byte 0x34
  # e_shoff
    # the offset from the beginning of the file to the section header table - zero, as there is no section header table
    .4byte 0x0
  # e_flags
    # processor-specific flags. None are in use here.
    .4byte 0x0
  # e_ehsize
    # the size (in bytes) of the ELF header. for a 32-bit ELF, this will always be 52
    .2byte 0x34
  # e_phentsize
    # the size (in bytes) of an entry in the program header table.
    .2byte 0x20
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
    # p_offset - offset (in bytes) of start of segment in file
    .4byte 0x0
    # p_vaddr - load this segment into memory at the address 0x20000
    .4byte 0x020000
    # p_paddr - load this segment from physical address 0 in file
    .4byte 0x0
    # p_filesz - size (in bytes) of the segment in the file
    .4byte 0x75
    # p_memsz - size (in bytes) of memory to load the segment into
    .4byte 0x75
    # p_flags - segment permissions - PF_X + PF_R (0x1 + 0x100) - readable and executable
    .4byte 5
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .4byte 0x2

# The actual code
  # first syscall: write(1, 0x20073, 10)
    # On 32-bit x86 systems, write is syscall 4.
    # pushing and popping like this takes 3 bytes, where `mov` takes 5
    pushl $0x4
    pop %eax
    # STDOUT is file descriptor #1
    pushl $0x1
    pop %ebx
    # the memory address with the data to print is 0x2006b.
    movl $0x2006b, %ecx
    # Write 10 bytes of data
    pushl $0xa
    pop %edx
    # interupt 0x80 - the syscall instruction for i386
    int $0x80
  # Second syscall: exit(0)
    # on 32-bit x86 systems, exit is syscall 1.
    pushl $0x1
    pop %eax
    # set the EBX register to 0 by XOR'ing it to itself
    # error code 0 - no error
    xor %ebx, %ebx
    # interupt 0x80
    int $0x80

# The escape sequences
  .ascii "\x1b""[H""\x1b""[J""\x1b""[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 32-bit x86 version of the GNU assembler (`gas`, or just `as`). The problem is that it adds its own ELF header, program, and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-i686-linux-gnu` package.

On `i386` systems, one should instead use the `binutils` package, as the `binutils-i686-linux-gnu` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

```sh
# On non-i386 Debian systems with binutils-i686-linux-gnu installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On i386 Debian systems, it's harmless.
PATH="/usr/i686-linux-gnu/bin:$PATH"

# assemble
as -march=i686 -o clear.o clear.S -no-pad-sections
# -march=i686 ensures that the instructions are valid on all Debian i386 systems

# link
ld -o clear.wrapped clear.o

# extract
objcopy -O binary clear.wrapped clear
```
