#include "peri.h"
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#ifdef HAVE_NCURSES
#   include <ncurses.h>
#else
#   include <unistd.h>
#   include <termios.h>
#endif

#ifndef HAVE_NCURSES
int my_getch()
{
    char buf = 0;

    struct termios old = { 0 };
    struct termios tmp;

    if(tcgetattr(0, &old) < 0) {
        perror("tcgetattr");
    }
    tmp = old;

    tmp.c_lflag &= (tcflag_t)~ICANON;
    tmp.c_lflag &= (tcflag_t)~ECHO;
    tmp.c_cc[VMIN] = 0;
    tmp.c_cc[VTIME] = 0;

    if(tcsetattr(0, TCSANOW, &tmp) < 0) {
        perror("tcsetattr ICANON");
    }
    if(read(0, &buf, 1) < 0) {
        perror ("read()");
    }
    if(tcsetattr(0, TCSADRAIN, &old) < 0) {
        perror ("tcsetattr ~ICANON");
    }

    return buf;
}
#endif


void peri_keyboard_buffered_input(computer *comp, unsigned char *key)
{
#ifdef HAVE_NCURSES
    int val = getch();

    if(val == ERR) val = 0;
#else
    int val = my_getch();
#endif

    *key = (unsigned char)val;
}

void peri_keyboard_unbuffered_input(computer *comp, unsigned char *key)
{
    int c, c2;

#ifdef HAVE_NCURSES
    c = getch();
    if(c != ERR) {
        while((c2 = getch()) != ERR) {
            c = c2;
        }
    }

    if(c == ERR) c = 0;
#else
    c = my_getch();
    if(c) {
        while((c2 = my_getch())) {
            c = c2;
        }
    }
#endif

    *key = (unsigned char)c;
}

void peri_ascii_printer_output(computer *comp, unsigned char c)
{
#ifdef HAVE_NCURSES
    printw("%c", c);
    refresh();
#else
    printf("%c", c);
    fflush(stdout);
#endif
}

void peri_integer_printer_output(computer *comp, unsigned char i)
{
#ifdef HAVE_NCURSES
    printw("%u", i);
    refresh();
#else
    printf("%u", i);
    fflush(stdout);
#endif
}

void peri_terminate_output(computer *comp, unsigned char c)
{
    comp->is_running = 0;
}

void peri_random_input(computer *comp, unsigned char *rnd)
{
    static int initialized = 0;

    if(initialized == 0) {
        srand((unsigned int)time(NULL));
        initialized = 1;
    }

    *rnd = (unsigned char)rand();
}

