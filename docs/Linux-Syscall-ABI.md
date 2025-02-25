# Linux Syscall ABI
<!-- vim: set et ai nowrap: -->

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
  * [Relevant parts for Tiny Clear Elf](#relevant-parts-for-tiny-clear-elf)
    * [Setting up a syscall](#setting-up-a-syscall)
    * [`write`](#write)
    * [`exit`](#exit)

<!-- vim-markdown-toc -->


# Overview

On every architecture Linux supports, there's a unique way for binaries to switch to kernel mode in order to interface with the kernel and make system calls (syscalls).

When the architecture-specific call is made, the kernel does the following:
  1. read the syscall number from a specific CPU register
  2. read the syscall arguments from a list of CPU registers
  3. run the syscall, and write its return value to a specific CPU register
  4. (only on some architectures) write secondary return code to a specific CPU register, and/or write error code to a specific CPU register.
  5. return to user mode

The specific registers used depend on the CPU architecture.
A pair of tables containing the kernel-mode instrution, register used for each purpose, and any notes about specific exceptions to the rules for several Linux architectures call all be found in the `SYSCALL(2)` man page from the Linux man-pages project.

The set of system calls available on each architecture, and what the syscall number for each of them is, is different on each architecture.

Marcin Juszkiewicz, an AArch64/Arm developer at Red Hat, created a program that generates an HTML table of syscalls, and their numbers on different architectures. The table itself is available [here](https://marcin.juszkiewicz.com.pl/download/tables/syscalls.html), and the tool used to generate it from the Linux source code is available [here](https://github.com/hrw/syscalls-table). A python script to easily look up a specific call number on a specific architecture is available [here](https://github.com/hrw/python-syscalls)

## Relevant parts for Tiny Clear Elf

The following information is collected from the glibc headers, Marcin Juszkiewicz's and table and python script, the aforementioned man page, and the man pages for the `write` and `exit` syscalls (`WRITE(2)` and `EXIT(2)` respectively, both are from the Linux man-pages project).

### Setting up a syscall

The following table contains the project-relevant information from 2 tables in the `SYSCALL(2)` man page and Marcin Juszkiewicz's table.
I've adjusted the names of the various fields and architectures to improve clarity in this context, and better align with the terminology I've been using for this project overall.

| **Arch/ABI**    | **Instruction** | **System Call Register** | **arg1 register** | **arg2 register** | **arg3 register** | **`write` call** | **`exit` call** |
|-----------------|-----------------|--------------------------|-------------------|-------------------|-------------------|------------------|-----------------|
| `amd64`         | `syscall`       | `rax`                    | `rdi`             | `rsi`             | `rdx`             | `1`              | `60`            |
| `i386`          | `int $0x80`     | `eax`                    | `ebx`             | `ecx`             | `esi`             | `4`              | `1`             |
| `armel`/`armhf` | `swi 0x0`\*     | `r7`                     | `r0`              | `r1`              | `r2`              | `4`              | `1`             |
| `arm64`         | `svc #0`        | `w8`                     | `x0`              | `x1`              | `x2`              | `64`             | `93`            |
| `ppc64`\*\*     | `sc`            | `r0`                     | `r3`              | `r4`              | `r5`              | `4`              | `1`             |
| `s390x`         | `svc 0`\*\*\*   | `r1`                     | `r2`              | `r3`              | `r4`              | `4`              | `1`             |
| `mips`\*\*      | `syscall`       | `v0`                     | `a0`              | `a1`              | `a2`              | `4004`           | `4001`          |
| `mips64`\*\*    | `syscall`       | `v0`                     | `a0`              | `a1`              | `a2`              | `5001`           | `5058`          |
| `riscv64`       | `ecall`         | `a7`                     | `a0`              | `a1`              | `a2`              | `64`             | `93`            |

\* *Note: I've seen online tutorials say to use `svc #0` here. In the `armel`/`armhf` instructions `swi 0x0` and `svc #0` both assemble to `000000ef`, so that should also work just fine.*

\*\* PowerPC and MIPS systems can typically switch between little-endian and big-endian, and use the same registers for both. The `el` in the names for the architectures indicates that they are in little-endian mode, but because that
is not relevant in this context, it would be superfluous to specify.

\*\*\* On s390x, if the syscall number is less than 256, it can be passed directly to - i.e. `svc 4` would have the same effect as setting `r1` to 4 then calling `svc 0`.

### `write`

The `write` syscall takes 3 arguments. In C, its function declaration is `ssize (int fd, const void *buf, size_t count);`.

In raw binary, it reads the file descriptor number from the arg1 register, the **memory address of** the data to write from the arg2 register, and the number of bytes to write from the arg3 register.

### `exit`

The `exit` syscall takes 1 argument. In C, its function declaration is `void _exit(int status);`.

In raw binary, it reads the exit status from the arg1 register.
