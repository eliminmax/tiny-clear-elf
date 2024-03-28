#!/bin/sh
# for this script to work, the system SHOULD be able to run foreign ELF binaries as
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
# On a Debian system, to run foreign binaries as though they're native, you SHOULD install:
# * systemd or binfmt-support (enables binfmt_misc usage and provides an interface to it)
# * qemu-user-binfmt or qemu-user-static (enables running foreign binaries)
#
# If you do not have bindmt_misc enabled, or do not want to use it, define the FORCE_USE_QEMU
# environment variable, and this will try to fall back to invoking qemu-user binaries.
# Will prioritize qemu-$arch over qemu-$arch-static, but supports the latter as a fall-back
# If you do that, then each supported architecture MUST have qemu-$arch and/or qemu-$arch-static
# installed to the $PATH.
#
# This script MUST be run in a terminal emulator that's at least 94 columns and 50 rows in size.
# To avoid cutting off content, if it detects that it's not operating at that size, it will exit.
#
# Exit code 2 means that there was an issue with the terminal environment (e.g. too small to fit the presentation).
# Exit code 3 means that there was a dependency issue
# Exit code 100 means that something is seriously broken, and `cd`ing to the directory containing this script failed.

# some dependency checking
dep_issues=0

dep_check () {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'error: missing dependency: ' >&2
        printf '%s (provided by %s %s)\n' "$1" "$2" "$3" >&2
        dep_issues=$((dep_issues+1))
    fi
}

for coreutils_cmd in cat dirname head realpath stty tail; do
    dep_check "$coreutils_cmd" deb coreutils
done

dep_check awk deb awk
dep_check readelf deb binutils
dep_check hexyl deb hexyl
dep_check figlet deb figlet
dep_check tput deb ncurses-bin
dep_check rasm2 git 'https://github.com/radareorg/radare2'

# "${FORCE_USE_QEMU+x}" resolves to 'x' if FORCE_USE_QEMU is defined
# -z tests if the following string is empty
# if FORCE_USE_QEMU is defined, even if it's empty, this won't run, as even an empty var becomes 'x'
if [ -z "${FORCE_USE_QEMU+x}" ]; then
    # make sure binfmt_misc support is enabled - this enables running foreign binaries
    if [ ! -e /proc/sys/fs/binfmt_misc ]; then
        printf 'error: binfmt support is missing.\n' >&2
        dep_issues=$((dep_issues+1))
    elif [ "$(cat /proc/sys/fs/binfmt_misc/status)" != 'enabled' ]; then
        printf 'error: binfmt support is disabled.\n' >&2
        dep_issues=$((dep_issues+1))
    else
        # check that all of the binaries can run
        for clear_bin in */clear; do
            if ! "$clear_bin" >/dev/null 2>&1; then
                printf 'error: non-zero exit code testing %s. ' "$clear_bin" >&2
                printf 'Is binfmt support set up for that architecture?\n' >&2
                dep_issues=$((dep_issues+1))
            fi
        done
    fi
else
    # generate qemu wrapper functions - Debian has both statically and dynamically linked versions
    # of qemu-user, and the names of the statically linked ones have -static added to the end.
    # define wrapper functions to call the appropriate binary
    for arch in x86_64 i386 arm aarch64 mipsel mips64el ppc64le s390x riscv64; do
        # `eval` to define function dynamically based on architecture and available commands
        # prioritize dynamically linked
        if command -v "qemu-$arch" >/dev/null 2>&1; then
            # if qemu-s390x exists, this will evaluate as 's390x_wrapper () { qemu-s390x "$@"; }'
            # which is a function that just passes its arguments straight to the qemu-s390x command
            eval "${arch}_wrapper() { qemu-$arch \"\$@\"; }"
        elif command -v "qemu-$arch-static" >/dev/null 2>&1; then
            # if qemu-s390x doesn't exist, but qemu-s390x-static does, this will evaluate as
            # 's390x_wrapper () { qemu-s390x-static "$@"; }'
            # which is a function that just passes its arguments straight to the qemu-s390x-static command
            eval "${arch}_wrapper() { qemu-$arch-static \"\$@\"; }"
        else
            printf 'Neither qemu-%s nor qemu-%s-static found.\n' "$arch" "$arch" >&2
            dep_issues=$((dep_issues+1))
        fi
    done
fi

