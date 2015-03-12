#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#ifdef HAVE_NCURSES
#   include <ncurses.h>
#else
#   include <termios.h>
#endif
#include "computer.h"
#ifdef HAVE_SIGNAL
#   include <signal.h>
#endif

#ifdef HAVE_TIMING
#   ifndef _POSIX_MONOTONIC_CLOCK
#       error "No monotonic-clock present!"
#   endif
#endif

#ifndef HAVE_NCURSES
    static struct termios gs_term_old = { 0 };
    static struct termios gs_term_cur;
#endif

#ifdef HAVE_TIMING
double time_now()
{
    struct timespec time_now_timespec;

    clock_gettime(CLOCK_MONOTONIC, &time_now_timespec);

    return (double)time_now_timespec.tv_sec + (double)time_now_timespec.tv_nsec * 1e-9;
}
#endif

static void init_screen()
{
#ifdef HAVE_NCURSES
    initscr();
    timeout(0);
    noecho();
#else
    if(tcgetattr(0, &gs_term_old) < 0) {
        perror("tcgetattr");
    }
    gs_term_cur = gs_term_old;

    gs_term_cur.c_lflag &= (tcflag_t)~ICANON;
    gs_term_cur.c_lflag &= (tcflag_t)~ECHO;
    gs_term_cur.c_cc[VMIN] = 0;
    gs_term_cur.c_cc[VTIME] = 0;

    if(tcsetattr(0, TCSANOW, &gs_term_cur) < 0) {
        perror("tcsetattr ICANON");
    }
#endif
}

static void finalize_screen()
{
#ifdef HAVE_NCURSES
    endwin();
#else
    if(tcsetattr(0, TCSADRAIN, &gs_term_old) < 0) {
        perror ("tcsetattr ~ICANON");
    }
#endif
}

#ifdef HAVE_SIGNAL
static void sig_handler(int signo)
{
    if(signo == SIGINT) {
        finalize_screen();
        exit(EXIT_FAILURE);
    }
}
#endif

int main(int argc, char *argv[])
{
    computer comp;
#ifdef HAVE_TIMING
    double freq = 1000;
    double cycle_time = 1 / freq;
#endif

#ifdef HAVE_SIGNAL
    if(signal(SIGINT, sig_handler) == SIG_ERR) {
        fprintf(stderr, "Warning: Can not catch SIGINT.\n");
    }
#endif

    init_screen();

    computer_reset(&comp);

    if(argc != 2) {
        fprintf(stderr, "Usage: %s RAM-file\n", argv[0]);
        goto clean;
    }
    {
        FILE *fp;
        int i;
        if((fp = fopen(argv[1], "rb")) == NULL) {
            fprintf(stderr, "ERROR: Can not open file '%s' for reading.\n'", argv[1]);
            goto clean;
        }
        for(i = 0; i < COMPUTER_RAM_SIZE; i++) {
            int c = fgetc(fp);
            if(c == EOF) break;
            comp.ram[i] = (unsigned char)c;
        }
        fclose(fp);
    }

    while(computer_is_running(&comp)) {
#ifdef HAVE_TIMING
        double cycle_start = time_now();
#endif
        computer_step_cycle(&comp);
#ifdef HAVE_TIMING
        while(time_now() < cycle_start + cycle_time);
#endif
    }

clean:
    finalize_screen();

    return 0;
}

