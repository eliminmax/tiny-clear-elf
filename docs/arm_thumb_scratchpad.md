  # Existing armhf/armel version

`7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00 02 00 28 00 01 00 00 00 54 00 02 00 34 00 00 00 00 00 00 00 00 00 00 00 34 00 20 00 01 00 00 00 00 00 00 00`

`01 00 00 00 00 00 00 00 00 00 02 00 00 00 00 00 82 00 00 00 82 00 00 00 05 00 00 00 02 00 00 00`

`04 70 a0 e3 01 00 a0 e3 78 10 00 e3 02 10 40 e3 0a 20 a0 e3 00 00 00 ef 01 70 a0 e3 00 00 a0 e3 00 00 00 ef`

`1b 5b 48 1b 5b 4a 1b 5b 33 4a`

* first 52 bytes are ehdr
* next 32 bytes are phdr
* last 10 bytes are text

actual cpu operations are as follows:

| hex        | bin                                   | asm             |
|------------|---------------------------------------|-----------------|
| `0470a0e3` | `00000100 01110000 10100000 11100011` | `mov r7, 4`     |
| `0100a0e3` | `00000001 00000000 10100000 11100011` | `mov r0, 1`     |
| `781000e3` | `01111000 00010000 00000000 11100011` | `movw r1, 0x78` |
| `021040e3` | `00000010 00010000 01000000 11100011` | `movt r1, 2`    |
| `0a20a0e3` | `00001010 00100000 10100000 11100011` | `mov r2, 0xa`   |
| `000000ef` | `00000000 00000000 00000000 11101111` | `svc 0`         |
| `0170a0e3` | `00000001 01110000 10100000 11100011` | `mov r7, 1`     |
| `0000a0e3` | `00000000 00000000 10100000 11100011` | `mov r0, 0`     |
| `000000ef` | `00000000 00000000 00000000 11101111` | `svc 0`         |

## ARM instruction encoding

