# `i386`/`amd64` possible savings

This document makes extensive reference to [Intel® 64 and IA-32 Architectures Software Developer’s Manual Combined Volumes: 1, 2A, 2B, 2C, 2D, 3A, 3B, 3C, 3D, and 4, version 82](https://www.intel.com/content/www/us/en/content-details/812392/intel-64-and-ia-32-architectures-software-developer-s-manual-combined-volumes-1-2a-2b-2c-2d-3a-3b-3c-3d-and-4.html). Its title is indicative of how engaging and brief it is.

## Instructions Used (original version)

* `amd64`:

| hex          | meaning            |
|--------------|--------------------|
| `b801000000` | `mov eax, 1`       |
| `bf01000000` | `mov edi, 1`       |
| `be97000100` | `mov esi, 0x10097` |
| `ba0a000000` | `mov edx, 0xa`     |
| `0f05`       | `syscall`          |
| `b83c000000` | `mov eax, 0x3c`    |
| `31ff`       | `xor edi, edi`     |
| `0f05`       | `syscall`          |

* `i386`:

| hex          | meaning            |
|--------------|--------------------|
| `b804000000` | `mov eax, 4`       |
| `bb01000000` | `mov ebx, 1`       |
| `b973000200` | `mov ecx, 0x20073` |
| `ba0a000000` | `mov edx, 0xa`     |
| `cd80`       | `int 0x80`         |
| `b801000000` | `mov eax, 1`       |
| `31db`       | `xor ebx, ebx`     |
| `cd80`       | `int 0x80`         |

## Possible savings to consider

### `INC` instruction`

The reason I used `xor edi, edi` is because it is 3 bytes shorter. It occured that there's probably an instruction to increment a register by one, which, depending on length, might shave off another byte or two.

Looking into it, I can save one byte with the `xor eax, eax; inc eax` approach for `amd64`. Because the `write` syscall number is different for `i386`, that doesn't work there.

### Addressing mode

x86_64 uses different addressing modes for backwards compatibility with older x64 architecture versions. I currently use the 32-bit registers even in the `amd64` version, It's possible that I can save bytes by using the 16-bit or even 8-bit equivalents instead.

### Initial register states

If the kernel sets the registers when starting a process, I can `inc`rement `eax` and `edi` for `amd64`, instead of needing to `mov`, or `xor` then `inc`.

From what I've found, the kernel does set things that way, but does not guarentee that it will continue to do so - see [arch/x86/include/asm/elf.h (line 98) in Linux v6.8 source](https://elixir.bootlin.com/linux/v6.8/source/arch/x86/include/asm/elf.h#L98).

I'm of two minds about this - there's no official policy that it will continue to work that way, but the (in)famous "don't break userspace" rule means that it's not going to change anyway.

For now, I'll avoid assuming anything about initial register states, though I might revisit that in the future.

### push-pop trickery for setting low values

*from [Assembly code size optimization tricks](https://dev.to/bartosz/assembly-code-size-optimization-tricks-2abd) by Bartosz Wójcik on DEV community*

`push`ing a 1-byte value to the stack, and `pop`ing it, takes only 3 bytes, at least according to the mentioned article.

### Use known register values

For the `amd64` version, I set 2 registers in a row to the same value as each other. Why not copy one register into the other instead?

### Load Effective Address

As mentioned in [issue #13](/eliminmax/tiny-clear-elf/issues/13), program-counter relative addressing could save bytes in some architectures.

From what I can tell, the `lea` (Load Effective Address) instruction could enable that on x86 architectures, though it actually uses 1 more byte than a 32-bit `mov`, so that's not an option.

## Improvements to use for new versions

### `amd64` improvements

#### replace `mov eax, 1` with `xor eax, eax; inc eax`

##### looking at `xor` more closely

From Appendix B - Instruction Formats and Encodings, the register1 xor register2 encoding of `xor` in non-64-bit modes, (but usable in 64-bit modes as well), is on page 2885 of the manual PDF, as part of table B-13, a behemoth of a table split across 11 pages.

```
0011 000w: 11 reg1 reg2
```

Table B.1, found on page 2870 of the manual PDF, explains that `w` is a bit "Specifies if data is byte or full-sized, where full-sized is 16 or 32 bits (see Table B-6)."

Table B.6 is found on page 2872, and explains that "the current operand-size attribute determines whether the processor is performing 16-bit, 32-bit, or 64-bit operations…" I'm too tired for this. I'll just see what works, and if that comes back to bite me, so be it.

`reg1` and `reg2` are the 3-bit encodings of the registers to use, and table B-3, on page 2872 of the PDF, explains what it means when the `w` field is present in the instruction. It turns out that if I want to target `eax` instead of `ax`, I set `w` to 1. Guess I don't need to just see what works after all.

The existing `xor` instruction, then, can be examined against that.

`31ff` in hex is `0011 0001 1111 1111` in binary.

| `0011 000` | `w` | `11` | `reg1` | `reg2` | `hex`  |
|------------|-----|------|--------|--------|--------|
| `0011 000` | `1` | `11` | `111`  | `111`  | `31ff` |

From Table B-3, I can see that if `w` is set to 1 during 32-bit data operations, `111` refers to the EDI register. That checks out.

##### looking at `inc` more closely

Within table B-13, on page 2878 of the PDF, there are 2 encodings offered for `inc`rementing a register.

The first encoding:

```
1111 111w 11 000 reg
```

The second encoding:

```
0100 0 reg
```

From table B-2, when the `w` field is not present, for non-64-bit mode instructions, `000` would be the encoding to use for `eax`.

Unfortunately, unlike most x86 instructions, the second encoding is not usable in 64-bit mode, so for `amd64`, I only can use the first encoding, costing me a whole byte of precious storage out of my 1430500933632-byte partition.

But seriously, `inc eax` in the first encoding would be as follows:

| `1111 111` | `w` | `11 000` | `reg` | `hex`  |
|------------|-----|----------|-------|--------|
| `1111 111` | `1` | `11 000` | `000` | `ffc0` |

##### `xor eax, eax; inc eax`

Bringing it together, figuring out the should be as simple as zeroing out the last 6 bits from the existing `xor` instruction.

Using a Python REPL for a quick and dirty calculation:

```python
hex(0xff ^ 0b111111)
```

The result is `0xc0`.

So the new instruction would be `31c0`

For the sake of completeness, the table for the new instruction is as follows:

| `0011 000` | `w` | `11` | `reg1` | `reg2` | `hex`  |
|------------|-----|------|--------|--------|--------|
| `0011 000` | `1` | `11` | `000`  | `000`  | `31c0` |

For the `inc` operation, it's the one I showed earlier:


| `1111 111` | `w` | `11 000` | `reg` | `hex`  |
|------------|-----|----------|-------|--------|
| `1111 111` | `1` | `11 000` | `000` | `ffc0` |

So I can replace `mov eax, 1` with `xor eax, eax; inc eax` for a whopping 1-byte saving.

#### `replace xor eax, eax; inc eax` with `push 1; pop rax`

I know I just replaced it, but there's a possible 1-byte saving here.

##### looking at `push` more closely

From page 2881, `push`ing an immediate takes the following form:

```
0110 10s0 : immediate data
```

Per Table B-1 on page 2870, `s` indicates sign extension. Per Table B-7 on page 2872, if set to 1, an 8-bit immediate is sign-extended. Otherwise, it has no effect. That said, according to the documentation on `push` on page 1736 of the PDF, the opcode to push an 8-bit immediate is `6A ib`, where `ib` is the byte value, and `68 iw` (`iw` being a 16-bit value) is used for 16-bit immediates. Given that `a` in hex is `1010` in binary, I take it that it should be set for 8-bit immediates.

So to push `1` to the stack, the following would be used:

| `0110 10` | `s` | `0` | `immediate data` | `hex`  |
|-----------|-----|-----|------------------|--------|
| `0110 10` | `1` | `0` | `0000 0001`      | `6a01` |

##### looking at `pop` more cloesly

From page 1612, the `pop` instruction to pop a 32-bit register in 32-bit mode is the same as a 64-bit register in 64-bit mode - `58` + `rd` - meaning you add the hex value `58` to the 3-bit register identifier.

Page 2881 details that the alternate encoding takes the following form:

```
0101 1 reg
```

So to `pop` the stack into `eax`, the following would be used:

| `0101 1` | `reg` | `hex` |
|----------|-------|-------|
| `0101 1` | `000` | `58`  |

##### `push 1; pop rax`

The resulting hex would be `6a0158`

#### replace `mov edi, 1` with `mov edi, eax`

While it has the same mnemonic, the encoding is different, and much shorter.

(Page 2979 of the PDF)

To copy register1 to register2:

```
1000 100w : 11 reg1 reg2
```

To copy register2 to register1:

```
1000 101w : 11 reg1 reg2
```

Why would you do that, Intel? Have an alternate encoding that does not have any clear purpose like that.

I assume that the GNU assembler will only do one of those, so if I assemble a file containing the following, whichever it uses, I'll use, to make the reassembly instructions work.

```sh
printf 'mov %%edx, %%eax\n' > mov.s # printf treats % as special, but %% as a literal '%' character, and % is needed for the assembly syntax that the GNU assembler uses.
as mov.s -o mov.o # assemble that instruction
objdump -d mov.o # disassemble mov.o
```

The result:

```

/tmp/tmp.nhtRj56AL4/mov.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <.text>:
   0:	89 d0                	mov    %edx,%eax
```

Okay, so `89` in hex is `1000 1001`, meaning that the 7th bit from the right is `0`, so the first encoding is in use.

So `mov edi, eax` would be as follows:

| `1000 100` | `w` | `11` | `reg1`      | `reg2`      | hex    |
|------------|-----|------|-------------|-------------|--------|
| `1000 100` | `1` | `11` | `eax`=`000` | `edi`=`111` | `89c7` |

#### replace `mov edx, 0xa` with `push 0xa; pop rdx`

| `0110 10` | `s` | `0` | `immediate data` | `0101 1` | `reg` | `hex`    |
|-----------|-----|-----|------------------|----------|-------|----------|
| `0110 10` | `1` | `0` | `0000 1010`      | `0101 1` | `010` | `6a0a5a` |

#### replace `mov eax, 0x3c` with `push 0x3c; pop rax`

| `0110 10` | `s` | `0` | `immediate data` | `0101 1` | `reg` | `hex`    |
|-----------|-----|-----|------------------|----------|-------|----------|
| `0110 10` | `1` | `0` | `0011 1100`      | `0101 1` | `000` | `6a3c58` |

#### replace `mov esi, 0x10097` with `mov esi, 0x1008e`

This does not save any bytes, but it changes the value to account for the new memory address of the data to write.

From page 2879:

```
1011 w reg : immediate data
```

| `1011` | `w` | `reg` | `immediate data`                          | `hex`        |
|--------|-----|-------|-------------------------------------------|--------------|
| `1011` | `1` | `110` | `1000 1110 0000 0000 0000 0001 0000 0000` | `be8e000100` |

### `i386` improvements

I'll be using the same `pop`/`push` approach, but not the register-to-register `mov`, as the syscall number is different.

Because the shorter `inc` instruction encoding is available, I could use the `xor reg, reg; inc reg` approach and not lose any bytes, but I wouldn't gain any bytes either, so I decided not to bother.

#### replace `mov eax, 4` with `push 0x4; pop eax`

| `0110 10` | `s` | `0` | `immediate data` | `0101 1` | `reg` | `hex`    |
|-----------|-----|-----|------------------|----------|-------|----------|
| `0110 10` | `1` | `0` | `0000 0100`      | `0101 1` | `000` | `6a0458` |

#### replace `mov ebx, 1` with `push 0x1; pop ebx`

| `0110 10` | `s` | `0` | `immediate data` | `0101 1` | `reg` | `hex`    |
|-----------|-----|-----|------------------|----------|-------|----------|
| `0110 10` | `1` | `0` | `0000 0001`      | `0101 1` | `011` | `6a015b` |

#### replace `mov edx, 0xa` with `push 0xa; pop edx`

| `0110 10` | `s` | `0` | `immediate data` | `0101 1` | `reg` | `hex`    |
|-----------|-----|-----|------------------|----------|-------|----------|
| `0110 10` | `1` | `0` | `0000 1010`      | `0101 1` | `010` | `6a0a5a` |

#### replace `mov eax, 1` with `push 0x1; pop eax`

| `0110 10` | `s` | `0` | `immediate data` | `0101 1` | `reg` | `hex`    |
|-----------|-----|-----|------------------|----------|-------|----------|
| `0110 10` | `1` | `0` | `0000 0001`      | `0101 1` | `000` | `6a0158` |

#### replace `mov ecx, 0x20073` with `mov ecx, 0x2006e`

This does not save any bytes, but it changes the value to account for the new memory address of the data to write.

From page 2879:

```
1011 w reg : immediate data
```

| `1011` | `w` | `reg` | `immediate data`                          | `hex`        |
|--------|-----|-------|-------------------------------------------|--------------|
| `1011` | `1` | `001` | `0110 1011 0000 0000 0000 0010 0000 0000` | `b96b000200` |

## The result

* `amd64`:

| original hex | original instruction | new instruction(s)   | new hex      |
|--------------|----------------------|----------------------|--------------|
| `b801000000` | `mov eax, 1`         | `push 0x1; pop rax`  | `6a0158`     |
| `bf01000000` | `mov edi, 1`         | `mov edi, eax`       | `89c7`       |
| `be97000100` | `mov esi, 0x10097`   | `mov esi, 0x1008e`   | `be8e000100` |
| `ba0a000000` | `mov edx, 0xa`       | `push 0xa; pop rdx`  | `6a0a5a`     |
| `0f05`       | `syscall`            | `syscall`            | `0f05`       |
| `b83c000000` | `mov eax, 0x3c`      | `push 0x3c; pop rax` | `6a3c58`     |
| `31ff`       | `xor edi, edi`       | `xor edi, edi`       | `31ff`       |
| `0f05`       | `syscall`            | `syscall`            | `0f05`       |

* `i386`:

| original hex | original instruction | new instruction(s)  | new hex      |
|--------------|----------------------|---------------------|--------------|
| `b804000000` | `mov eax, 4`         | `push 0x4; pop eax` | `6a0458`     |
| `bb01000000` | `mov ebx, 1`         | `push 0x1; pop ebx` | `6a015b`     |
| `b973000200` | `mov ecx, 0x20073`   | `mov ecx, 0x2006b`  | `b96b000200` |
| `ba0a000000` | `mov edx, 0xa`       | `push 0xa; pop edx` | `6a0a5a`     |
| `cd80`       | `int 0x80`           | `int 0x80`          | `cd80`       |
| `b801000000` | `mov eax, 1`         | `push 0x1; pop eax` | `6a0158`     |
| `31db`       | `xor ebx, ebx`       | `xor ebx, ebx`      | `31db`       |
| `cd80`       | `int 0x80`           | `int 0x80`          | `cd80`       |
