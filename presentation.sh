#!/usr/bin/env bash
# for this script to work, the system MUST be able to run foreign ELF binaries as
# though they were native, using the Linux kernel's binfmt_misc capabilities and
# something like qemu-user, and MUST have the following programs installed:
#
# * du
# * head
# * tail
# * cat
# * figlet
# * file
# * hexyl
# * readelf
# * awk
# * bash
#
# those are provided by the following packages on Debian-like systems:
#
# * coreutils (du, head, tail, cat)
# * figlet
# * file
# * hexyl
# * binutils (readelf)
# * gawk (awk)
# * bash
#
# It also depends on rasm2 (part of the radare2 reverse engineering toolkit), which is not in
# Debian's repos. Its source can be fount at https://github.com/radareorg/radare2
#
# This script must be run in a terminal emulator that's at least 112 columns and 56 rows in size.

# make sure we're in the right directory
cd "$(dirname "$(realpath "$0")")" || exit 12

heading() {
    printf '\e[%dH\e[1;4;32m(%s)\e[m\n' "$@"
}

bash_clear() {
    # why not use one of the 9-10 different clear commands I'm presenting? I don't want to have to choose which one
    # to use.
    printf '\e[H\e[J\e[3J'
}

arch_specific_logo() {
    cat logo
    printf '\e[H'
    figlet -f slant "$architecture" | sed $'s/^/\e[48G/'
}

wait_for_eof() {
    cat >/dev/null
}

bash_clear

cat logo

cat <<EOF
$(printf '\e[1;32m')
| | -+- |
+-+  |  |
| | -+- .
$(printf '\e[m')
This is my presentation of the Tiny Clear Elf series of executables
EOF

wait_for_eof


for tiny_clear_elf in */clear; do
    "$tiny_clear_elf" # use the current executable to clear the screen
    architecture="$(dirname "$tiny_clear_elf")"


    arch_specific_logo

    case "$architecture" in
        amd64|i386) rasm2_arch=x86 endianness=little ;;
        arm*) rasm2_arch=arm endianness=little ;;
        mips*) rasm2_arch=mips endianness=little ;;
        ppc64el) rasm2_arch=ppc endianness=little ;;
        s390x) rasm2_arch=s390 endianness=big ;;
        riscv64) rasm2_arch=riscv endianness=little ;;
    esac


    # set some variables that depend on whether it's 64 or 32 bits by parsing the elf file itself
    case "$(head -c5 "$tiny_clear_elf" | tail -c1)" in
        $'\x01') bits=32; ehdr_size=52; phdr_size=32  ;;
        $'\x02') bits=64; ehdr_size=64; phdr_size=56 ;;
        *) printf 'ERROR: invalid value in elf header.\n' >&2 ; exit 1;;
    esac

    # print the architecture 48 cells in, so that it doesn't clobber the logo.

    heading 8 'HEXDUMP OF EXECUTABLE'
    hexyl "$tiny_clear_elf"

    heading 23 'ELF HEADER OF EXECUTABLE'
    hexyl -n"$ehdr_size" "$tiny_clear_elf"
    readelf -h "$tiny_clear_elf"

    read -s

    wait_for_eof

    "$tiny_clear_elf"

    arch_specific_logo

    heading 8 'PROGRAM HEADER TABLE OF EXECUTABLE'
    hexyl -s"$ehdr_size" -n"$phdr_size" "$tiny_clear_elf"
    readelf -l "$tiny_clear_elf"

    heading 26 'DISSASSEMBLY'
    case "$endianness" in
        big)
            head -c-10 "$tiny_clear_elf" | tail -c+$((ehdr_size+phdr_size+1)) |\
                rasm2 -a"$rasm2_arch" -b"$bits" -B -e -d -f - ;;
        little)
            head -c-10 "$tiny_clear_elf" | tail -c+$((ehdr_size+phdr_size+1)) |\
                rasm2 -a"$rasm2_arch" -b"$bits" -B -d -f - ;;
    esac

    heading 38 'HEXDUMP OF LAST 10 BYTES'

    tail -c 10 "$tiny_clear_elf" | hexyl

    heading 42 'HEXDUMP OF OUTPUT'

    "$tiny_clear_elf" | hexyl

    read -s

done