if [ "$dep_issues" -gt 0 ]; then
    if [ "$dep_issues" -eq 1 ]; then
        printf '\e[1mExiting: found a dependency issue.\e[m\n' >&2
    else
        printf '\e[1mExiting: found %d dependency issues.\e[m\n' "$dep_issues" >&2
    fi
    exit 3
fi

# make sure we're in the right directory
cd "$(dirname "$(realpath "$0")")" || exit 100

# save original terminal settings to be restored at the end
stty_orig="$(stty -g)"

stty -echo # hide anything the user types

# https://old.reddit.com/r/linuxquestions/comments/rl1jai/comment/hphcj8h/
tput civis # hide cursor

show_heading () {
    # display a heading at a specific row in bold green underlined, enclosed in parenthases
    # first argument is the row number
    # second argument is the heading text
    printf '\e[%dH\e[1;4;32m(%s)\e[m\n' "$1" "$2"
}

sh_clear () {
    # why not use one of the 10 different clear commands I'm presenting?
    # I don't want to have to choose which one to use.
    printf '\e[H\e[J\e[3J'
}

cleanup () {
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

arch_specific_logo () {
    # display the Tiny Clear Elf ASCII-art logo, followed by the name
    # in figlet italics
    cat logo
    printf '\e[H' # go to top row
    # print the architecture name 48 cells in, so that it doesn't overwrite the logo.
    figlet -f slant "$architecture" | awk '{printf "\x1b[48G%s\n", $0}'
}

wait_for_next () {
    # hacky way to require presenter to press enter to continue
    read -r _wait_var # this variable is unused, but needs to be set anyway
}

run_current () {
    # invoke tiny clear elf directly unless FORCE_USE_QEMU is defined
    if [ -z "${FORCE_USE_QEMU+x}" ]; then
        "$tiny_clear_elf"
    else
        "$qemu_wrapper" "$tiny_clear_elf"
    fi

}

sh_clear

cat logo

# the first line is an escape sequence to set the text to bold green
printf '\e[1;32m
╻ ╻ ╺┳╸ ╻
┣━┫  ┃  ╹
╹ ╹ ╺┻╸ •
\e[m
This is my presentation of the Tiny Clear Elf series of executables\n'
# the 2nd-to-last line is an escape sequence to clear text formatting

wait_for_next

for tiny_clear_elf in */clear; do
    # need this info for proper display and disassembly
    architecture="$(dirname "$tiny_clear_elf")"
    case "$architecture" in
           'amd64') rasm2_arch=x86   endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 qemu_wrapper=x86_64_wrapper;;
            'i386') rasm2_arch=x86   endianness=little rasm2_bits=32 ehdr_size=52 phdr_size=32 qemu_wrapper=i386_wrapper;;
           'armhf') rasm2_arch=arm   endianness=little rasm2_bits=16 ehdr_size=52 phdr_size=32 qemu_wrapper=arm_wrapper;;
           'armel') rasm2_arch=arm   endianness=little rasm2_bits=16 ehdr_size=52 phdr_size=32 qemu_wrapper=arm_wrapper;;
           'arm64') rasm2_arch=arm   endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 qemu_wrapper=aarch64_wrapper;;
          'mipsel') rasm2_arch=mips  endianness=little rasm2_bits=32 ehdr_size=52 phdr_size=32 qemu_wrapper=mipsel_wrapper;;
        'mips64el') rasm2_arch=mips  endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 qemu_wrapper=mips64el_wrapper;;
         'ppc64el') rasm2_arch=ppc   endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 qemu_wrapper=ppc64le_wrapper;;
           's390x') rasm2_arch=s390  endianness=big    rasm2_bits=64 ehdr_size=64 phdr_size=56 qemu_wrapper=s390x_wrapper;;
         'riscv64') rasm2_arch=riscv endianness=little rasm2_bits=64 ehdr_size=64 phdr_size=56 qemu_wrapper=riscv64_wrapper;;
    esac
    # for armhf and armel, it's technically 32-bits, but because
    # it uses thumb instructions, rasm2 needs to be told it's 16.

    run_current # use the current executable to clear the screen
    # each Tiny Clear ELF is in a folder matching its architecture name

    arch_specific_logo

    show_heading 8 'HEXDUMP OF EXECUTABLE'
    hexyl "$tiny_clear_elf"

    show_heading 23 'ELF HEADER OF EXECUTABLE'
    hexyl -n"$ehdr_size" "$tiny_clear_elf"
    readelf -h "$tiny_clear_elf"

    wait_for_next

    run_current

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

    run_current | hexyl

    wait_for_next
done

cleanup
