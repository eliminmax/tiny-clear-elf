# ELF format
<!-- vim: set et ai nowrap: -->
## Table of Contents

<!-- vim-markdown-toc GFM -->

* [Introduction](#introduction)
* [ELF Header](#elf-header)
* [Fields](#fields)
  * [`e_ident` byte-by-byte](#e_ident-byte-by-byte)
  * [Real-world example](#real-world-example)
    * [`e_ident`](#e_ident)
    * [`e_type`](#e_type)
    * [`e_machine`](#e_machine)
    * [`e_version`](#e_version)
    * [`e_entry`](#e_entry)
    * [`e_phoff`](#e_phoff)
    * [`e_shoff`](#e_shoff)
    * [`e_flags`](#e_flags)
    * [`e_ehsize`](#e_ehsize)
    * [`e_phentsize`](#e_phentsize)
    * [`e_phnum`](#e_phnum)
    * [`e_shentsize`](#e_shentsize)
    * [`e_shnum`](#e_shnum)
    * [`e_shstrndx`](#e_shstrndx)
* [Program Header](#program-header)
  * [Elf32_Phdr](#elf32_phdr)
  * [Elf64_Phdr](#elf64_phdr)
  * [Field values](#field-values)
    * [`p_type`](#p_type)
    * [`p_flags`](#p_flags)
    * [`p_offset`](#p_offset)
    * [`p_vaddr`](#p_vaddr)
    * [`p_paddr`](#p_paddr)
    * [`p_memsz`](#p_memsz)
    * [`p_align`](#p_align)

<!-- vim-markdown-toc -->

## Introduction

This page was made with reference to `elf.h` from the GNU C Library, and `ELF(5)` from the Linux man-pages project.

<details><summary><b>Note about Notation</b></summary>
<p>
<code>elf.h</code> defines various data types, such as <code>Elf32_Half</code>, <code>Elf32_Word</code>, and <code>Elf64_Half</code>,
as well as constants like <code>EI_NIDENT</code> and <code>EI_MAG1</code>. Every type defined has an <code>Elf32_</code> and
<code>Elf64_</code> version, but constants are shared across both 32-bit and 64-bit versions. Some data types are different sizes on
32-bit systems than on 64-bit systems. I am using the notation <code>ElfNN_foo</code> to refer to both <code>Elf32_foo</code> and
<code>Elf64_foo</code>.
</p>
</details>

## ELF Header

The layout of a 32-bit ELF header is defined in the struct `Elf32_Ehdr`, and its 64-bit counterpart is defined in `Elf64_Ehdr`.
The difference between those structs is that the 32-bit version uses `Elf32_` data types, while the 64-bit version uses `Elf64_` data types.
Here's the structure of both the `Elf32_Ehdr` and the `Elf64_Ehdr`, with each field's data type, size, and effective type from `stdint.h`.

## Fields

The ELF header is a struct containing the following data:

| field         | type (in `elf.h`)       | effective type       | description                                                                                                                                                                    |
|---------------|-------------------------|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `e_ident`     | unsigned char[E_NIDENT] | unsigned char[16]    | info about the ELF file                                                                                                                                                        |
| `e_type`      | ElfNN_Half              | unsigned 16-bit int  | type of ELF file: `ET_NONE` (0) for unknown, `ET_REL` (1) for relocatable, `ET_EXEC` (2) for an executable, `ET_DYN` (3) for a shared object, or `ET_CORE` (4) for a core file |
| `e_machine`   | ElfNN_Half              | unsigned 16-bit int  | target CPU architecture                                                                                                                                                        |
| `e_version`   | ElfNN_Word              | unsigned 32-bit int  | file version: `EV_NONE` (0) for invalid version, `EV_CURRENT` (1) for current version                                                                                          |
| `e_entry`     | ElfNN_Addr\*            | unsigned N-bit int\* | virtual address to transfer control at (0 if file has no entry point)                                                                                                          |
| `e_phoff`     | ElfNN_Off\*             | unsigned N-bit int\* | file offset for program header table in bytes (0 if file has no program header table)                                                                                          |
| `e_shoff`     | ElfNN_Off\*             | unsigned N-bit int\* | file offset for section header table in bytes (0 if file has no section header table)                                                                                          |
| `e_flags`     | ElfNN_Word              | unsigned 32-bit int  | processor-specific flags
| `e_ehsize`    | ElfNN_Half              | unsigned 16-bit int  | size of the elf header in bytes                                                                                                                                                |
| `e_phentsize` | ElfNN_Half              | unsigned 16-bit int  | size of an entry in the program header table in bytes                                                                                                                          |
| `e_phnum`     | ElfNN_Half              | unsigned 16-bit int  | number of entries in the program header table                                                                                                                                  |
| `e_shentsize` | ElfNN_Half              | unsigned 16-bit int  | size of an entry in the section header table in bytes                                                                                                                          |
| `e_shnum`     | ElfNN_Half              | unsigned 16-bit int  | number of entries in the section header table                                                                                                                                  |
| `e_shstrndx`  | ElfNN_Half              | unsigned 16-bit int  | index of section header table entry names, or `0xffff` if it would be larger than `0xff00`. If no section header name string table exists, it is set to `SHN_UNDEF` (0)        |

\* `elf.h` defines both `Elf32_Addr` and `Elf32_Off` as `uint32_t`, and both `Elf64_Addr` and `Elf64_Off` as `uint64_t`

### `e_ident` byte-by-byte

| byte index | field name      | description                                                                                                                         |
|------------|-----------------|-------------------------------------------------------------------------------------------------------------------------------------|
| `0`        | `EI_MAG0`       | 1st byte of the ELF magic number - its value must be set to `0x7f` (non-printable)                                                  |
| `1`        | `EI_MAG1`       | 2nd byte of the ELF magic number - its value must be set to `0x45` ('`E`')                                                          |
| `2`        | `EI_MAG2`       | 3rd byte of the ELF magic number - its value must be set to `0x4c` ('`L`')                                                          |
| `3`        | `EI_MAG3`       | 4th byte of the ELF magic number - its value must be set to `0x46` ('`F`')                                                          |
| `4`        | `EI_CLASS`      | this ELF file - `ELFCLASSNONE` (0) is invalid, `ELFCLASS32` (1) is 32-bit, and `ELFCLASS64` (2) is 64-bit                           |
| `5`        | `EI_DATA`       | data encoding - `ELFDATANONE` (0) is invalid, `ELFDATA2LSB` (1) is little-endian, `ELFDATA2MSB` (2) is big-endian                   |
| `6`        | `EI_VERSION`    | ELF version - must be set to `EV_CURRENT` (1)                                                                                       |
| `7`        | `EI_OSABI`      | ABI to target, `ELFOSABI_NONE` (0) is almost always the right choice. See manpage `ELF(5)` for other values                         |
| `8`        | `EI_ABIVERSION` | Which ABI version to target, in case the targeted ABI has incompatible versions. Interpretation is dependent on value of `EI_OSABI` |
| `9`        |                 | Currently unused, should be set to `0x00`                                                                                           |
| `a`        |                 | Currently unused, should be set to `0x00`                                                                                           |
| `b`        |                 | Currently unused, should be set to `0x00`                                                                                           |
| `c`        |                 | Currently unused, should be set to `0x00`                                                                                           |
| `d`        |                 | Currently unused, should be set to `0x00`                                                                                           |
| `e`        |                 | Currently unused, should be set to `0x00`                                                                                           |
| `f`        |                 | Currently unused, should be set to `0x00`                                                                                           |

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

#### `e_ident`
```
┌─────────┬─────────────────────────────────────────────────┐
│ 00 - 0f │ 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────────────────────────────┘
```
* The first 4 bytes (`7f454c46`) are the magic number
* The next byte (`02`) indicates that this is a 64-bit ELF file
* The byte after that (`01`) indicates that this is little-endian encoded, meaning that, for instance, an unsigned 16-bit integer with the value of 2 would be stored as `02 00` rather than `00 02`.
* After that, the following byte (also) `01` indicates that it is the current version of an ELF file
* The next one (`00`) indicates that this is targeting the SYSV ABI, and the one after that (also `00`) would be used to specify which version, were different incompatible versions of the ABI to exist.
* The remaining bytes are unused.

#### `e_type`

```
┌─────────┬───────┐
│ 10 - 11 │ 03 00 │
└─────────┴───────┘
```

* Setting this to 3 (again, little-endian) means that this is a shared object

#### `e_machine`
```
┌─────────┬───────┐
│ 12 - 13 │ 3e 00 │
└─────────┴───────┘
```
* 62 (`3e`) is the value for "AMD x86-64 architecture"

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
* Transfer control at virtual address 54928 (`90 d6` in little-endian hexadecimal)

#### `e_phoff`
```
┌─────────┬─────────────────────────┐
│ 20 - 27 │ 40 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* program header table begins after the first 64 (`40` in little-endian hexadecimal) bytes in the file

#### `e_shoff`
```
┌─────────┬─────────────────────────┐
│ 28 - 2f │ d8 e3 0a 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* section header table begins after the first 713688 (`d8 e3 0a` in little-endian hexadecimal) bytes in the file

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
* program header table entries are `38` (56) bytes long

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

The Program header is a struct with 8 values within it, defining the location and properties of a segment within the program. The both the order and the size of the Program Header fields depend on whether the ELF file is 32-bit or 64-bit.

### Elf32_Phdr
| data       | bytes | type       | description              |
|------------|-------|------------|--------------------------|
| `p_type`   | 4     | Elf32_Word | Segment type             |
| `p_offset` | 4     | Elf32_Off  | Segment file offset      |
| `p_vaddr`  | 4     | Elf32_Addr | Segment virtual address  |
| `p_paddr`  | 4     | Elf32_Addr | Segment physical address |
| `p_filesz` | 4     | Elf32_Word | Segment size in file     |
| `p_memsz`  | 4     | Elf32_Word | Segment size in memory   |
| `p_flags`  | 4     | Elf32_Word | Segment flags            |
| `p_align`  | 4     | Elf32_Word | Segment alignment        |

### Elf64_Phdr
| data       | bytes | type        | description              |
|------------|-------|-------------|--------------------------|
| `p_type`   | 4     | Elf64_Word  | Segment type             |
| `p_flags`  | 4     | Elf64_Word  | Segment flags            |
| `p_offset` | 8     | Elf64_Off   | Segment file offset      |
| `p_vaddr`  | 8     | Elf64_Addr  | Segment virtual address  |
| `p_paddr`  | 8     | Elf64_Addr  | Segment physical address |
| `p_filesz` | 8     | Elf64_Xword | Segment Size in file     |
| `p_memsz`  | 8     | Elf64_Xword | Segment size in memory   |
| `p_align`  | 8     | Elf64_Xword | Segment alignment        |

### Field values

#### `p_type`

Valid field values are listed in `elf.h`. The only one of interest to this project is `PT_LOAD` (1), which indicates that this is a loadable program segment.

#### `p_flags`

This is similar to Unix permissions. If the segment is readable, add 4, if it's writable, add 2, and if it's executable, add 1. For a readable, executable segment, set it to 5.

#### `p_offset`

Offset from the beginning of the file to the segment described

#### `p_vaddr`

Virtual address of the first byte of the segment in memory

#### `p_paddr`

The physical address of the segment - not used on all systems. On BSD, it must be 0.

#### `p_memsz`

Size (in bytes) of the segment in memory

#### `p_align`

Segments are to be aligned to this value. Must be either 0 or a positive power of 2. If set to 0 or 1, alignment does not matter. Otherwise, `p_vaddr % p_align` must equal `p_offset % p_align`
If not set to 0, must be a positive power of 2, and "`p_vaddr` should be equal to `p_offset` modulo `p_align`"

