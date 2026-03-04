This file is written as a stream-of-conciousness, to help me organize my approach to the LoongArch ISA, as I re-familiarize myself with this project after a year. Expect little-to-no proofreeding, and notes that may jump around or be incoherently organized.

* The Linux Kernel Docs for LoongArch are at https://docs.kernel.org/arch/loongarch/introduction.html.
* That page has links to the ISA and psABI docs.
* Debian documents the port at https://wiki.debian.org/Ports/loong64

Instructions are fixed size, with 32 bits per instruction. Between that and its open MIPS influence, I expect it will be the same size as the mips64el implementation.

write system call number is 64
exit system call number is 93

LoongArch has 32 General-Purpose registers. Register $r0 is always zero. Registers $r4 through $r11 are aliased as $a0 through $a7, and are used for arguments. Per `man syscall(2)`, loongarch takes the syscall number in $a7 and the arguments in $a0 through $a6, and uses `syscall 0` as the syscall instruction

The steps are as follows:

1. store 64 in $a7
2. store the STDOUT file descriptor in $a0
3. store address of output in $a1
4. store 10 in $a2
5. call syscall 0
6. store 93 in $a7
7. store 0 in $a0
8. call syscall 0

Working from the assumption that each step takes 1 instruction, and binary is mmaped at 0x10000, as it is with the other 64-bit implementations: Given that STDOUT's file descriptor is always 1, the instructions should be as follows:

1. store 64 in $r11
2. store 1 in $r4
3. store address of output in $r5
4. store 10 in $r6
5. call syscall 0
6. store 93 in $r11
7. store 0 in $r4
8. call syscall 0

The `addi.w rd, rj, si12` instruction adds a 12-bit sign-extended immediate to the lower 32 bits of `rj`, sign extends that to 64 bits, and stores it in `rd`. It should be the only instruction I need other than `syscall 0`

The memory address of the output buffer will be 0x10000 + 64 [ehdr length] + 56 [phdr length] + (4 * 8) [length of 8 instructions]. That evaluates to 0x10098 (65688 in decimal)

Knowing that $r0 is always set to zero, and looking at the list of instructions in the ISA docs, the instructions to use are:

```
addi.w $r11, $r0, 64
addi.w $r4,  $r0, 1
addi.w $r5,  $r0, 0x10098
addi.w $r6,  $r0, 10
syscall 0
addi.w $r11, $r0, 93
addi.w 0,    $r0, 0
syscall 0
```

Looking at section 1.3 of the ISA docs, the `.w` suffix means that it's the signed word variant of `addi`.

Looking at back up at section 1.2, there are a number of common instruction formats listed, but the one that matches `addi` is `2RI12-type`, which I presume is "2 registers and i12", and not a keysmash, given that that's the parameters it takes.
The only format for instructions with only an immediate parameter is "I26-type", which takes a 26-bit immediate.

The encodings are listed from bit 31 down to bit 0.

The 2RI12 encoding uses bits 31 through 22 for the opcode, bits 21 through 10 for the immediate, bits 9 through 5 for rj, and bits 4 through 0 for rd.

wait... the immediate 0x10098 is way too long for 12 bits. dammit.

What if I were to change the start address ensure that it's aligned such that I can make it work?

The `addu16i`.w instruction left-shifts a 16-bit immediate by 16, sign extends, then adds the result to rj and stores it in rd. If the start address were at 0x400 instead of 0x10000, then it could fit in 12 bits. Unfortunately, the first 64 KiB of memory address space is forbidden by default on Linux, to make NULL pointer dereferences likely to crash - something I didn't know when I started this project 4 years ago. I only learned that when watching [Stackmaxxing for a recursion world record](https://www.youtube.com/watch?v=WQKSyPYF0-Y&t=941s), which brings it up at the linked timestamp (15:41). It went on to note that one can disable the restriction by writing '0' to /proc/sys/vm/mmap_min_addr, but I'd rather not deal with that, as it would mean that the tiny-clear-elf binary would need to be run on a system with a non-default and potentially risky configuration.

Looking back at the mips64el `clear`, it looks like I had used 9 instructions, with 2 to construct the address.

That said, if I were to use relative addressing, I might be able to do that. The English translation manual is quite a bit hard to understand, but it seems like the `PCADDI` instruction might be the way to go.

As far as I can tell, it takes a 20-bit immediate, left-shifts it by 2, and adds it to the `PC` of the current instruction.

