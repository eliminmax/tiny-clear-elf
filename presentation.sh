#!/bin/sh
# for this script to work, the system MUST be able to run foreign ELF binaries as
# though they were native, using the Linux kernel's binfmt_misc capabilities and
# something like qemu-user, MUST be run from the Tiny Clear ELF git directory,
# and MUST have the following programs installed:
#
# * awk
# * cat
# * dirname
# * figlet
# * head
# * hexyl
# * rasm2
# * readelf
# * realpath
# * stty
# * tail
# * tput
#
# other than rasm2, those are provided by the following packages on Debian 12 (Bookworm):
#
# * awk (awk)
# * binutils (readelf)
# * coreutils (cat, dirname, head, realpath, stty, tail)
# * hexyl (hexyl)
# * figlet (figlet)
# * ncurses-bin (tput)
#
# awk is a virtual package provided by gawk, mawk, or original-awk.
# The one awk command used here has been tested with all three
#
# rasm2 is part of the radare2 reverse engineering toolkit, which is not in
# Debian's repos. Its source can be found at https://github.com/radareorg/radare2
# 
# Additionally, on a Debian system, to run foreign binaries as required, you must install:
# * systemd or binfmt-support (enables binfmt_misc usage and provides an interface to it)
# * qemu-user-binfmt or qemu-user-static (enables running foreign binaries)
#
# This script must be run in a terminal emulator that's at least 94 columns and 50 rows in size.
# To avoid cutting off content, if it detects that it's not operating at that size, it will exit.

# make sure we're in the right directory
cd "$(dirname "$(realpath "$0")")" || exit 1

# save original terminal settings to be restored at the end
stty_orig="$(stty -g)"

stty -echo # hide anything the user types

# https://old.reddit.com/r/linuxquestions/comments/rl1jai/comment/hphcj8h/
tput civis # hide cursor

show_heading() {
    # display a heading at a specific row in bold green underlined, enclosed in parenthases
    # first argument is the row number
    # second argument is the heading text
    printf '\e[%dH\e[1;4;32m(%s)\e[m\n' "$1" "$2"
}

sh_clear() {
    # why not use one of the 10 different clear commands I'm presenting?
    # I don't want to have to choose which one to use.
    printf '\e[H\e[J\e[3J'
}

cleanup() {
    # at the end of a run, restore the terminal settings to how they were.
    stty "$stty_orig"
    tput cnorm
    sh_clear
}
# call cleanup before quitting if common terminating signals are sent
trap cleanup HUP INT QUIT ABRT TERM

dimension_check () {
    # method of getting rows and cols adapted from https://stackoverflow.com/a/68085512
    term_size="$(stty size)"
    cols="${term_size#* }"
    rows="${term_size% *}"
    if [ "$cols" -lt 94 ] || [ "$rows" -lt 50 ]; then
        cleanup
        printf 'stopping presentation - terminal too small.\n' >&2
        exit 2
    fi
}
dimension_check # run once right away
trap dimension_check WINCH # re-run dimension_check if terminal is resized.

arch_specific_logo() {
    # display the Tiny Clear Elf ASCII-art logo, followed by the name
    # in figlet italics
    cat logo
    printf '\e[H' # go to top row
    # print the architecture name 48 cells in, so that it doesn't overwrite the logo.
    figlet -f slant "$architecture" | awk '{printf "\x1b[48G%s\n", $0}'
}

wait_for_next() {
    # hacky way to require presenter to press enter to continue
    read -r _wait_var # this variable is unused, but needs to be set anyway
}

sh_clear

cat logo

# the first line is an escape sequence to set the text to bold green
printf '\e[1;32m
| | -+- |
+-+  |  |
| | -+- .
\e[m
This is my presentation of the Tiny Clear Elf series of executables\n'
# the 2nd-to-last line is an escape sequence to clear text formatting

wait_for_next

for tiny_clear_elf in */clear; do
    "$tiny_clear_elf" # use the current executable to clear the screen
    # each Tiny Clear ELF is in a folder matching its architecture name
    architecture="$(dirname "$tiny_clear_elf")"


    arch_specific_logo
    # need this info for proper display and disassembly
    case "$architecture" in
           'amd64') rasm2_arch=x86   endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 ;;
            'i386') rasm2_arch=x86   endianness=little rasm2_bits=32 ehdr_size=52 phdr_size=32 ;;
           'armhf') rasm2_arch=arm   endianness=little rasm2_bits=16 ehdr_size=52 phdr_size=32 ;;
           'armel') rasm2_arch=arm   endianness=little rasm2_bits=32 ehdr_size=52 phdr_size=32 ;;
           'arm64') rasm2_arch=arm   endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 ;;
          'mipsel') rasm2_arch=mips  endianness=little rasm2_bits=32 ehdr_size=52 phdr_size=32 ;;
        'mips64el') rasm2_arch=mips  endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 ;;
         'ppc64el') rasm2_arch=ppc   endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 ;;
           's390x') rasm2_arch=s390  endianness=big    rasm2_bits=64 ehdr_size=64 phdr_size=56 ;;
         'riscv64') rasm2_arch=riscv endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 ;;
    esac
    # for armhf, it's technically 32-bits, but because
    # it uses thumb instructions, rasm2 needs to be told it's 16.

    show_heading 8 'HEXDUMP OF EXECUTABLE'
    hexyl "$tiny_clear_elf"

    show_heading 23 'ELF HEADER OF EXECUTABLE'
    hexyl -n"$ehdr_size" "$tiny_clear_elf"
    readelf -h "$tiny_clear_elf"

    wait_for_next

    "$tiny_clear_elf"

    arch_specific_logo

    show_heading 8 'PROGRAM HEADER TABLE OF EXECUTABLE'
    hexyl -s"$ehdr_size" -n"$phdr_size" "$tiny_clear_elf"
    readelf -l "$tiny_clear_elf"

    show_heading 26 'DISSASSEMBLY'
    case "$endianness" in
        big)
            head -c-10 "$tiny_clear_elf" | tail -c+$((ehdr_size+phdr_size+1)) |\
                rasm2 -a"$rasm2_arch" -b"$rasm2_bits" -B -e -d -f - ;;
        little)
            head -c-10 "$tiny_clear_elf" | tail -c+$((ehdr_size+phdr_size+1)) |\
                rasm2 -a"$rasm2_arch" -b"$rasm2_bits" -B -d -f - ;;
    esac

    show_heading 38 'HEXDUMP OF LAST 10 BYTES'

    tail -c 10 "$tiny_clear_elf" | hexyl

    show_heading 42 'HEXDUMP OF OUTPUT'

    "$tiny_clear_elf" | hexyl

    wait_for_next
done

cleanup
