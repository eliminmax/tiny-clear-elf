/* This program, when compiled with -static -nostartfiles, is equivalent to
 * a tiny-clear-elf program, in terms of syscalls used. It does not work on all
 * platforms. */
#include <unistd.h>
#include <sys/syscall.h> 

int main(int argc, char** argv)
{
    syscall(__NR_write, 1, "\33c\33[3J", 10);
    syscall(__NR_exit, 0);
}
