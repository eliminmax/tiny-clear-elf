# mips64el tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 0800 0100 0000 7800 0100 0000 0000  ........x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0000 0080 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0000 0000 0000  ................
00000060: a200 0000 0000 0000 a200 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 8913 0224 0100 0424  ...........$...$
00000080: 0100 053c 9c00 a534 0600 0624 0c00 0000  ...<...4...$....
00000090: c213 0224 0000 0424 0c00 0000 1b63 1b5b  ...$...$.....c.[
000000a0: 334a                                     3J
```

## Breakdown

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 64-bit ELF file, the ELF header is 64 bytes, and one entry in the Program Header table is 56 bytes long. The string to print is 6 bytes long.

### Disassembly

```asm
# mark as section .text for easier extraction
.section .text
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
    # EM_MIPS
    .2byte 0x8
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
    # processor-specific flags.
    # 0x8------- = mips64r2
    .4byte 0x80000000
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
  # first syscall: write(1, 0x1009c, 6)
    # On mips/n64, write is syscall 5001 (0x1389 in hex)
    # add 0xfa4 to the contents of the $zero register, store the result in $v0
    addiu $v0, $zero, 0x1389
    # STDOUT is always file descriptor 1
    addiu $a0, $zero, 0x1
    # Because each instruction is exactly 32 bits long,
    # there's not enough room to set all 32 bits with 1 instruction, so to set the register,
    # we need to split it into two steps.
      # load 0x1 into the upper 16 bits of $a1 - this zeroes out the lower 16 bits.
      lui $a1, 0x1
      # bitwise OR $a1 against 0x9c, save the result to $a1, to set the lower bits properly.
      ori $a1, $a1, 0x9c
    # Write 6 bytes of data
    addiu $a2, $zero, 0x6
    # system call time
    syscall
  # Second syscall: exit(0)
    # On mips/n64, exit is syscall 5058 (0x13c2 in hex)
    addiu $v0, $zero, 0x13c2
    # Exit code is zero
    addiu $a0, $zero, 0
    # system call time
    syscall

# The escape sequences
  .ascii "\33c\33[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 64-bit MIPS little-endian version of the GNU assembler (`gas`, or just `as`) and linker (`ld`), as well as `objcopy`. All of these are part of GNU binutils. The problem is that it adds its own ELF header and program and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-mips64el-linux-gnuabi64` package.

On `mips64el` systems, one should instead use the `binutils` package, as the `binutils-mips64el-linux-gnuabi64` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

```sh
# On non-mips64el Debian systems with binutils-mips64el-linux-gnuabi64 installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On mips64el Debian systems, it's probably harmless.
PATH="/usr/mips64el-linux-gnuabi64/bin:$PATH"

# assemble
as -EL -mabi=64 -march=mips64r2 -o clear.o clear.S -no-pad-sections
# -EL ensures it's a little-endian binary
# -march=mips64r2 instructs it to target the minimum version supported by Debian Bookworm
# -mabi=64 instructs it to use the N64 Application Binary Interface

# extract
objcopy --only-section .text -O binary clear.o clear
```
