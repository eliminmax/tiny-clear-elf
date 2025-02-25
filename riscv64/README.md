# riscv64 tiny-clear-elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 f300 0100 0000 7800 0100 0000 0000  ........x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0500 0000 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0000 0000 0000  ................
00000060: 9a00 0000 0000 0000 9a00 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 9308 0004 0545 c165  .............E.e
00000080: 9385 4509 1946 7300 0000 9308 d005 0145  ..E..Fs........E
00000090: 7300 0000 1b63 1b5b 334a                 s....c.[3J
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
    # EM_RISCV
    .2byte 0xf3
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
    # processor-specific flags. There are two in use here.
      # EF_RISCV_FLOAT_ABI_DOUBLE (0x0004) indicates that it targets systems that use 64-bit floats (like the systems Debian targets)
      # EF_RISCV_RVC (0x0001) indicates that it uses the C extension for compressed instructions.
    .4byte 0x0005
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
    .8byte 0x9a
    # p_memsz - size (in bytes) of memory to load the segment into
    .8byte 0x9a
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .8byte 0x2

# The actual code
  # first syscall: write(1, 0x10094, 6)
    # On 64-bit riscv systems, write is syscall 64.
    # to set a register to an immediate value, use addi to add that immediate to the register x0
    # which is hard-wired to always contain a zero and save the result to the target regiser.
    addi a7, x0, 0x40
    # STDOUT is file descriptor #1
    addi a0, x0, 0x1
    # Because each instruction is exactly 32 bits long,
    # there's not enough room to set all 32 bits with 1 instruction, so the upper 20 bits
    # are loaded with `lui` then the lower 12 bits are added with addi. This can be condensed
    # into the `li` pseudo-instruction, but I am not doing that here.
      # set a1 to 0x100000
      lui a1, 0x10
      # set the lowest 12 bits to 0x94
      addi a1, a1, 0x94
      # thus, the value of a1 is set to 0x10094 - the memory address of the data to print.
    # Write 6 bytes of data
    addi a2, x0, 0x6
    # riscv's system call instruction is ecall (previously known as scall)
    ecall
  # Second syscall: exit(0)
    # on 64-bit riscv systems, exit is syscall 93.
    addi a7, x0, 0x5d
    # error code 0 - no error
    addi a0, x0, 0x0
    # ecall instruction
      ecall

# The escape sequences
  .ascii "\33c\33[3J"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 64-bit RISC-V version of the GNU assembler (`gas`, or just `as`) and linker (`ld`), as well as `objcopy`. All of these are part of GNU binutils. The problem is that it adds its own ELF header and program and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-riscv64-linux-gnu` package.

On `riscv64` systems, one should instead use the `binutils` package, as the `binutils-riscv64-linux-gnu` package is meant for working with foreign binaries.

If you save the disassembly to `clear.S`, you'll need to do the following to reassemble it:

```sh
# On non-riscv64 Debian systems with binutils-riscv64-linux-gnu installed, this will ensure
# the appropriate binutils versions are first in the PATH.
# On riscv64 Debian systems, it's probably harmless.
PATH="/usr/riscv64-linux-gnu/bin:$PATH"

# assemble
as -mabi=lp64d -march=rv64gc -mlittle-endian -o clear.o clear.S -no-pad-sections
# -mlittle-endian ensures it's a little-endian binary
# -march=rv64gc instructs it to target the minimum hardware version supported by Debian
# -mabi=lp64d instructs it to target the minimum ABI version supported by Debian

# link
ld -o clear.wrapped clear.o

# extract
objcopy -O binary clear.wrapped clear
```
