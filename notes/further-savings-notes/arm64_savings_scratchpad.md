# Potential savings for `arm64`

This document makes reference to the Arm Architecture Reference Manual for A-profile architecture, version J.a, downloadable from [this web page](https://developer.arm.com/documentation/ddi0487/ja/).

## Instructions Used (original version)

| hex        | meaning           |
|------------|-------------------|
| `08088052` | `mov w8, 0x40`    |
| `200080d2` | `mov x0, 1`       |
| `2100a0d2` | `mov x1, 0x10000` |
| `811380f2` | `movk x1, 0x9c`   |
| `420180d2` | `mov x2, 0xa`     |
| `010000d4` | `svc 0`           |
| `a80b8052` | `mov w8, 0x5d`    |
| `000080d2` | `mov x0, 0`       |
| `010000d4` | `svc 0`           |

I believe that I can replace the `mov x1, 0x10000; movk x1, 0x9c` pair of instructions with a single instruction.

Page 1269 of the PDF describes the `ADR` instruction, to add an immediate to the program counter register (PC), saving the result to a register.

It takes the following form:

| 31  | 30 29   | 28 .. 24    | 23 .. 5 | 4 .. 0 |
|-----|---------|-------------|---------|--------|
| `0` | `immlo` | `1 0 0 0 0` | `immhi` | `Rd`   |

it concatenates `immhi`:`immlo`, then sign extends that to 64 bits, adds the result to the program counter, then writes that to the register Rd.

So, because it saves me a 4 byte instruction, I need to set `x1` to `0x10098` instead of `0x1009c`.

When it runs, `pc` will be set to `0x10080`, so I want to set the imm to `0x18` (`0 0000 0000 0000 0001 1000` in binary).

`immlo` should be the lowest 2 bits, the rest are `immhi`

Thus:

| `0` | `immlo` | `1 0 0 0 0` | `immhi`               | `Rd`    |
|-----|---------|-------------|-----------------------|---------|
| `0` | `00`    | `10000`     | `0000000000000000110` | `00001` |

| bin         | hex  |
|-------------|------|
| `0001 0000` | `10` |
| `0000 0000` | `00` |
| `0000 0000` | `00` |
| `1100 0001` | `c1` |

Accounting for endian-ness, the instruction is `c1000010`.
