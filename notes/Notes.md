This document is primarily written for someone with similar background knowledge to me.

# Table of Contents


<!-- vim-markdown-toc GFM -->

* [Assembly and Linux ABI](#assembly-and-linux-abi)
  * [x86_64](#x86_64)
    * [registers](#registers)
    * [Linux ABI](#linux-abi)
  * [i386](#i386)
    * [registers](#registers-1)
    * [Linux ABI](#linux-abi-1)
* [Bringing it all together - Real-World Example](#bringing-it-all-together---real-world-example)
    * [ELF Header](#elf-header)
      * [`e_ident`](#e_ident)
      * [`e_type`](#e_type)
      * [`e_machine`:](#e_machine)
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
      * [`p_type`](#p_type)
      * [`p_flags`](#p_flags)
      * [`p_offset`](#p_offset)
      * [`p_vaddr`](#p_vaddr)
      * [`p_paddr`](#p_paddr)
      * [`p_filesz`](#p_filesz)
      * [`p_memsz`](#p_memsz)
      * [`p_align`](#p_align)
    * [The rest of the file](#the-rest-of-the-file)
      * [First Syscall](#first-syscall)
      * [Second Syscall](#second-syscall)

<!-- vim-markdown-toc -->

# Assembly and Linux ABI

A full list of syscalls can be found in the `SYSCALLS(2)` man page from the Linux man-pages project, and the registers that they read and write to are detailed in the confusingly-similarly named `SYSCALL(2)` man page from the same project. The only two directly needed in this project are `write` and `exit`.

Note that the register "value" field is the way to target the register with a `mov` command or its equivalent.

## x86_64

I figured that I'd start with `x86_64` assembly, as it's the native format for the system I'm working on.

### registers

<details>
<summary>How this table was made</summary>
<p>Using the first table on the <a href="https://wiki.osdev.org/CPU_Registers_x86-64">OSDev.org wiki page on x86_64 CPU Registers</a>, as a base, I used the Netwide Assembler to get their values</p>
</details>

64-bit name | 64-bit value | 32-bit name | 32-bit value | 16-bit name | 16-bit value | 8 high bits of lower 16 bits name | 8 high bits of lower 16 bits value | 8-bit name | 8-bit value | Description
------------|--------------|-------------|--------------|-------------|--------------|-----------------------------------|------------------------------------|------------|-------------|-------------------------------------------
RAX         | `48 b8`      | EAX         | `b8`         | AX          | `66 b8`      | AH                                | `b4`                               | AL         | `b0`        | Accumulator
RBX         | `48 bb`      | EBX         | `bb`         | BX          | `66 bb`      | BH                                | `b7`                               | BL         | `b3`        | Base
RCX         | `48 b9`      | ECX         | `b9`         | CX          | `66 b9`      | CH                                | `b5`                               | CL         | `b1`        | Counter
RDX         | `48 ba`      | EDX         | `ba`         | DX          | `66 ba`      | DH                                | `b6`                               | DL         | `b2`        | Data (commonly extends the A register)
RSI         | `48 be`      | ESI         | `be`         | SI          | `66 be`      | N/A                               | N/A                                | SIL        | `40 b6`     | Source index for string operations
RDI         | `48 bf`      | EDI         | `bf`         | DI          | `66 bf`      | N/A                               | N/A                                | DIL        | `40 b7`     | Destination index for string operations
RSP         | `48 bc`      | ESP         | `bc`         | SP          | `66 bc`      | N/A                               | N/A                                | SPL        | `40 b4`     | Stack Pointer
RBP         | `48 bd`      | EBP         | `bd`         | BP          | `66 bd`      | N/A                               | N/A                                | BPL        | `40 b5`     | Base Pointer (meant for stack frames)
R8          | `49 b8`      | R8D         | `41 b8`      | R8W         | `66 41 b8`   | N/A                               | N/A                                | R8B        | `41 b0`     | General purpose
R9          | `49 b9`      | R9D         | `41 b9`      | R9W         | `66 41 b9`   | N/A                               | N/A                                | R9B        | `41 b1`     | General purpose
R10         | `49 ba`      | R10D        | `41 ba`      | R10W        | `66 41 ba`   | N/A                               | N/A                                | R10B       | `41 b2`     | General purpose
R11         | `49 bb`      | R11D        | `41 bb`      | R11W        | `66 41 bb`   | N/A                               | N/A                                | R11B       | `41 b3`     | General purpose
R12         | `49 bc`      | R12D        | `41 bc`      | R12W        | `66 41 bc`   | N/A                               | N/A                                | R12B       | `41 b4`     | General purpose
R13         | `49 bd`      | R13D        | `41 bd`      | R13W        | `66 41 bd`   | N/A                               | N/A                                | R13B       | `41 b5`     | General purpose
R14         | `49 be`      | R14D        | `41 be`      | R14W        | `66 41 be`   | N/A                               | N/A                                | R14B       | `41 b6`     | General purpose
R15         | `49 bf`      | R15D        | `41 bf`      | R15W        | `66 41 bf`   | N/A                               | N/A                                | R15B       | `41 b7`     | General purpose

When setting 64-bit registers' 32-bit equivalents, the higher 32-bits are zeroed out automatically. Thus, `b8 01 00 00 00` has the same effect as `48 b8 01 00 00 00 00 00 00 00`, in half the bytes.
*(Incidentally, this caused me some trouble creating the above table, as the Netwide Assembler is smart enough to assemble* `mov rax,0` *as* `b8 00 00 00 00`, *and as I couldn't find the hex identifiers of the registers online,
I was using it to build the above table. Thanks to [This StackOverflow answer](https://stackoverflow.com/a/26505463) for the fix for that, by the way).*

### Linux ABI

The `syscall` instruction is `0f 05`, and it reads the system call number from RAX, writes its return values to RAX and RDX. It reads arguments from registers RDI, RSI, RDX, R10, R8, and R9.

* The `write` syscall is given the number `1`. It reads the file descriptor to write to from RDI, the memory address of the message to print from RSI, and the size of the message from RDX.
* The `exit` syscall is given the number `60`. It reads the exit code from RDI.

On my primary system, running Pop!_OS 22.04, the full list of syscalls' numeric codes can be found in the file **/usr/include/x86_64-linux-gnu/asm/unistd_64.h** provided by the `linux-libc-dev:amd64` package

## i386

### registers

 32-bit value | 16-bit name | 16-bit value | 8 high bits of lower 16 bits name | 8 high bits of lower 16 bits value | 8-bit name | 8-bit value | Description
--------------|-------------|--------------|-----------------------------------|------------------------------------|------------|-------------|-------------------------------------------
 `b8`         | AX          | `66 b8`      | AH                                | `b4`                               | AL         | `b0`        | Accumulator
 `bb`         | BX          | `66 bb`      | BH                                | `b7`                               | BL         | `b3`        | Base
 `b9`         | CX          | `66 b9`      | CH                                | `b5`                               | CL         | `b1`        | Counter
 `ba`         | DX          | `66 ba`      | DH                                | `b6`                               | DL         | `b2`        | Data (commonly extends the A register)
 `be`         | SI          | `66 be`      | N/A                               | N/A                                | SIL        | `40 b6`     | Source index for string operations
 `bf`         | DI          | `66 bf`      | N/A                               | N/A                                | DIL        | `40 b7`     | Destination index for string operations
 `bc`         | SP          | `66 bc`      | N/A                               | N/A                                | SPL        | `40 b4`     | Stack Pointer
 `bd`         | BP          | `66 bd`      | N/A                               | N/A                                | BPL        | `40 b5`     | Base Pointer (meant for stack frames)

This is a subset of the registers available in x86_64.

On my primary system, the full list of syscalls' numeric codes can be found in the file **/usr/i686-linux-gnu/include/asm/unistd_32.h**, provided by the `linux-libc-dev-i386-cross` package

### Linux ABI

There is no instructuion called `syscall` in the i386 Linux ABI, but the functionality is provided with the assembly `int 0x80`, which in hex is `cd 80`. It reads arguments from registers EBX, ECX, EDX, ESI, EDI, and EBP
* The `write` syscall is given the number `4`. It reads the file descriptor to write to from EBX, the memory address of the message to print from ECX, and the size of the message from EDX.
* The `exit` syscall is given the number `1`. It reads the exit code from EBX.

# Bringing it all together - Real-World Example
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

The `e_ident` bytes are the same as the previously-analyzed Busybox executable, so I'm going to just be lazy and paste in the previous analysis
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
* This is a loadable segment

#### `p_flags`
```
┌─────────┬─────────────┐
│ 44 - 47 │ 05 00 00 00 │
└─────────┴─────────────┘
```
* This segment is readable and executable

#### `p_offset`
```
┌─────────┬─────────────────────────┐
│ 48 - 4f │ 00 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
* This segment begins at byte 0 of the file

#### `p_vaddr`
```
┌─────────┬─────────────────────────┐
│ 50 - 57 │ 00 00 01 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
The address of the first byte of virtual memory to allocate is 0x10000

#### `p_paddr`
```
┌─────────┬─────────────────────────┐
│ 58 - 5f │ 00 00 01 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
The address of the first byte of physical memory to allocate is 0x10000

#### `p_filesz`
```
┌─────────┬─────────────────────────┐
│ 60 - 67 │ 31 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
The size of the section in the file is 0x31 bytes

#### `p_memsz`
```
┌─────────┬─────────────────────────┐
│ 68 - 6f │ 31 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
The section should be loaded into a 0x31-byte region of memory

#### `p_align`
```
┌─────────┬─────────────────────────┐
│ 70 - 77 │ 02 00 00 00 00 00 00 00 │
└─────────┴─────────────────────────┘
```
The section must be aligned to an even-numbered address

### The rest of the file

```
┌────────┬─────────────────────────┬─────────────────────────┐
│00000078│                         ┊ b8 01 00 00 00 bf 01 00 │
│00000080│ 00 00 be 9a 00 01 00 ba ┊ 0f 00 00 00 0f 05 b8 3c │
│00000090│ 00 00 00 bf 00 00 00 00 ┊ 0f 05 48 65 6c 6c 6f 2c │
│000000a0│ 20 57 6f 72 6c 64 21 0a ┊ 00                      │
└────────┴─────────────────────────┴─────────────────────────┘
```

#### First Syscall
```
┌─────────┬────────────────┐
│ 78 - 7c │ b8 01 00 00 00 │
└─────────┴────────────────┘
┌─────────┬────────────────┐
│ 7d - 81 │ bf 01 00 00 00 │
└─────────┴────────────────┘
┌─────────┬────────────────┐
│ 82 - 86 │ be 9a 00 01 00 │
└─────────┴────────────────┘
┌─────────┬────────────────┐
│ 87 - 8b │ ba 0f 00 00 00 │
└─────────┴────────────────┘
```
* `b8`, `bf`, `be`, and `ba` are the identifies of specific 32-bit registers, and the next 4 bytes are the values to set it to.
  * `b8` is EAX, and it is being set to 1.
  * `bf` is EDI, and it is being set to 1.
  * `be` is ESI, and it is being set to 65690.
  * `ba` is EDX, and it is being set to 15.

```
┌─────────┬───────┐
│ 8c - 8d │ 0f 05 │
└─────────┴───────┘
```
* This is the Linux amd64 `syscall` instruction. It determines its behavior by reading RAX.
  * RAX is set to 1 (because EAX was set to 1, and EAX is the 32-bit mode version of RAX). This is the `write` syscall.
    * `write` gets its the file descriptor to write to from RDI, and file descriptor 1 is always the standard output (STDOUT)
    * `write` gets the memory address of the message to write from RSI. In this case, it's 65690. The ELF header's `e_entry` value is 65656. This means that the message to print starts 34 bytes after the entry point
    * `write` gets the length of the data to print from RDX, which is set to 15.

    * This means that it will write 15 bytes to STDOUT, which it will get starting 34 bytes after the entry point - starting at memory address 65690, which is at address `0x9a` within the file

skipping ahead a bit, to `0x9a` in the file, we get the message to print:
```
┌─────────┬──────────────────────────────────────────────┐
│ 9a - a8 │ 48 65 6c 6c 6f 2c 20 57 6f 72 6c 64 21 0a 00 │
└─────────┴──────────────────────────────────────────────┘
```
* These bytes consist of the 8-bit ASCII code of the classic text "Hello, World!", followed by a newline character, and a NULL byte.
*(As an aside, this last byte seems unneeded to me - removing it and adjusting the message length specified by RDX to 14 works fine, and running the original adds a NULL byte to the end of the output,
visible if you pipe it into a hex-dumping program like `xxd`, `hd`, or my tool of choice, [`hexyl`](https://github.com/sharkdp/hexyl).)*

#### Second Syscall

Moving back to the next syscall, it starts out similarly, by setting up the registers:

```
┌─────────┬────────────────┐
│ 8e - 93 │ b8 3c 00 00 00 │
└─────────┴────────────────┘
┌─────────┬────────────────┐
│ 94 - 97 │ bf 00 00 00 00 │
└─────────┴────────────────┘
```
* once again, the first each of these sets of 5-bytes is the 32-bit register, and the 4 bytes that follow are the value to set it to
  * b8 is EAX, and is being set to 60.
  * bf is EDI, and is being set to 0.
```
┌─────────┬───────┐
│ 98 - 99 │ 0f 05 │
└─────────┴───────┘
```
* Once again, we encounter a `syscall` instruction, but this time, it is much simpler.
  * RAX is set to 60, which is the `exit` syscall
    * `exit` gets its exit code from RDI, and exit code 0 means it is exiting successfully.


[//]: <> ( vim: set et ai nowrap: )
