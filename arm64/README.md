# arm64 tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 b700 0100 0000 7800 0100 0000 0000  ........x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0000 0000 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0000 0000 0000  ................
00000060: 9e00 0000 0000 0000 9e00 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 0808 8052 2000 80d2  ...........R ...
00000080: c100 0010 c200 80d2 0100 00d4 a80b 8052  ...............R
00000090: 0000 80d2 0100 00d4 1b63 1b5b 334a       .........c.[3J
```

## Breakdown

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 64-bit ELF file, the ELF header is 64 bytes, and one entry in the Program Header table is 56 bytes long. The string to print is 6 bytes long.

### Disassembly

```asm
# ELF ehdr
  # e_ident
    # EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    .ascii "\177ELF"
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
    # EM_AARCH64
    .2byte 0xb7
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
    .8byte 0x9e
    # p_memsz - size (in bytes) of memory to load the segment into
    .8byte 0x9e
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .8byte 0x2

# The actual code
  # first syscall: write(1, 0x1009c, 6)
    # On 64-bit arm systems, write is syscall 64.
    mov w8, 0x40
    # STDOUT is file descriptor #1
    mov x0, 0x1
    # instead of taking 64 bytes to use a mov to set the lower
    # bytes followed by a movk to set the upper bytes, set them relative to the program counter
    adr x1, ESCAPE_SEQ
    # Write 6 bytes of data
    mov x2, 0x6
    # supervisor call 0 is equivalent to amd64's syscall and i386's int 0x80
    svc 0x0
  # Second syscall: exit(0)
    # on 64-bit arm systems, exit is syscall 93.
    mov w8, 0x5d
    # error code 0 - no error
    mov x0, 0x0
    # supervisor call 0
    svc 0x0

# I'd normally not use any labels in these, but the ADR encoding used requires a label
#   so that the assembler can calculate the offset the distance from the adr instruction to the label
#   I'd prefer to just input an immediate (i.e. adr x1, #0x18, but that's invalid syntax)
ESCAPE_SEQ:
# The escape sequences
  .ascii "\33c\33[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 64-bit ARM version of the GNU assembler (`gas`, or just `as`). The problem is that it adds its own ELF header, program, and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-aarch64-linux-gnu` package.

On `arm64` systems, one should instead use the `binutils` package, as the `binutils-aarch64-linux-gnu` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

```sh
# On non-arm64 Debian systems with binutils-aarch64-linux-gnu installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On arm64 Debian systems, it's harmless.
PATH="/usr/aarch64-linux-gnu/bin:$PATH"

# assemble
as -march=armv8-a -EL -o clear.o clear.S -no-pad-sections
# -march=armv8-a ensures that the instructions are valid on all Debian arm64 systems
# -EL ensures that it uses little-endian byte order

# link
ld -o clear.wrapped clear.o

# extract
objcopy -O binary clear.wrapped clear
```
