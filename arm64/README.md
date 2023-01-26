# arm64 tiny_clear_elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 b700 0100 0000 7800 0100 0000 0000  ........x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0000 0000 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0000 0000 0000  ................
00000060: a600 0000 0000 0000 a600 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 0808 8052 2000 80d2  ...........R ...
00000080: 2100 a0d2 8113 80f2 4201 80d2 0100 00d4  !.......B.......
00000090: a80b 8052 0000 80d2 0100 00d4 1b5b 481b  ...R.........[H.
000000a0: 5b4a 1b5b 334a                           [J.[3J
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
    # The virtual memory to transfer control at. The file is loaded into memory address 0x010000, and the code starts 0x78 bytes into the file
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
    .8byte 0xa6
    # p_memsz - size (in bytes) of memory to load the segment into
    .8byte 0xa6
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .8byte 0x2

# The actual code

mov w8, 0x40
mov x0, 0x1
mov x1, 0x10000
movk x1, 0x9c
mov x2, 0xa
svc 0x0
mov w8, 0x5d
mov x0, 0x0
svc 0x0

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
