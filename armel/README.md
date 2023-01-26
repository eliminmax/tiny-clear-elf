# armel/armhf tiny_clear_elf `clear`

**Note about architecture:** `armhf` and `armel` are not technically separate architectures, but `armhf` executables are compiled for use with **h**ardware **f**loating-point support, which not all 32-bit arm hardware has. I am copying Debian's approach to ARM, and treating them as separate architectures, but because I am not doing any floating-point calculations in this simple executable, there's no real difference between them.

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0101 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 2800 0100 0000 5400 0200 3400 0000  ..(.....T...4...
00000020: 0000 0000 0000 0000 3400 2000 0100 0000  ........4. .....
00000030: 0000 0000 0100 0000 0000 0000 0000 0200  ................
00000040: 0000 0200 8200 0000 8200 0000 0500 0000  ................
00000050: 0200 0000 0470 a0e3 0100 a0e3 7810 00e3  .....p......x...
00000060: 0210 40e3 0a20 a0e3 0000 00ef 0170 a0e3  ..@.. .......p..
00000070: 0000 a0e3 0000 00ef 1b5b 481b 5b4a 1b5b  .........[H.[J.[
00000080: 334a                                     3J
```

## Breakdown

Unfortunately, NASM is only usable for the x86 architecture family, so I can't provide NASM source.

The file has 4 parts to it - the ELF header, the Program Header table, the code, and the data.

Given that this is a 32-bit ELF file, the ELF header is 52 bytes, and one entry in the Program Header table is 32 bytes long. The string to print is 10 bytes long.

### Disassembly

```asm
# ELF ehdr
  # e_ident
    # EI_MAG0, EI_MAG1, EI_MAG2, EI_MAG3: ELFMAG0, ELFMAG1, ELFMAG2, ELFMAG3 - the ELF magic number
    .ascii "\x7f""ELF"
    # EI_CLASS: 1 is ELFCLASS32 - meaning it's a 32-bit object
    .byte 1
    # EI_DATA: 1 is ELFDATA2LSB - meaning that values are little-endian encoded
    .byte 1
    # EI_VERSION: 1 is EV_CURRENT - the only valid value
    .byte 1
    # EI_OSABI: 0 is ELFOSABI_NONE - the generic SYSV ABI
    .byte 0
    # EI_ABIVERSION: used to distinguish between incompatible ABI versions. Unused for the SYSV ABI
    .byte 0
    # The remaining 7 bytes are unused, and should be set to 0
    .4byte 0
    .2byte 0
    .byte 0
  # e_type
    # ET_EXEC - executable file
    .2byte 2
  # e_machine
    # EM_ARM
    .2byte 40
  # e_version
    # EV_CURRENT - the only valid value
    .4byte 1
  # e_entry
    # The virtual memory to transfer control at. The file is loaded into memory address 0x020000, and the code starts 0x54 bytes into the file
    .4byte 0x00020054
  # e_phoff
    # the offset from the beginning of the file to the program header table
    .4byte 52
  # e_shoff
    # the offset from the beginning of the file to the section header table - zero, as there is no section header table
    .4byte 0
  # e_flags
    # processor-specific flags. None are in use here.
    .4byte 0
  # e_ehsize
    # the size (in bytes) of the ELF header. for a 32-bit ELF, this will always be 52
    .2byte 52
  # e_phentsize
    # the size (in bytes) of an entry in the program header table.
    .2byte 32
  # e_phnum
    # the number of entries in the program header table
    .2byte 1
  # e_shentsize
    # the size of an entry in the section header table, or 0 if there is no section header table
    .2byte 0
  # e_shnum
    # the number of entries in the section header table
    .2byte 0
  # e_shstrndx
    # the index of the section header table entry names - zero, as there is no section header table
    .2byte 0
# Program Header Table
  # Program header entry
    # p_type - PT_LOAD (1) - a loadable program segment
    .4byte 1
    # p_offset - offset (in bytes) of start of segment in file
    .4byte 0
    # p_vaddr - load this segment into memory at the address 0x20000
    .4byte 0x020000
    # p_paddr - load this segment from physical address 0 in file
    .4byte 0
    # p_filesz - size (in bytes) of the segment in the file
    .4byte 0x82
    # p_memsz - size (in bytes) of memory to load the segment into
    .4byte 0x82
    # p_flags - segment permissions - PF_X + PF_R (0x1 + 0x100) - readable and executable
    .4byte 5
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .4byte 2

# The actual code

mov r7, #4
mov r0, #1
movw r1, #0x78
movt r1, #2
mov r2, #0xa
svc 0
mov r7, #1
mov r0, #0
svc 0

# The escape sequences
.ascii "\x1b""[H""\x1b""[J""\x1b""[3J"

# It's going to include 2 extra bytes, might as well ensure that they have easily-identified values
.ascii "\xff""\xff"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 32-bit ARM version of the GNU assembler (`gas`, or just `as`). The problem is that it adds its own ELF header and program and section tables, so you then need to extract the actual file out from its output.

If you save the disassembly to `clear.S`, you'd need to do the following to reassemble it:


```sh
# assemble
as -o clear.o clear.S
# link
ld -o clear.wrapped clear.o
# extract
objcopy -O binary clear.wrapped clear.unwrapped
# extracted binary will have 2 trailing bytes to discard
head -c-2 clear.unwrapped > clear
# mark clear as executable
chmod +x clear
```