# MIPS® family architectures

## Table of Contents

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
  * [Registers](#registers)
    * [Notes](#notes)
  * [Instruction Structure](#instruction-structure)
    * [R Instructions](#r-instructions)
      * [Binary form](#binary-form)
    * [I Instructions](#i-instructions)
      * [Binary form](#binary-form-1)
    * [J Instructions](#j-instructions)
    * [FR and FI](#fr-and-fi)
* [Loading values into registers](#loading-values-into-registers)
* [Syscall Instruction](#syscall-instruction)

<!-- vim-markdown-toc -->

## Overview

The contents of this page generally apply to MIPS systems running Linux-based systems, regardless of ABI or byte ordering.

### Registers

MIPS provides 32 general-purpose registers, and 32 floating-point registers.

The floating-point registers can be referred to as `$f{N}`, where `{N}` is the register number (i.e. `$f0`, `$f1`, `$f2`, … `$f31`)

The general-purpose registers can be referred to either in numeric form (i.e. `$0`, `$1`, `$2`, … `$31`), or by name. A table of the names and purposes of the registers can be found in Section 4 of the *MIPS Assembly* book on WikiBooks, in the *Register Files* page ([link](https://en.m.wikibooks.org/wiki/MIPS_Assembly/Register_File)).

I'm including a tiny subset of the rows from the table in the page linked above. Follow the link for the full table.

|Number       | Name           | Comments|
|-------------|----------------|-------------------|
|`$0`         | `$zero`, `$r0` | Always zero|
|`$2`, `$3`   | `$v0`, `$v1`   | First and second return values, respectively|
|`$4`…`$7`    | `$a0`…`$a3`    | First four arguments to functions|
|`$8`… `$15`  | `$t0`…`$t7`    | Temporary registers|
|`$24`…`$25`  | `$t8`…`$t9`    | More temporary registers|

#### Notes

The `$zero` register is "always zero" at a hardware level - it cannot be set to another value.

the `$v0` register is also used to pass the syscall number to the linux kernel

The temporary registers are usable for any purpose when working in assembly (or directly in binary), but are cleared when executing a function call.

### Instruction Structure

Each instruction is exactly 4 bytes (32 bits) long. There are 5 instruction types: `R`, `I`, `J`, `FR`, and `FI`. The details of the instruction types can be found in the *Instruction Formats* page of the aforementioned book on WikiBooks ([link](https://en.m.wikibooks.org/wiki/MIPS_Assembly/Instruction_Formats)). That page lists them in their big-endian form, but the little-endian form is the same with the byte order reversed.

Instructions are often fairly straightforward in big-endian form, but because fields are not byte-aligned, they can be confusing in little endian form. Because of this, I am using the big-endian form here. In little-endian binaries, figure out the big-endian instruction in binary, and reverse the order of the 4 bytes.


#### R Instructions

Format in assembly:
```
OP rd, rs, rt
````

Meaning: perform the `OP` operation on the values in `rs` and `rt`, and write the result to `rd`

Example - add the values stored in `$t8` and `$t9`, and store the result in `$t7`:

```asm
add $t7, $t8, $t9
```

##### Binary form

|opcode | rs     | rt     | rd     | shift  | funct|
|-------|--------|--------|--------|--------|-------|
|6 bits | 5 bits | 5 bits | 5 bits | 5 bits | 6 bits|

Multiple operations can share a single opcode. When they do, the funct field is used to diffrentiate them. The *Instruction Formats* page linked above uses the following example:

> 0x00 refers to an ALU operation and 0x20 refers to ADDing specifically.

The shift (or shamt) field is used in the shift and rotate instructions, and specifies how many bits to shift/rotate by.

The above `add` example would be `03197820` in hex, or in raw binary:

```
000000 11000 11001 01111 00000 100000
```

Breaking that down into its individual fields

|        | opcode   | rs      | rt      | rd      | shift   | funct    |
|--------|----------|---------|---------|---------|---------|----------|
| Binary | `000000` | `11000` | `11001` | `01111` | `00000` | `100000` |
| Dec    | 0        | 24      | 25      | 15      | 0       | 32       |

#### I Instructions

I instructions can take 2 different forms in assembly:

```
OP rt, IMM(rs)
```

```
OP rs, rt, IMM
```

Meaning: perform the `OP` operation on the value in `rs` and the immediate `IMM`, and store the result in `rt`.

According to the *Instruction Formats* page linked above, the former is the proper form for all but two instructions - `beq` and `bne` (i.e. *branch if equal* and *branch if not equal*), which should use the latter form.

The GNU assembler does not seem to like the former form, so I'm using the latter in all cases.

Example: Add 32 (`0x20`) to the value stored in `$t8`, and store the result in t7:

```asm
addi $t7, 0x20($t8)
```

##### Binary form

| opcode | rs     | rt     | IMM     |
|--------|--------|--------|---------|
| 6 bits | 5 bits | 5 bits | 16 bits |

The above `addi` example would be `230f0020` in hex, or in raw binary:

```
001000 11000 01111 0000000000100000
```

#### J Instructions

Not going to go into as much detail here - it's not relevant to this project, and the *Instruction Formats* page linked above is a better general-purpose reference anyway.

| Opcode | Pseudo-Address |
|--------|----------------|
| 6 bits | 26 bit         |

The *Instruction Formats* page describes the Pseudo-Address field as follows:

> A 26-bit shortened address of the destination. (0 to 25). The full 32-bit destination address is formed by concatenating the highest 4 bits of the PC (the address of the instruction following the jump), the 26-bit pseudo-address, and 2 zero bits (since instructions are always aligned on a 32-bit word).

#### FR and FI

Like R and I Instructions respectively, but for floating-point registers. See the *Instruction Formats* page for details.

## Loading values into registers

For values that fit within 16 bits, one way to load a value is to use the `addiu` (i.e. add unsigned immediate, opcode `0x09`) instruction, in the following form:

```
addiu rt, IMM($zero)
```

So to set `$t7` to the hex value `feed`\*, one would use the following instruction:

```asm
addiu $t7, 0xfeed($zero)
```

\* At time of writing, I'm hungry.

The process to load 32-bit values requires 2 instructions.

The first is `lui` (i.e. load upper immediate, opcode `0x0f`), to set the upper 16 bytes, followed by either an `addiu` (i.e. add unsigned immediate, opcode `0x09`) or `ori` (i.e. bitwise or immediate, opcode `0x0d`), to set the lower 16 bits. Note that `lui` zeroes out the lower 16 bits, so the order is important, and there's no risk of interference from a previous value.

Assemblers typically allow a `li` (i.e. load immediate) pseudo-instruction that is split into that kind of instruction pair, but working by hand in a hex editor provides no such luxury.

To load the hex value `feedcafe` into register `$t7`, one could use the following instructions:

```asm
lui $t7, 0xfeed
ori $t7, 0xcafe($t7)
```

## Syscall Instruction

The syscall instruction, in little-endian form, is `0c000000`. In big-endian form, it's `0000000c`.
