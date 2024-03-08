# RVC

The optional RISC-V "C" Standard Extension for Compressed Instructions, documented in Chapter 16 of Volume I of the manual [downloadable here](https://drive.google.com/file/d/1s0lZxUZaa7eV_O0_WsZzaurFLLww7ou5/view?pli=1), offers alternative 16-bit encodings of some common 32-bit instructions, when

> * the immediate or address offset is small, or
> * one of the registers is the zero register (`x0`), the ABI link register (`x1`), or the ABI stack pointer (`x2`), or
> * the destination register and the first source register are identical, or
> * the registers used are the 8 most popular ones

(page 97)

Debian requires support for RVC as part of the minimum RISC-V hardware requirements, meaning that while it is an extension, it is still acceptable for use in the Tiny Clear ELF project.

# Current version:

| hex        | asm                |
|------------|--------------------|
| `93080004` | `li a7, 64`        |
| `13051000` | `li a0, 1`         |
| `b7050100` | `lui a1, 0x10`     |
| `9385c509` | `addi a1, a1, 156` |
| `1306a000` | `li a2, 10`        |
| `73000000` | `ecall`            |
| `9308d005` | `li a7, 93`        |
| `13050000` | `li a0, 0`         |
| `73000000` | `ecall`            |

RISC-V's 32-bit version is a very well-designed and well-documented architecture.

The 64-bit version is a modified version of the 32-bit version, and its official specification details only its differences from the 32-bit version. Given that both are part of the same document, that's not a big deal.

Without any extensions, RV32I - the standard 32-bit version, has 4 core instruction encoding forms (R/I/S/U). The following table, adapted from figure 2.2 in the specification (page 16), details how they are laid out in memory

| 31..25    | 24..20 | 19..15 | 14..12 | 11..7 | 6..0   | encoding |
|-----------|--------|--------|--------|-------|--------|----------|
| funct7    | rs2    | rs1    | funct3 | rd    | opcode | R-type   |

| 31..20    | 19..15 | 14..12 | 11..7 | 6..0   | encoding |
|-----------|--------|--------|-------|--------|----------|
| imm[11:0] | rs1    | funct3 | rd    | opcode | I-type   |

| 31..25    | 24..20 | 19..15 | 14..12 | 11..7 | 6..0   | encoding |
|-----------|--------|--------|--------|-------|--------|----------|
| imm[11:5] | rs2    | rs1    | funct3 | rd    | opcode | S-type   |

| 31..12     | 11..7 | 6..0   | encoding |
|------------|-------|--------|----------|
| imm[31:12] | rd    | opcode | U-type   |

There are 2 other special forms - U and J, but they are not relevant to this project.

The `li` instruction, which `rasm2` reports is in use, is technically not a real instruction.
Rather, it's a pseudo-instruction which assemblers handle in a contextually appropriate way.
ADDI (an I-type instruction) adds an immediate to the contents of a source register (rs1), saving the result to a destination register (rd). I believe that the `li` instructions `rasm2` reports are actually `addi` instructions, using the special read-only `x0` register, which always contains `0`.

To test that, I'm going to look at the `li a7, 64` instruction (the first one in the table above).

Due to little-endian encoding, to decode `93080004`, the first step is to reverse the byte order, and go from hex to binary

`93 08 00 04` → `04 00 08 93` → `0000 0100` `0000 0000` `0000 1000` `1001 0011`

Now, see if that makes sense as the `addi` instruction, as hypothesized:

| imm[11:0]      | rs1     | funct3 | rd      | opcode    |
|----------------|---------|--------|---------|-----------|
| `000001000000` | `00000` | `000`  | `10001` | `0010011` |

The opcode, in combination with funct3 and, for some encodings, funct7, is what determines what specific operation to perform.

An opcode of `0010011`, in combination with a funct3 of `000`, is the `addi` instruction. An rs1 value of `00000` indicates that the source data is `x0`, the special zero register I expected (page 130).

The rd field is set to 17. According to page 137 of the manual, the ABI Name for register `x17` is `a7`, and it's meant to be used for function arguments. The imm[11:0] field is set to 64. Everything checks out.

Now, to replace all pseudo-instructions with the actual instructions and registers used:

| hex        | asm                | asm (no pseudo-instructions) |
|------------|--------------------|------------------------------|
| `93080004` | `li a7, 64`        | `addi x17, x0, 0x40`         |
| `13051000` | `li a0, 1`         | `addi x10, x0, 0x1`          |
| `b7050100` | `lui a1, 0x10`     | `lui x10, 0x10`              |
| `9385c509` | `addi a1, a1, 156` | `addi x11, x11, 0x9c`        |
| `1306a000` | `li a2, 10`        | `addi x12, x0, 0xa`          |
| `73000000` | `ecall`            | `ecall`                      |
| `9308d005` | `li a7, 93`        | `addi x17, x0, 0x5d`         |
| `13050000` | `li a0, 0`         | `addi x10, x0, 0x0`          |
| `73000000` | `ecall`            | `ecall`                      |


So there are a total of 3 unique instructions in use: `addi`, `lui`, and `ecall`. They are an I-type, a U-type, and a special case that isn't any specific type respectively.

There are a total of 5 unique registers referenced: `x0`, `x10`, `x11`, `x12`, and `x17`.

# Compressed forms

The mnemonics for compressed instructions are of the form C.MNEMONIC, where MNEMONIC is the equivalent non-compressed instruction or pseudo-instruction.

Unlike the `li` pseudo-instruction, C.LI is a valid instruction. C.ADDI can only be used to add an immediate to an existing register's value (i.e. the source and destination register must be the same). C.LUI can be used. There is no compressed `ecall` as far as I can tell.

There are far more C instruction formats than normal ones, but all 3 C instructions I have listed use the same format:

CI (Compressed Immediate) has the following form:

| 15..13 | 12  | 11..7  | 6..2 | 1 0 |
|--------|-----|--------|------|-----|
| funct3 | imm | rd/rs1 | imm  | op  |

(From page 100)

The specific instructions used all list their encoding on page 113. They are as follows:

## C.LI

| funct3 | imm    | rd/rs1   | imm      | op   |
|--------|--------|----------|----------|------|
| `010`  | imm[5] | rs1/rd≠0 | imm[4:0] | `01` |

## C.LUI

| funct3 | imm       | rd/rs1   | imm          | op   |
|--------|-----------|----------|--------------|------|
| `011`  | nzimm[17] | rs1/rd≠0 | nzimm[16:12] | `01` |

## C.ADDI

| funct3 | imm       | rd/rs1   | imm        | op   |
|--------|-----------|----------|------------|------|
| `000`  | nzimm[5]  | rs1/rd≠0 | nzimm[4:0] | `01` |

# Shortening

Again, these are the instructions used. Because the `addi x11, x11` instruction sets the memory address of the first byte of data to output, and shrinking this changes that byte, I'll save it for last.

| hex        | asm                | asm (no pseudo-instructions) |
|------------|--------------------|------------------------------|
| `93080004` | `li a7, 64`        | `addi x17, x0, 0x40`         |
| `13051000` | `li a0, 1`         | `addi x10, x0, 0x1`          |
| `b7050100` | `lui a1, 0x10`     | `lui x11, 0x10`              |
| `9385c509` | `addi a1, a1, 156` | `addi x11, x11, 0x9c`        |
| `1306a000` | `li a2, 10`        | `addi x12, x0, 0xa`          |
| `73000000` | `ecall`            | `ecall`                      |
| `9308d005` | `li a7, 93`        | `addi x17, x0, 0x5d`         |
| `13050000` | `li a0, 0`         | `addi x10, x0, 0x0`          |
| `73000000` | `ecall`            | `ecall`                      |

* `li a7, 64`/ `addi x17, x0, 0x40`
  * `64` is `1000000` in binary, which does not fit within the 6 bits available. It will need to remain full-length.

* `li a0, 1` / `addi x10, x0, 0x1`
  * this can become `c.li x10, 0x1`
    * imm = 1, rd/rs1 = 10
      * imm = `000001`, rd/rs1 = `01010`

| `010`  | imm[5] | rs1/rd≠0 | imm[4:0] | `01` |
|--------|--------|----------|----------|------|
| `010`  | `0`    | `01010`  | `00001`  | `01` |

So it becomes `0100 0101 0000 0101`. The hex for that is `4505`.
Adjusting for little-endianness, the result is `0545`.

* `lui a1, 0x10` / `lui x11, 0x10`
  * this can become `c.lui x11, 0x10`
    * imm = 16, rd/rs1 = 11
      * imm = `010000`, rd/rs1 = `01011`

| `011` | nzimm[17] | rs1/rd≠0 | imm[16:12] | `01` |
|-------|-----------|----------|------------|------|
| `011` | `0`       | `01011`  | `10000`    | `01` |

0110 0101 1100 0001 

So it becomes `0110 0101 1100 0001`. The hex for that is `65c1`.
Adjusting for little-endianness, the result is `c165`.

* `addi a1, a1, 156` / `addi x11, x11, 0x9c`
  * Skipping for the aforementioned reason

* `li a2, 10` / `addi x12, x0, 0xa`
  * this can become `c.li x12, 0xa`
    * imm = 10, rd/rs1 = 12
      * imm = `001010`, rd/rs1 = `01100`

| `010` | imm[5] | rs1/rd≠0 | imm[4:0] | `01` |
|-------|--------|----------|----------|------|
| `010` | `0`    | `01100`  | `01010`  | `01` |

So it becomes `0100 0110 0010 1001`. The hex for that is `4629`.
Adjusting for little-endianness, the result is `2946`

* `ecall`
  * has no C form

* `li a7, 93` / `addi x17, x0, 0x5d`
  * 93 (0x5d in hex) does not fit within the 6 bits available

* `li a0, 0` / `addi x10, x0, 0x0`
  * this can become `c.li x10, 0x0`
    * imm = 0, rd/rs1 = 10
      * imm = `000000`, rd/rs1 = `01010`

| `010` | imm[5] | rs1/rd≠0 | imm[4:0] | `01` |
|-------|--------|----------|----------|------|010 imm[5] rd̸=0 imm[4:0] 01 C.L
| `010` | `0`    | `01010`  | `00000`  | `01` |

So it becomes `0010 0101 0000 0001`. The hex for that is `4501`.
Adjusting for little-endianness, the result is `0145`

* `ecall`
  * still has no C form

Now, the new encodings are as follows:

| hex        | asm                | asm (no pseudo-instructions) | C hex      |
|------------|--------------------|------------------------------|------------|
| `93080004` | `li a7, 64`        | `addi x17, x0, 0x40`         | `93080004` |
| `13051000` | `li a0, 1`         | `addi x10, x0, 0x1`          | `0545`     |
| `b7050100` | `lui a1, 0x10`     | `lui x11, 0x10`              | `c165`     |
| `9385c509` | `addi a1, a1, 156` | `addi x11, x11, 0x9c`        | TBD        |
| `1306a000` | `li a2, 10`        | `addi x12, x0, 0xa`          | `2946`     |
| `73000000` | `ecall`            | `ecall`                      | `73000000` |
| `9308d005` | `li a7, 93`        | `addi x17, x0, 0x5d`         | `9308d005` |
| `13050000` | `li a0, 0`         | `addi x10, x0, 0x0`          | `0145`     |
| `73000000` | `ecall`            | `ecall`                      | `73000000` |

Lastly, the new memory address.

A total of 8 bytes were shaved off by switching over to the C version of instructions, so subtract 8 from the number - the result is 148 (0x94 in hex). Unfortunately, far too large to fit within the 6 bytes available for the C.ADDI instruction. Subtracting 2 more, which could be done if it could be written as a C.ADDI instruction, still isn't enough. Now, time to determine its new value.

0x94 in binary is `1001 0100`, so imm[11:0] would be `000010010100`.

| imm[11:0]      | rs1     | funct3 | rd      | opcode    |
|----------------|---------|--------|---------|-----------|
| `000010010100` | `01011` | `000`  | `01011` | `0010011` |

The result is `09458593`, which, adjusting for little-endianness, results in `93854509`

Thus, the final version of the code section would be

| asm                 | C hex      |
|---------------------|------------|
| `li a7, 64`         | `93080004` |
| `li a0, 1`          | `0545`     |
| `lui a1, 0x10`      | `c165`     |
| `addi a1, a1, 0x94` | `93854509` |
| `li a2, 10`         | `2946`     |
| `ecall`             | `73000000` |
| `li a7, 93`         | `9308d005` |
| `li a0, 0`          | `0145`     |
| `ecall`             | `73000000` |

`93080004 0545 c165 93854509 2946 73000000 9308d005 0145 73000000`
