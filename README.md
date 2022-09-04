# Tiny Clear ELF
The goal of this project is to create the smallest possible ELF executable that clears the screen, for all architectures that are officially supported by Debian GNU/Linux Bullseye. Why? Originally it was because I felt like it. Later on, a I mentioned it to a professor, who that I should keep this in mind as a college Capstone project.

The way they work is simple - they print out the following hexadecimal data to stdout: `1b 5b 48 1b 5b 4a 1b 5b 33 4a`.

Breaking it down further, what that does is print 3 ANSI escape sequences:
1. `ESC[H` - move the cursor to position 0,0
2. `ESC[J` - clear the screen
3. `ESC[3J` - clear any scrollback lines

Note that these utilites are hand-written in a hex editor, so source code distribution is not really an applicable concept. As such, I am not releasing them under a formal license. If you want to use them, you can do so however you want, but I'd appreciate it if you'd let me know - that's not a requirement, just something I'm curious about.

I can't test all of these on real hardware, so I plan on using QEMU to test them. I also should note that am writing this README having never worked with pure assembly of any kind in any capacity, so I might be biting off more than I can chew with this project. For now, this repo is a statement of intent rather than a finished project.
