# ELF format

This section was made with reference to `elf.h` from the GNU C Library, and `ELF(5)` from the Linux man-pages project.

## ELF Header

The ELF header is a struct containing the following data:

data          | bytes  | type                | description
--------------|--------|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
`e_ident`     | 16     | char array          | info about the ELF file
`e_type`      | 2      | unsigned 16-bit int | type of ELF file: `ET_NONE` (0) for unknown, `ET_REL` (1) for relocatable, `ET_EXEC` (2) for an executable, `ET_DYN` (3) for a shared object, or `ET_CORE` (4) for a core file
`e_machine`   | 2      | unsigned 16-bit int | target CPU architecture
`e_version`   | 4      | unsigned 32-bit int | file version: `EV_NONE` (0) for invalid version, `EV_CURRENT` (1) for current version
`e_entry`     | 4 or 8 | ElfN_Addr*          | virtual address to transfer control at (0 if file has no entry point)
`e_phoff`     | 4 or 8 | ElfN_Off*           | file offset for program header table in bytes (0 if file has no program header table)
`e_shoff`     | 4 or 8 | ElfN_Off*           | file offset for section header table in bytes (0 if file has no section header table)
`e_flags`     | 4      | unsigned 32-bit int | processor-specific flags, currently none are defined
`e_ehsize`    | 2      | unsigned 16-bit int | size of the elf header in bytes
`e_phentsize` | 2      | unsigned 16-bit int | size of an entry in the program header table in bytes
`e_phnum`     | 2      | unsigned 16-bit int | number of entries in the program header table
`e_shentsize` | 2      | unsigned 16-bit int | size of an entry in the section header table in bytes
`e_shnum`     | 2      | unsigned 16-bit int | number of entries in the section header table
`e_shstrndx`  | 2      | unsigned 16-bit int | index of section header table entry names, or `0xffff` if it would be larger than `0xff00`. If no section header name string table exists, it is set to `SHN_UNDEF` (0)

\* the size of this field is different on 32-bit and 64-bit systems, and just so happens to match up perfectly - 32-bit on 32-bit systems, 64-bit on 64-bit systems.

### `e_ident` byte-by-byte

byte index | field name      | description
-----------|-----------------|-------------
`0`        | `EI_MAG0`       | 1st byte of the ELF magic number - its value must be set to `0x7f` (non-printable)
`1`        | `EI_MAG1`       | 2nd byte of the ELF magic number - its value must be set to `0x45` ('`E`')
`2`        | `EI_MAG2`       | 3rd byte of the ELF magic number - its value must be set to `0x4c` ('`L`')
`3`        | `EI_MAG3`       | 4th byte of the ELF magic number - its value must be set to `0x46` ('`F`')
`4`        | `EI_CLASS`      | this ELF file - `ELFCLASSNONE` (0) is invalid, `ELFCLASS32` (1) is 32-bit, and `ELFCLASS64` (2) is 64-bit
`5`        | `EI_DATA`       | data encoding - `ELFDATANONE` (0) is invalid, `ELFDATA2LSB` (1) is little-endian, `ELFDATA2MSB` (2) is big-endian
`6`        | `EI_VERSION`    | ELF version - must be set to `EV_CURRENT` (1)
`7`        | `EI_OSABI`      | ABI to target, `ELFOSABI_NONE` (0) is almost always the right choice. See manpage `ELF(5)` for other values
`8`        | `EI_ABIVERSION` | Which ABI version to target, in case the targeted ABI has incompatible versions. Interpretation is dependent on value of `EI_OSABI`
`9`        | `+-+-+-+-+-+-+` | Currently unused, should be set to `0x00`
`a`        | `+-+-+-+-+-+-+` | Currently unused, should be set to `0x00`
`b`        | `+-+-+-+-+-+-+` | Currently unused, should be set to `0x00`
`c`        | `+-+-+-+-+-+-+` | Currently unused, should be set to `0x00`
`d`        | `+-+-+-+-+-+-+` | Currently unused, should be set to `0x00`
`e`        | `+-+-+-+-+-+-+` | Currently unused, should be set to `0x00`
`f`        | `+-+-+-+-+-+-+` | Currently unused, should be set to `0x00`

