# armhf tiny_clear_elf `clear`

## Hexdump of the executable

*made with xxd*

```xxd
00000000: 7f45 4c46 0101 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 2800 0100 0000 5500 0200 3400 0000  ..(.....U...4...
00000020: 0000 0000 0000 0000 3400 2000 0100 0000  ........4. .....
00000030: 0000 0000 0100 0000 0000 0000 0000 0200  ................
00000040: 0000 0000 7200 0000 7200 0000 0500 0000  ....r...r.......
00000050: 0200 0000 0427 0120 6821 c0f2 0201 0a22  .....'. h!....."
00000060: 00df 0127 0020 00df 1b5b 481b 5b4a 1b5b  ...'. ...[H.[J.[
00000070: 334a                                     3J
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
    # EM_ARM
    .2byte 0x28
  # e_version
    # EV_CURRENT - the only valid value
    .4byte 0x1
  # e_entry
    # The virtual memory to transfer control at. The file is loaded into memory address 0x20000, and the code starts 0x54 bytes into the file. Adding 1 starts it in thumb mode.
    .4byte 0x20055
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
    .4byte 0x72
    # p_memsz - size (in bytes) of memory to load the segment into
    .4byte 0x72
    # p_flags - segment permissions - PF_X + PF_R (0x1 + 0x100) - readable and executable
    .4byte 0x5
    # p_align - segment alignment - segment addresses must be aligned to multiples of this value
    .4byte 0x2

# The actual code
  # first syscall: write(1, 0x20078, 10)
    # On 32-bit arm systems, write is syscall 4.
    mov r7, #0x4
    # STDOUT is file descriptor #1
    mov r0, #0x1
    # Because each instruction is exactly 32 bits long,
    # there's not enough room to set all 32 bits with 1
    # `mov` command, but `mov` zeros out the bits not explicitly set.
    # The solution I'm using is to set the lower bits with `mov` and the upper with `movt`.
      # set the lower bits to 0x0068
      mov r1, #0x68
      # set the upper bits to 0x0002
      movt r1, #0x2
      # thus, the value of r1 is set to 0x20068 - the memory address of the data to print.
    # Write 10 bytes of data
    mov r2, #0xa
    # supervisor call 0 is equivalent to amd64's syscall and i386's int 0x80
    svc 0x0
  # Second syscall: exit(0)
    # on 32-bit arm systems, exit is syscall 1.
    mov r7, #0x1
    # error code 0 - no error
    mov r0, #0x0
    # supervisor call 0
    svc 0x0

# The escape sequences
  .ascii "\x1b""[H""\x1b""[J""\x1b""[3J"

# Padding
  .ascii "\xff""\xff"
```

#### Reassembly

To re-assemble the disassembly, you need to first assemble it with a 32-bit ARM version of the GNU assembler (`gas`, or just `as`) and linker (`ld`), as well as `objcopy`. All of these are part of GNU binutils. The problem is that it adds its own ELF header and program and section tables, so you then need to extract the actual file out from its output.

I used the versions from Debian Bookworm's `binutils-arm-linux-gnueabihf` package.

If you save the disassembly to `clear.S`, you'd need to do the following to reassemble it:

```sh
# assemble
as -mthumb -o clear.o clear.S
# link
ld -o clear.wrapped clear.o
# extract
objcopy -O binary clear.wrapped clear.unwrapped
# extracted binary will have 2 trailing bytes to discard
head -c-2 clear.unwrapped > clear
# mark clear as executable
chmod +x clear
```