If I move it to the 1st instruction, it'll be exactly 0x20 bytes before the address of the data. By my understanding, `PC` + `0` would be the address of the current address in memory, and `0x20 >> 2` is `8`, so if the 1st instruction is `pcaddi $r5, 8`, it should store the address `0x10098` in the correct register. Alternatively, keep the order consistent with the original plan, and simply subtract 1 from the immediate value. I think I'll go with that.

```
addi.w $r11, $r0, 64        ; PC: 0x10078
pcaddi $r5,    7            ; PC: 0x1007c
addi.w $r4,  $r0, 1         ; PC: 0x10080
addi.w $r6,  $r0, 10
syscall 0
addi.w $r11, $r0, 93
addi.w $r5,  $r0, 0
syscall 0
```

Now, to figure out the actual encoding.

Using `PCADDI` adds a 3rd encoding to worry about, in addition to `2RI12-type` and `I26-type` as mentioned above, there's whatever encodding `pcaddi` uses - none of the encodings listed in the common encoding table mentioned above fit it.

Looking at Appendix B: Table of Instruction Encoding:

`ADDI.W`:

* bits 31 through 22 are the 10-bit sequence `0000001010`
* bits 21 through 10 are the immediate
* bits 09 through 05 are the source register
* bits 04 through 00 are the destination register

`PCADDI`:

* bits 31 through 25 are the 7-bit sequence `0001100`
* bits 24 through 05 are the immediate
* bits 04 through 00 are the destination register

`SYSCALL`:
* bits 31 through 15 are the 17-bit sequence `00000000001010110`
* bits 15 through 00 are the code


looking first at syscall, the encoding is simple: `00000000001010110000000000000000`

Because the bits are ordered from 31 to 00, I wasn't quite sure how to convert that to hex, so I first pasted it into a python fstring: 

```python
print(f"{0b00000000001010110000000000000000:08x}")
```

The result was `002b0000`, which `rasm2` disassembled to `cto.d  zero, s1` - a swing and a miss, I suppose.

Next, I tried reversing the byte order, and `rasm2` reported it as `syscall  0x0` - success!

Now, the issue is that I'm not sure what bit order to encode the immediates in, so I'll try the  `PCADDI` instruction next.

I came up with the following python abomination that belongs nowhere near production code, which I evaluated by using `python3` as a vim filter

```python
print(bytes.fromhex(f'{eval(f"0b0001100{7:020b}{5:05b}"):08x}')[::-1].hex())
```

The result was `e5000018`, which `rasm2` dissassembled to `pcaddi  a1, 0x7` - a success!

---

Coming back 2 days later:

While writing the above, I'd created an ELF file with the appropriate Ehdr, except for the `e_entry` address, which was set to 0x478 due to my plan to try to adjust the start address, before I realized that it was too small.
It then had 72 `NUL` bytes (56 for the Phdr, and what should have been 32 for the instructions, but was missing 16).

I appended the missing bytes and output sequence, then adjusted `e_entry` back to `0x10078`, before moving on to the Phdr.

Looking at `elf.h`, the first 8 bytes will be the same as all other 64-bit implementations, as they're just the type and flags, which will be `PT_LOAD` and `PF_R | PF_X` regardless of architecture, I would think. After that, it's `p_offset` - the byte offset in the file, which is 0, so leave it `NUL`ed out. In fact, the only fields that will differ from the `mips64el` version are `p_filesz` and `p_memsz`, so I copied my previous work.

So all that's left to do is fill in the instruction bytes.

`addi.w $r11, $r0, 64` should become `(0000001010 << 22) | (64 << 10) | 11`, which evaluates to `0x0281000b`. `0b008102` disassembled to `addi.w a7, zero, 0x40`
`addi.w RD, $r0, IMM12`, in general, should become `(0000001010 << 22) | (IMM12 << 10) | RD`

Now, a hexdump of what I have:

```xxd
00000000: 7f45 4c46 0201 0000 0000 0000 0000 0000  .ELF............
00000010: 0200 0201 0100 0000 7800 0100 0000 0000  ........x.......
00000020: 4000 0000 0000 0000 0000 0000 0000 0000  @...............
00000030: 0000 0000 4000 3800 0100 0000 0000 0000  ....@.8.........
00000040: 0100 0000 0500 0000 0000 0000 0000 0000  ................
00000050: 0000 0100 0000 0000 0000 0000 0000 0000  ................
00000060: a600 0000 0000 0000 a600 0000 0000 0000  ................
00000070: 0200 0000 0000 0000 0b00 8102 c500 0018  ................
00000080: 0404 8002 0528 8002 0000 2000 0b74 8102  .....(.... ..t..
00000090: 0400 8002 0000 2b00 1b5b 481b 5b4a 1b5b  ......+..[H.[J.[
000000a0: 334a                                     3J
```

