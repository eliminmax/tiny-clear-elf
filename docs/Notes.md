# ELF header format

This section was made with reference to `elf.h` from the GNU C Library, and `ELF(5)` from the Linux man-pages project.

## Header fields

The ELF header is a struct containing the following data:

data          | bytes    | type                | description
--------------|----------|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
`e_ident`     | 16       | char array          | info about the ELF file
`e_type`      | 2        | unsigned 16-bit int | type of ELF file: `ET_NONE` (0) for unknown, `ET_REL` (1) for relocatable, `ET_EXEC` (2) for an executable, `ET_DYN` (3) for a shared object, or `ET_CORE` (4) for a core file
`e_machine`   | 2        | unsigned 16-bit int | target CPU architecture
`e_version`   | 4        | unsigned 32-bit int | file version: `EV_NONE` (0) for invalid version, `EV_CURRENT` (1) for current version
`e_entry`     | 32 or 64 | ElfN_Addr*          | virtual address to transfer control at (0 if file has no entry point)
`e_phoff`     | 32 or 64 | ElfN_Off*           | file offset for program header table in bytes (0 if file has no program header table)
`e_shoff`     | 32 or 64 | ElfN_Off*           | file offset for section header table in bytes (0 if file has no section header table)
`e_flags`     | 32       | unsigned 32-bit int | processor-specific flags, currently none are defined
`e_ehsize`    | 16       | unsigned 16-bit int | size of the elf header in bytes
`e_phentsize` | 16       | unsigned 16-bit int | size of an entry in the program header table in bytes
`e_phnum`     | 16       | unsigned 16-bit int | number of entries in the program header table
`e_shentsize` | 16       | unsigned 16-bit int | size of an entry in the section header table in bytes
`e_shnum`     | 16       | unsigned 16-bit int | number of entries in the section header table
`e_shstrndx`  | 16       | unsigned 16-bit int | index of section header table entry names, or `0xffff` if it would be larger than `0xff00`. If no section header name string table exists, it is set to `SHN_UNDEF` (0)

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
│00000040│ 06 00 00 00 04 00 00 00 ┊ 40 00 00 00 00 00 00 00 │
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
* After that, the following byte (also `0x01` indicates that it is the current version of an ELF file)
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


# Assembly and Linux ABI

## x86_64
I figured that I'd start with `x86_64` assembly, as it's the native format for the system I'm working on.

The `syscall` instruction is `0f 05`, and it reads the system call number from the `rax`, writes its return values to `rax` and `rdx`. It reads arguments from registers `rdi`, `rsi`, `rdx`, `r10`, `r8`, and `r9`.

* The `write` instruction is given the number `1`. It reads the file descriptor to write to from `rdi`, the message to print from `rsi`, and the size of the message from `rdx`.
* The `exit` syscall is given the number `60`. It reads the exit code from `rdi`.



[//]: <> ( vim: set et ai nowrap: )
