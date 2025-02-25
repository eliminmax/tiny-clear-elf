# ppc64el tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 1500 0100 0000 7800 0100 0000 0000  ........x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0200 0000 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0000 0000 0000  ................
00000060: a200 0000 0000 0000 a200 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 0400 0038 0100 6038  ...........8..`8
00000080: 9c00 8038 0100 843c 0600 a038 0200 0044  ...8...<...8...D
00000090: 0100 0038 0000 6038 0200 0044 1b63 1b5b  ...8..`8...D.c.[
000000a0: 334a                                     3J
```

## Breakdown

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 64-bit ELF file, the ELF header is 64 bytes, and one entry in the Program Header table is 56 bytes long. The string to print is 6 bytes long.

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
    # EM_PPC64
    .2byte 0x15
  # e_version
    # EV_CURRENT - the only valid value
    .4byte 0x1
  # e_entry
    # The virtual memory to transfer control at. The file is loaded into memory address 0x10000, and the code starts 0x78 bytes into the file
    .8byte 0x10078
  # e_phoff
    # the offset from the beginning of the file to the program header table
    .8byte 0x40
  # e_shoff
    # the offset from the beginning of the file to the section header table - zero, as there is no section header table
    .8byte 0x0
  # e_flags
    # processor-specific flags. Must be set to 2
    .4byte 0x2
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
    .8byte 0xa2
    # p_memsz - size (in bytes) of memory to load the segment into
    .8byte 0xa2
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .8byte 0x2

# The actual code
  # first syscall: write(1, 0x1008e, 6)
    # write is syscall #4
    li %r0, 0x4
    # STDOUT is file descriptor #1
    li %r3, 0x1
    # the memory address of the data to write is 0x1009c
    li %r4, 0x9c
    addis %r4, %r4, 0x1
    # the number of bytes to write is 6
    li %r5, 0x6
    # syscall instruction
    sc
  # Second syscall: exit(0)
    # exit is syscall #1
    li %r0, 1
    # error code 0 - no error
    li %r3, 0
    # syscall instruction
    sc
    

# The escape sequences
  .ascii "\33c\33[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 64-bit PowerPC little-endian version of the GNU assembler (`gas`, or just `as`) and linker (`ld`), as well as `objcopy`. All of these are part of GNU binutils. The problem is that it adds its own ELF header and program and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-powerpc64le-linux-gnu` package.

On `powerpc64le` systems, one should instead use the `binutils` package, as the `binutils-powerpc64le-linux-gnu` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

```sh
# On non-ppc64el Debian systems with binutils-powerpc64le-linux-gnu installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On ppc64el Debian systems, it's probably harmless.
PATH="/usr/powerpc64le-linux-gnu/bin:$PATH"

# assemble
as -le -mpower8 -o clear.o clear.S -no-pad-sections
# -le ensures it's a little-endian binary
# -mpower8 instructs it to target the minimum version supported by Debian Bookworm

# extract
objcopy -O binary clear.o clear
```
