/* This program prints the system call numbers for the syscalls used within
 * the tiny-clear-elf project.
 *
 * By cross-compiling and running with qemu-user, it can make it faster than
 * having to look it up in a table, like I did originally.
 * */
#include <unistd.h>
#include <sys/syscall.h> 
#include <stdio.h>

int main(int argc, char** argv)
{
    printf("__NR_write: %d\n__NR_exit: %d\n", __NR_write, __NR_exit);
    return(0);
}
