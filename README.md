# Tiny Clear ELF
The goal of this project is to create the smallest possible ELF executable that clears the screen, for all architectures that are officially supported by Debian GNU/Linux Bullseye.

## How it works

The way they work is simple - they print out the following hexadecimal data to stdout: `1b 5b 48 1b 5b 4a 1b 5b 33 4a`.

Breaking it down further, what that does is print 3 ANSI escape sequences:
1. `ESC[H` - move the cursor to position 0,0
2. `ESC[J` - clear the screen
3. `ESC[3J` - clear any scrollback lines

Note that these utilities are hand-written in a hex editor, so source code distribution is not really an applicable concept. As such, I am not releasing them under a formal license. If you want to use them, you can do so however you want. I'd appreciate it if you'd let me know, but that's not a requirement, just something I'm curious about.

I can't test all of these on real hardware, so I plan on using QEMU to test them. I also should note that am writing this README having never worked with pure assembly of any kind in any capacity, so I might be biting off more than I can chew with this project. For now, this repo is a statement of intent rather than a finished project.

## Why do this?

* It's (my idea of) fun
* It will help me understand:
  * the structure of ELF files
  * the basics of several instruction set architectures
  * the Linux Kernels `binfmt_misc` capability
* It's likely to be at least a major part of my capstone project at college

### TODO:

* [x] Create the ELF files
  * [x] x86 family
    * [x] amd64
    * [x] i386
  * [x] ARM family
    * [x] armhf
    * [x] armel
    * [x] aarch64
  * [x] MIPS family
    * [x] mipsel
    * [x] mips64el
  * [x] PowerPC Family
    * [x] ppc64el
  * [x] IBM Z Family
    * [x] s390x
* [ ] Create a logo - an image of a transparent pointy-eared humanoid that takes up only about 1/16th of the image
