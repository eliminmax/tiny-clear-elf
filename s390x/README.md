# s390x tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0202 0100 0000 0000 0000 0000  .ELF............
00000010: 0002 0016 0000 0001 0000 0000 0001 0078  ...............x
00000020: 0000 0000 0000 0040 0000 0000 0000 0000  .......@........
00000030: 0000 0000 0040 0038 0001 0000 0000 0000  .....@.8........
00000040: 0000 0001 0000 0005 0000 0000 0000 0000  ................
00000050: 0000 0000 0001 0000 0000 0000 0000 0000  ................
00000060: 0000 0000 0000 0098 0000 0000 0000 0098  ................
00000070: 0000 0000 0000 0002 a729 0001 c031 0001  .........)...1..
00000080: 008e a749 000a 0a04 a729 0000 0a01 1b5b  ...I.....).....[
00000090: 481b 5b4a 1b5b 334a                      H.[J.[3J
```

## Breakdown

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 64-bit ELF file, the ELF header is 64 bytes, and one entry in the Program Header table is 56 bytes long. The string to print is 10 bytes long.

```asm
# ELF ehdr
  # e_ident
    # EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    .ascii "\x7f""ELF"
    # EI_CLASS: 2 is ELFCLASS64 - meaning it's a 64-bit object
    .byte 0x2
    # EI_DATA: 2 is ELFDATA2MSB - meaning that values are big-endian encoded
    .byte 0x2
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
    # EM_S390
    .2byte 0x16
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
    .8byte 0x98
    # p_memsz - size (in bytes) of memory to load the segment into
    .8byte 0x98
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .8byte 0x2

# The actual code
  # first syscall: write(1, 0x1008e, 10)
    # STDOUT is file descriptor #1
    lghi %r2, 0x1
    # the memory address of the data to write is 0x1008e
    lgfi %r3, 0x1008e
    # the number of bytes to write is 10
    lghi %r4, 0xa
    # instead of writing the syscall number (NR) to r1 then calling svc 0, one can simply call svc NR if it's less than 255.
    # write is syscall 4
    svc 4
  # Second syscall: exit(0)
    # error code 0 - no error
    lghi %r2, 0
    # exit is syscall 1
    svc 1

# The escape sequences
  .ascii "\x1b""[H""\x1b""[J""\x1b""[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 64-bit PowerPC little-endian version of the GNU assembler (`gas`, or just `as`) and linker (`ld`), as well as `objcopy`. All of these are part of GNU binutils. The problem is that it adds its own ELF header and program and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-powerpc64le-linux-gnu` package.

On `s390x` systems, one should instead use the `binutils` package, as the `binutils-s390x-linux-gnu` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

```sh
# On non-s390x Debian systems with binutils-s390x-linux-gnu installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On s390x Debian systems, it's probably harmless.
PATH="/usr/s390x-linux-gnu/bin:$PATH"

# assemble
as -o clear.o clear.S

# extract
objcopy --only-section .text -O binary clear.o clear.unwrapped

# link
ld -o clear.wrapped clear.o

# extracted binary will have 2 trailing bytes to discard
head -c-2 clear.unwrapped > clear

# mark clear as executable
chmod +x clear
```
