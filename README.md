```
 ___________________________________________
/    _|_o._      _                   _  __  \
|     |_|| |\/__| |___ __ _ _ _  ___| |/ _| |
|   /\      // _| / -_) _` | '_|/ -_) |  _| |
| <(oo)>     \__|_\___\__,_|_|  \___|_|_|   |
\___________________________________________/
```

The goal of this project is to create the smallest possible ELF executable that clears the screen, for all architectures that are officially supported by Debian GNU/Linux Bookworm, as well as RISC-V 64-bit, which is slated to be included in Debian GNU/Linux Trixie. I made each of the 9\* unique binaries by hand in [hed](/fr0zn/hed), a minimalist vim-inspired hex editor.

\* there are 10 binaries included, but only nine unique binaries. Debian considers `armel` and `armhf` to be 2 different architectures, but the Tiny Clear Elf binaries are identical. This is because `armhf` is an upgraded version of `armel` for armv7 and newer systems with hardware floating point units (FPUs), and Tiny Clear Elf binaries do not do any floating point math, or use any features that require armv7.

## How it works

The way they work is simple - they print out the following hexadecimal data to stdout: `1b 63 1b 5b 33 4a`.

Breaking it down further, what that does is print 3 ANSI escape sequences:
1. `␛c` (`1b 63`) - move the cursor to position 0,0 and clear the screen
3. `␛[3J` (`1b 5b 33 4a`) - clear the scrollback buffer

The executables in this project depend on the terminal supporting those escape sequences, which is not guaranteed to be the case, though all commonly-used terminals I am aware of do support them.

Note that these utilities are hand-written in a hex editor, so source code distribution is not really an applicable concept. If you want to use the Tiny Clear ELF binaries, you can do so under the terms in the LICENSE file. I'd appreciate it if you'd let me know what you're doing with them, but that's not a requirement, just something I'd appreciate.

All of these have been verified to work when run with QEMU. Additionally, I've run most of them (namely amd64, i386, armhf, armel, arm64, and mipsel) on physical hardware successfully.

A demo/display/infosheet/presentation… thing of sorts is available on [asciinema](https://asciinema.org/a/558392)