### Real-world example
This was taken from the beginning of the Busybox v1.30.1, packaged as Busybox v1.30.1 (Debian 1:1.30.1-6+b3) for Debian 11 (bullseye)
```
┌────────┬─────────────────────────┬─────────────────────────┐
│00000000│ 7f 45 4c 46 02 01 01 00 ┊ 00 00 00 00 00 00 00 00 │
│00000010│ 03 00 3e 00 01 00 00 00 ┊ 90 d6 00 00 00 00 00 00 │
│00000020│ 40 00 00 00 00 00 00 00 ┊ d8 e3 0a 00 00 00 00 00 │
│00000030│ 00 00 00 00 40 00 38 00 ┊ 0b 00 40 00 1c 00 1b 00 │
└────────┴─────────────────────────┴─────────────────────────┘
```

Let's split that up, section by section:

#### `e_ident`:
```
┌─────────┬─────────────────────────────────────────────────┐
│ 00 - 0f │ 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────────────────────────────┘
```
* The first 4 bytes (`0x7f454c46`) are the magic number
* The next byte (`0x02`) indicates that this is a 64-bit ELF file
* The byte after that (`0x01`) indicates that this is little-endian encoded, meaning that, for instance, an unsigned 16-bit integer with the value of 2 would be stored as `0x0200` rather than `0x0002`.
* After that, the following byte (also) `0x01` indicates that it is the current version of an ELF file
* The next one (`0x00`) indicates that this is targeting the SYSV ABI, and the one after that (also `0x00`) would be used to specify which version, were different incompatible versions of the ABI to exist.
* The remaining bytes are unused.

#### `e_type`:
```
┌─────────┬───────┐
│ 10 - 11 │ 03 00 │
└─────────┴───────┘
```
* Setting this to 3 (again, little-endian) means that this is a shared object

#### `e_machine`:
```
┌─────────┬───────┐
│ 12 - 13 │ 3e 00 │
└─────────┴───────┘
```
* 62 (`0x3e`) is the value for "AMD x86-64 architecture"

#### `e_version`
```
┌─────────┬─────────────┐
│ 14 - 17 │ 01 00 00 00 │
└─────────┴─────────────┘
```
* Why use 4 bytes on a field with only 1 valid value? I'd guess that they expected there to be future versions that have yet to come into existence.

#### `e_entry`
```
┌─────────┬─────────────────────────┐
│ 18 - 1f │ 90 d6 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* Transfer control at virtual address 54928 (`0x90d6` in little-endian hexadecimal)

#### `e_phoff`
```
┌─────────┬─────────────────────────┐
│ 20 - 27 │ 40 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* program header table begins after the first 64 (`0x40` in little-endian hexadecimal) bytes in the file

