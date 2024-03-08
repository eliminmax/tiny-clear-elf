#include <unistd.h>
#include <sys/syscall.h> 
#include <stdio.h>

int main(int argc, char** argv)
{
    printf("__NR_write: %d\n__NR_exit: %d\n", __NR_write, __NR_exit);
    return(0);
}
