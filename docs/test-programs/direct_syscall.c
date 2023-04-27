#include <unistd.h>
#include <sys/syscall.h> 

int main(int argc, int argv[])
{
    syscall(__NR_write, 1, "\x1b[H\x1b[J\x1b[3J", 10);
    syscall(__NR_exit, 0);
}