#### `e_shoff`
```
┌─────────┬─────────────────────────┐
│ 28 - 2f │ d8 e3 0a 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* section header table begins after the first 713688 (`0xd8e30a` in little-endian hexadecimal) bytes in the file

#### `e_flags`
```
┌─────────┬─────────────┐
│ 30 - 33 │ 00 00 00 00 │
└─────────┴─────────────┘
```
* currently unused

#### `e_ehsize`
```
┌─────────┬───────┐
│ 34 - 35 │ 40 00 │
└─────────┴───────┘
```
* the elf header is 64 bytes long

#### `e_phentsize`
```
┌─────────┬───────┐
│ 36 - 37 │ 38 00 │
└─────────┴───────┘
```
* program header table entries are `0x38` (56) bytes long

#### `e_phnum`
```
┌─────────┬───────┐
│ 38 - 39 │ 0b 00 │
└─────────┴───────┘
```
* there are 11 entries in the program header table

#### `e_shentsize`
```
┌─────────┬───────┐
│ 3a - 3b │ 40 00 │
└─────────┴───────┘
```
* each entry in the section header table is 64 bytes long

#### `e_shnum`

```
┌─────────┬───────┐
│ 3c - 3d │ 1c 00 │
└─────────┴───────┘
```
* there are 28 entries in the section header table

#### `e_shstrndx`
```
┌─────────┬───────┐
│ 3e - 3f │ 1b 00 │
└─────────┴───────┘
```
* section header name string table is at index 27

## Program Header

The Program header is a struct that differs between 32-bit and 64-bit

### Elf64_Phdr
data       | bytes | type        | description
-----------|-------|-------------|----------------
`p_type`   | 4     | Elf64_Word  | Segment type
`p_flags`  | 4     | Elf64_Word  | Segment flags
`p_offset` | 8     | Elf64_Off   | Segment file offset
`p_vaddr`  | 8     | Elf64_Addr  | Segment virtul address
`p_paddr`  | 8     | Elf64_Addr  | Segment physical address
`p_filesz` | 8     | Elf64_Xword | Segment Size in file
`p_memsz`  | 8     | Elf64_Xword | Segment size in memory
`p_align`  | 8     | Elf64_Xword | Segment alignment


## Real-World Example (Again)

This the xxd-formatted hexdump of a simple 169-byte amd64 Hello world ELF binary I found on [StackOverflow](https://stackoverflow.com/a/72943538).
I intend to go over every byte within it and explain its purpose, as a way to test and/or further my understanding of the ELF format.

```xxd
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0200 3e00 0100 0000 7800 0100 0000 0000  ..>.....x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0000 0000 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0100 0000 0000  ................
00000060: 3100 0000 0000 0000 3100 0000 0000 0000  1.......1.......
00000070: 0200 0000 0000 0000 b801 0000 00bf 0100  ................
00000080: 0000 be9a 0001 00ba 0f00 0000 0f05 b83c  ...............<
00000090: 0000 00bf 0000 0000 0f05 4865 6c6c 6f2c  ..........Hello,
000000a0: 2057 6f72 6c64 210a 00                    World!..
```

### ELF Header
```
┌────────┬─────────────────────────┬─────────────────────────┐
│00000000│ 7f 45 4c 46 02 01 01 00 ┊ 00 00 00 00 00 00 00 00 │
│00000010│ 02 00 3e 00 01 00 00 00 ┊ 78 00 01 00 00 00 00 00 │
│00000020│ 40 00 00 00 00 00 00 00 ┊ 00 00 00 00 00 00 00 00 │
│00000030│ 00 00 00 00 40 00 38 00 ┊ 01 00 00 00 00 00 00 00 │
└────────┴─────────────────────────┴─────────────────────────┘
```

#### `e_ident`
```
┌─────────┬─────────────────────────────────────────────────┐
│ 00 - 0f │ 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────────────────────────────┘
```

The `e_ident` bytes are the same as the previously-analyzed busybox executable, so I'm going to just be lazy and paste in the previous analysis
* The first 4 bytes (`0x7f454c46`) are the magic number
* The next byte (`0x02`) indicates that this is a 64-bit ELF file
* The byte after that (`0x01`) indicates that this is little-endian encoded, meaning that, for instance, an unsigned 16-bit integer with the value of 2 would be stored as `0x0200` rather than `0x0002`.
* After that, the following byte (also `0x01`) indicates that it is the current version of an ELF file
* The next one (`0x00`) indicates that this is targeting the SYSV ABI, and the one after that (also `0x00`) would be used to specify which version, were different incompatible versions of the ABI to exist.
* The remaining bytes are unused.


#### `e_type`
```
┌─────────┬───────┐
│ 10 - 11 │ 02 00 │
└─────────┴───────┘
```

* `e_type` is 2 (in little-endian), which indicates that this is an executable

#### `e_machine`:
```
┌─────────┬───────┐
│ 12 - 13 │ 3e 00 │
└─────────┴───────┘
```
* 62 (`0x3e`) is the value for "AMD x86-64 architecture"

#### `e_version`
```
┌─────────┬─────────────┐
│ 14 - 17 │ 01 00 00 00 │
└─────────┴─────────────┘
```
* Again, 4 bytes, which if set to 1, mean "current version", but if set to any of the other 4294967295 possible values, it's invalid. Silly, even if it made sense at the time it was designed

#### `e_entry`
```
┌─────────┬─────────────────────────┐
│ 18 - 1f │ 78 00 01 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* Transfer control at virtual address 65656 (`0x780001` in little-endian hexadecimal)

#### `e_phoff`
```
┌─────────┬─────────────────────────┐
│ 20 - 27 │ 40 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* program header table begins after the first 64 (`0x40` in little-endian hexadecimal) bytes in the file

#### `e_shoff`
```
┌─────────┬─────────────────────────┐
│ 28 - 2f │ 00 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* there is no section header