When running, I get an exec format error. The disassembly looks right to me, and I suspect the cause is the lack of `e_flags` - I saw there there was a section in the psABI docs for that, but it list several ABI variations, and I could not find any specific information about which of those Debian uses. I'd decided to skip it for the time being, and start any troubleshooting by looking there.

Looking at the psABI docs again, it states that bits 31 to 08 of `e_flags` are reserved, bits 07-06 are for the ABI version, bits 05-03 are for ABI extensions, and bits 02-00 are for the "Base ABI Modifier".

I decided to first look at the flags in the current Debian 14 `busybox-static` build for the architechture, but [there have been delays in setting that up](https://lists.debian.org/debian-loongarch/2025/11/msg00004.html), so I downloaded the current `sid` build. It has `e_flags` set to hex `43 00 00 00`, and `readelf -h` reports the value of `Flags` as "`0x43, DOUBLE-FLOAT, OBJ-v1`".

There are 6 listed ABI variations in the psABI docs, diffrentiated by the pointer size, and the floating-point registers usedin parameter passing

| Name     | Pointer Size | FPR parameters | value |
|----------|--------------|----------------|-------|
| `lp64s`  | 64           | none           | `0x1` |
| `lp64f`  | 64           | 32-bit floats  | `0x2` |
| `lp64d`  | 64           | 64-bit floats  | `0x3` |
| `ilp64s` | 32           | none           | `0x1` |
| `ilp64f` | 32           | 32-bit floats  | `0x2` |
| `ilp64d` | 32           | 64-bit floats  | `0x3` |

Given that `loong64` is a 64-bit architechture, it'll be one of `lp64[sfd]`, but it's not clear which one.
Bits 05 through 03 are used for ABI extensions, and as of v2.01 of the psABI docs the only defined value is `base`, which is `0x00`.

The defined ABI versions are `v0` and `v1`

If I'm reading it right, then in the `busybox` binary, bits 07-06 are `0x1`, and bits 02-00 are `0x3`, which would map to ABI v1 and `lp64d`, respectively. Reading it the other way around results in a currently-undefined ABI version, so that must be the right way.

Setting the `e_flags` to `0x43` did not fix it. Dammit.

Looking closer, when I "copied my work" for the Phdr, it looks like I forgot to change the `file_sz` and `mem_sz` fields. Fixing that doesn't work. Padding it to a size that's a multiple of 4 didn't work either.

Just to be sure, invoking the BusyBox binary as `uname -m` reports `loongarch64`, so it's not an issue with emulation. Trying to invoke the `clear` binary with `qemu-loongarch64` directly results in a format error. I decided to look at the `binfmt_misc` rule for `qemu-loongarch64`, and manually check if my binary matched the signature it checked for. It was 1 bit off - I'd forgotten to set the OS ABI. Fixing that, it now runs, but appears to do nothing.

Now, looking at the disassembly again, right in the middle, where my eyes glaze over a bit, I'd missed that there was a byte set to `20` instead of `2b`, resulting in `div.w zero, zero, zero` where the first `syscall 0x0` should have been. Either I somehow overlooked that when looking at the disassembly earlier, or I'd fat-fingered that in without noticing. I fixed that, and it still does not work.

Setting the `QEMU_STRACE` environment variable to a non-empty value results in an `strace`-like trace being output to `stderr`. That showed me that it was executing `write(1,0xa,0)` instead of `write(1,0x10098,10)`. I noticed that `$r5` was being overwritten with the length instead of `$r6` being set to the length. That was a simple fix, and now it was executing `write(1,0x10094,10)` - so, so close.

I'd swapped the instructions to set `a1` and `a2` at some point, and later swapped them back. While swapping them back, I'd forgotten to readjust the offset of the PCADDI instruction. Fixing that, I was able to get it working properly.

While working on the architecture-specific README, I realized just why I'd done so - the arguments were set out of order in the arrangement I had gotten working. I swapped the instructions around, and that was that.