Info from ARM Architecture Reference Manual ARMv7-A and ARMv7-R edition
(downloadable from [this web page](https://developer.arm.com/documentation/ddi0406/cd/?lang=en))

From page A5-192:

| 31..28 | 27..5 | 24..5 | 4  | 3..0 |
|--------|-------|-------|----|------|
| cond   | op1   |       | op |      |

* if the cond field is `0b1111`, then it's executed unnconditionally
* if it's not `0b1111`, then its behavior depends on `op1`, and possibly `op`. How exactly it's interpreded is documented below the table I copied into here

### Example:

`mov r7, 4`

The instruction is `0470a0e3`

Because of bit-orderning and endian-ness, the bits of the instruction are processed in the opposite of what I think is the more intuative order for humans.

I came up with a rather complex Python 1-liner to print the bits in an order that matches the ARM documentation:

```python
print("".join([bin(b)[2:].rjust(8, "0") for b in bytes.fromhex("0470a0e3")[::-1]]))
```

the result is the following:

`11100011101000000111000000000100`

putting that into the instruction set encoding table from page A5-192:

| cond        | op1   | 24..5                  | op  | 3..0   |
|-------------|-------|------------------------|-----|--------|
| `1110`      | `001` | `11010000001110000000` | `0` | `0100` |

Going through the list of instructions

* given that cond is not `1111`, according to page A5-192, it's a "Data-processing and miscellaneous instruction", documented on page A5-192

* on page A5-194, it says that if it's a "Data-processing and miscellaneous instructon", and the 25th bit is a 1, and bytes 24-20 are not 10xx0, it's a "Data-processing (immediate)" instruction, documented on page A5-197

* on page A5-197, it says that if bytes 24-20 are 1101x, it's a MOV (immediate), documented on page A8-485

MOV (immediate) instructions, as documented on page A8-485, are structured a few different ways.

For this instruction, it's the A1 encoding, meaning it's as follows.

| cond   | 00   | 1   | 1101   | S   | (0)(0)(0)(0) | Rd     | imm12          |
|--------|------|-----|--------|-----|--------------|--------|----------------|
| `1110` | `00` | `1` | `1101` | `0` | `0000`       | `0111` | `000000000100` |


* if cond is `1110`, according to page A8-286, the instruction runs unconditionally
* fields where the field is identified as a sequence of bits all must be set to those exact bits for the CPU to recognize the instruction properly.
* bits identified as `(0)`, if not set to 0, result in "UNPREDICTABLE BEHAVIOR" according to page A5-193, and should be avoided as a result.
* if S is set to 1, then the flags used for comparisons are updated. Given that it's set to 0, it does not do that.
* Rd is the register to move the immediate into. In this case, it's r7, so 7 is used as the value
* imm12 is a "modified immediate", described on pages A5-197 through A5-198. The first 4 bits are used to "rotate" the remaining bits. All that's relevant here is that if it's set to `0000`, the remaining 8 bits are used unmodified.

# Thumb Instructions

Thumb instructions can be used, but not freely mixed with normal ARM instructions. The original Thumb instructions were purely 16-bit instructions, but Thumbv2 mixes 16-bit and 32-bit instructions. If the goal is to minimize the size of the binary, Thumb instructions are incredibly valuable.

## Thumb instruction encoding

I'm not going to be as thorough as I was with an example for the normal ARM instruction. Each instruction in the book lists all valid encodings for that instruction. If it's T followed by a number, it's a Thumb instruction. If it's A followed by a number, it's a normal ARM instruction. Wherever I could, I just looked up the instruction I'd already used, looked at the info about that instruction, and found a Thumb encoding to use.

### 16-bit instructions

From page A6-221:

| 15..10 | 9..0 |
|--------|------|
| opcode |      |

### 32-bit instructions

From page A6-228:

| 15..13 | 12 11 | 10..4 | 3..0 | 15 | 14..0 |
|--------|-------|-------|------|----|-------|
| `111`  | op1   | op2   |      | op |       |

## Translating instructions from ARM to Thumb

Not all Thumb instructions are supported in older versions of ARM still supported as part of the Debian armel architecture, so there may be a difference moving forwards.

| asm               | old hex    | new hex (armhf) | new hex (armel) |
|-------------------|------------|-----------------|-----------------|
| `mov r7, 4`       | `0470a0e3` | `0427`          | `0427`          |
| `mov r0, 1`       | `0100a0e3` | `0120`          | `0120`          |
| `movw r1, 0x78`\* | `781000e3` | `NN21`          | `____`          |
| `movt r1, 2`\*    | `021040e3` | `c0f20201`      | `____`          |
| `mov r2, 0xa`     | `0a20a0e3` | `0a22`          | `0a22`          |
| `svc 0`           | `000000ef` | `00df`          | `00df`          |
| `mov r7, 1`       | `0170a0e3` | `0127`          | `0127`          |
| `mov r0, 0`       | `0000a0e3` | `0020`          | `0020`          |
| `svc 0`           | `000000ef` | `00df`          | `00df`          |

## MOV (immediate)

\* the immediate used would change if the program length changes

T1 encoding of mov Rd, imm8:

| 15..13 | 12 11 | 10..8 | 7..0 |
|--------|-------|-------|------|
| `001`  | `00`  | Rd    | imm8 |

The following instructions can be rewritten as T1-encoding MOV (immediate) instructions:

| instruction   | 15..13 | 12 11 | 10..8 | 7..0       | hex    |
|---------------|--------|-------|-------|------------|--------|
| `mov r7, 4`   | `001`  | `00`  | `111` | `00000100` | `0427` |
| `mov r0, 1`   | `001`  | `00`  | `000` | `00000001` | `0120` |
| `mov r2, 0xa` | `001`  | `00`  | `010` | `00001010` | `0a22` |
| `mov r7, 1`   | `001`  | `00`  | `111` | `00000001` | `0127` |
| `mov r0, 0`   | `001`  | `00`  | `000` | `00000000` | `0020` |

Note that this does set the comparison flags, so it's not identical to the old instructions, but it isn't different in a manner that matters for such a simple binary.

## SVC

In the case of `svc`, the T1 encoding (found on page A8-721) for SVC is as follows:

| 15..12 | 11..8  | 7..0 |
|--------|--------|------|
| `1101` | `1111` | imm8 |

So, for `svc 0`, it would be `1101111100000000`. Given the byte-ordering, that becomes `00df` in hex.

Now, `movw r1, 0x78` and `movt r1, 2` are complicated, and I saved them for last for 2 reasons:

1. They are setting the r2 to the memory address of the escape sequences to write, which changes if the instruction length changes.
2. The instructions were added as part of a newer version of ARM, and are not allowed as part of the armel architecture, so another way to get the same effect is needed for armel.

### MOVW and MOVT

MOVW and MOVT are used together to set a register to a 32-bit value.
Technically, MOVW is a variant of the MOV instruction, but MOVT is its own thing.
Both of them have Thumb encodings added in ARMv6T2, but for the armel Debian architecture, another solution is needed.

#### MOVT on armhf

According to page A8-492 of the book, the T1 form of MOVT (imm16) is as follows:

| 15..11  | 10 | 9 8  | 7   | 6   | 5   | 4   | 3..0 | 15  | 14..12 | 11..8 | 7..0 |
|---------|----|------|-----|-----|-----|-----|------|-----|--------|-------|------|
| `11110` | i  | `10` | `1` | `1` | `0` | `0` | imm4 | `0` | imm3   | Rd    | imm8 |

The 16-bit immediate is split into several parts.
To get it, concatenate imm4, i, imm3, and imm8 in that order.
It has "UNPREDICTABLE" behavior if the target register is 13, 14, or 15.

So, for the `movt r1, 2` instruction, it would be as follows:

| `11110` | i   | `10` | `1` | `1` | `0` | `0` | imm4   | 0   | imm3  | Rd    | imm8       | hex        |
|---------|-----|------|-----|-----|-----|-----|--------|-----|-------|-------|------------|------------|
| `11110` | `0` | `10` | `1` | `1` | `0` | `0` | `0000` | `0` | `000` | `001` | `00000010` | `c0f20201` |

#### MOVT on armel

MOVT is newer than armel's minimum hardware requirements, so it should not have been included at all in armel. I guess I technically failed to meed the original program requirements.

#### MOVW

Thankfully, in the case of MOVW, the solution is simply using MOV instead of MOVW. Using the same process as before, we can figure out the `mov r1, 0xNN` instruction, where `0xNN` is the offset (in bytes) from the start of the file to the first byte of the escape sequence to print, and `nnnnnnnn` is the binary representation of that value.

| instruction    | 15..13 | 12 11 | 10..8 | 7..0       | hex    |
|----------------|--------|-------|-------|------------|--------|
| `mov r1, 0xNN` | `001`  | `00`  | `001` | `nnnnnnnn` | `NN21` |

## Bringing it all together

### armhf

From what I've written, I should have the new Thumb instructions for armhf almost figured out. I just need to update the offset and I should be good to go.

Given that I've shaved 16 bytes off of the binary, the new offset will be 0x78 - 0x10. In other words, it's 68.

The new machine instructions are as follows:

`04 27 01 20 68 21 c0 f2 02 01 0a 22 00 df 01 27 00 20 00 df`

For comparison, again, here are the old ones:

`04 70 a0 e3 01 00 a0 e3 78 10 00 e3 02 10 40 e3 0a 20 a0 e3 00 00 00 ef 01 70 a0 e3 00 00 a0 e3 00 00 00 ef`

Now, the last step is to update the ELF header and Program Header table entry.

For the former, there is only one change to make, and it has to do with a quirk of ARM ELF files.
According to the official ARM ELF Specification (downloadable from [this web page](https://developer.arm.com/documentation/espc0003/1-0/?lang=en)), if bit 0 of a function address is set to one, because all addresses must be even numbers, then starts with the instruction at the previous byte address in Thumb mode. Using this for the `e_ehdr` value saves the 4 bytes it would take to switch to Thumb mode using an instruction.

Lastly, the `p_filesz` and `p_memsz` values need to be adjusted to reflect the new file size.


# Potential Further Improvement

`ADR` (documented on page A8-314 of the ARM Architecture Reference Manual) adds an immediate to the value of the `PC` (program counter) register, and puts it in a specified register. It has a 4-byte thumb representation that is old enough to be suitable for the `armel`, and is relative to the current point in the program, so I just need to figure out the offset from the `pc` to the escape sequence bytes.

| 15..12 | 11  | 10..8 | 7..0 |
|--------|-----|-------|------|
| `1010` | `0` | Rd    | imm8 |

* Rd is the destination register
* imm8 concatenated with `00` is the offset from the program counter

working from the `armhf` version:

* at the time it reaches the instruction address where this instruction would be, `pc` is set to `0x020058` (in a radare2 simulation).
* the current escape sequence start address is `0x020068`.
* if I replace the `movw`, `movt` combo with `adr`, it would shave off 4 bytes, moving it to `0x020064`.
* `0x020064` - `0x020058` = `0x0c`

| `1010` | `0` | Rd    | imm8       | hex    |
|--------|-----|-------|------------|--------|
| `1010` | `0` | `001` | `00000010` | `02a1` |

Based on a radare2 simulation, that did not work as expected. I was worried about the exact order of operations, and it turns out that it skips the first 4 bytes of the escape sequence data, presumably because `adr` is incremented first. I need to change from 12 to 8, and that should work.

After updating `p_filesz` and `p_memsz`, I can now bring the `armel` and `armhf` binaries back in sync, having fixed the invalid instruction issue in the `armel` version and shaving 20 bytes off of the binary.
