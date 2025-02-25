# mipsel tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0101 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 0800 0100 0000 5400 0200 3400 0000  ........T...4...
00000020: 0000 0000 0010 0070 3400 2000 0100 0000  .......p4. .....
00000030: 0000 0000 0100 0000 0000 0000 0000 0200  ................
00000040: 0000 0000 7e00 0000 7e00 0000 0500 0000  ....~...~.......
00000050: 0200 0000 a40f 0224 0100 0424 0200 053c  .......$...$...<
00000060: 7800 a534 0600 0624 0c00 0000 a10f 0224  x..4...$.......$
00000070: 0000 0424 0c00 0000 1b63 1b5b 334a       ...$.....c.[3J
```

## Breakdown

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 32-bit ELF file, the ELF header is 52 bytes, and one entry in the Program Header table is 32 bytes long. The string to print is 6 bytes long.

### Disassembly

```asm
.section .text
# ELF ehdr
  # e_ident
    # EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    .ascii "\177ELF"
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
    # EM_MIPS
    .2byte 0x8
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
    # processor-specific flags.
    # 0x7------- = mips32r2
    # 0x----1--- = o32 ABI
    .4byte 0x70001000
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
    .4byte 0x7e
    # p_memsz - size (in bytes) of memory to load the segment into
    .4byte 0x7e
    # p_flags - segment permissions - PF_X + PF_R (0x1 + 0x100) - readable and executable
    .4byte 0x5
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .4byte 0x2

# The actual code
  # first syscall: write(1, 0x20078, 6)
    # On mips/o32, write is syscall 4004 (0xfa4 in hex)
    # add 0xfa4 to the contents of the $zero register, store the result in $v0
    addiu $v0, $zero, 0xfa4
    # STDOUT is always file descriptor 1
    addiu $a0, $zero, 0x1
    # Because each instruction is exactly 32 bits long,
    # there's not enough room to set all 32 bits with 1 instruction, so to set the register,
    # we need to split it into two steps.
      # load 0x2 into the upper 16 bits of $a1 - this zeroes out the lower 16 bits.
      lui $a1, 0x2
      # bitwise OR $a1 against 0x78, save the result to $a1, to set the lower bits properly.
      ori $a1, $a1, 0x78
    # Write 6 bytes of data
    addiu $a2, $zero, 0x6
    # system call time
    syscall
  # Second syscall: exit(0)
    # On mips/o32, exit is syscall 4001 (0xfa1 in hex)
    addiu $v0, $zero, 0xfa1
    # Exit code is zero
    addiu $a0, $zero, 0
    # system call time
    syscall

# The escape sequences
  .ascii "\33c\33[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 32-bit MIPS little-endian version of the GNU assembler (`gas`, or just `as`) and linker (`ld`), as well as `objcopy`. All of these are part of GNU binutils. The problem is that it adds its own ELF header and program and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-mipsel-linux-gnu` package.

On `mipsel` systems, one should instead use the `binutils` package, as the `binutils-mipsel-linux-gnu` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

*I found it particularly hard to get the mipsel version of binutils to cooperate - not only did it add its own header too, but it padded it out in a completely different way than it did on other architectures. I changed the assembly, attempted to create a custom linker script, and when that failed, wound up coming up with an even hackier solution than other architectures.*

```sh
# On non-mipsel Debian systems with binutils-mipsel-linux-gnu installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On mipsel Debian systems, it's probably harmless.
PATH="/usr/mipsel-linux-gnu/bin:$PATH"

# assemble
as -EL -mabi=32 -march=mips32r2 -o clear.o clear.S -no-pad-sections
# -EL ensures it's a little-endian binary
# -march=mips32r2 instructs it to target the minimum version supported by Debian Bookworm
# -mabi=32 instructs it to use the O32 Application Binary Interface

# extract
objcopy -O binary clear.o clear
```