#### `e_flags`
```
┌─────────┬─────────────┐
│ 30 - 33 │ 00 00 00 00 │
└─────────┴─────────────┘
```
* currently unused

#### `e_ehsize`
```
┌─────────┬───────┐
│ 34 - 35 │ 40 00 │
└─────────┴───────┘
```
* the elf header is 64 bytes long

#### `e_phentsize`
```
┌─────────┬───────┐
│ 36 - 37 │ 38 00 │
└─────────┴───────┘
```
* program header table entries are `0x38` (56) bytes long

#### `e_phnum`
```
┌─────────┬───────┐
│ 38 - 39 │ 01 00 │
└─────────┴───────┘
```
* there is 1 entry in the program header table

#### `e_shentsize`
```
┌─────────┬───────┐
│ 3a - 3b │ 00 00 │
└─────────┴───────┘
```
* each entry in the section header table is 0 bytes long (because there is no section header table)

#### `e_shnum`

```
┌─────────┬───────┐
│ 3c - 3d │ 00 00 │
└─────────┴───────┘
```
* there are 0 entries in the section header table

#### `e_shstrndx`
```
┌─────────┬───────┐
│ 3e - 3f │ 00 00 │
└─────────┴───────┘
```
* section header name string table is at index 0 (i.e. null)

### Program Header
```
┌────────┬─────────────────────────┬─────────────────────────┐
│00000040│ 01 00 00 00 05 00 00 00 ┊ 00 00 00 00 00 00 00 00 │
│00000050│ 00 00 01 00 00 00 00 00 ┊ 00 00 01 00 00 00 00 00 │
│00000060│ 31 00 00 00 00 00 00 00 ┊ 31 00 00 00 00 00 00 00 │
│00000070│ 02 00 00 00 00 00 00 00 ┊                         │
└────────┴─────────────────────────┴─────────────────────────┘
```
#### `p_type`
```
┌─────────┬─────────────┐
│ 40 - 43 │ 01 00 00 00 │
└─────────┴─────────────┘
```

#### `p_flags`
```
┌─────────┬─────────────┐
│ 44 - 47 │ 05 00 00 00 │
└─────────┴─────────────┘
```

#### `p_offset`
```
┌─────────┬─────────────────────────┐
│ 48 - 4f │ 00 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```

#### `p_vaddr`
```
┌─────────┬─────────────────────────┐
│ 50 - 57 │ 00 00 01 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```

#### `p_paddr`
```
┌─────────┬─────────────────────────┐
│ 58 - 5f │ 00 00 01 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```

#### `p_filesz`
```
┌─────────┬─────────────────────────┐
│ 60 - 67 │ 31 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```

#### `p_memsz`
```
┌─────────┬─────────────────────────┐
│ 68 - 6f │ 31 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```

#### `p_align`
```
┌─────────┬─────────────────────────┐
│ 70 - 7f │ 02 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```

### The rest of the file

```
┌────────┬─────────────────────────┬─────────────────────────┐
│00000078│                         ┊ b8 01 00 00 00 bf 01 00 │
│00000080│ 00 00 be 9a 00 01 00 ba ┊ 0f 00 00 00 0f 05 b8 3c │
│00000090│ 00 00 00 bf 00 00 00 00 ┊ 0f 05 48 65 6c 6c 6f 2c │
│000000a0│ 20 57 6f 72 6c 64 21 0a ┊ 00                      │
└────────┴─────────────────────────┴─────────────────────────┘
```

# Assembly and Linux ABI

## x86_64
I figured that I'd start with `x86_64` assembly, as it's the native format for the system I'm working on.

The `syscall` instruction is `0f 05`, and it reads the system call number from the `rax`, writes its return values to `rax` and `rdx`. It reads arguments from registers `rdi`, `rsi`, `rdx`, `r10`, `r8`, and `r9`.

* The `write` instruction is given the number `1`. It reads the file descriptor to write to from `rdi`, the message to print from `rsi`, and the size of the message from `rdx`.
* The `exit` syscall is given the number `60`. It reads the exit code from `rdi`.

[//]: <> ( vim: set et ai nowrap: )
