#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <argp.h>
#include "config_impl.h"
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
    static struct termios gs_term_old;
    static struct termios gs_term_cur;
#endif

struct arguments {
#ifdef HAVE_TIMING
    double frequency;
#endif
    int fast;
    int print_total_clock_cycles;
    char *ram_file;
};

static struct arguments gs_arg = {
#ifdef HAVE_TIMING
    1000,
#endif
    0, 0, NULL };

char const *argp_program_version = "simulator " MINICOMP_VERSION;
char const *argp_program_bug_address = "<boris.carlsson@gmail.com>";

static char gs_argp_doc[] = "simulator - Simulate programs for the minicomp computer.\n";
static char gs_argp_args_doc[] = "ram-file";

static struct argp_option gs_argp_options[] = {
#ifdef HAVE_TIMING
    { "frequency", 'f', "N", 0, "Set clock frequency. Default 1000", 0 },
#endif
    { "fast", 'F', NULL, 0, "Fast simulation (will ignore frequency)", 0 },
    { "print-total-cycles", 'T', NULL, 0, "Print final elapsed clock cycles", 0 },
    { "no-print-total-cycles", 't', NULL, OPTION_HIDDEN, "Print final elapsed clock cycles", 0 },
    { 0, 0, 0, 0, 0, 0 }
};

static error_t parse_opt(int key, char *arg, struct argp_state *state)
{
    struct arguments *arguments = state->input;
    
    switch (key) {
#ifdef HAVE_TIMING
        case 'f':
            arguments->frequency = strtod(arg, NULL);
            if(arguments->frequency <= 0) argp_usage(state);
            break;
#endif
        case 'F':
            arguments->fast = 1;
            break;
        case 't':
            arguments->print_total_clock_cycles = 0;
            break;
        case 'T':
            arguments->print_total_clock_cycles = 1;
            break;
        case ARGP_KEY_ARG:
            if(state->arg_num == 0) arguments->ram_file = arg;
            break;
        case ARGP_KEY_END:
            if(state->arg_num != 1) argp_usage(state);
            break;
        default:
        return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

static struct argp gs_argp = { gs_argp_options, parse_opt, gs_argp_args_doc, gs_argp_doc, 0, 0, 0 };

#ifdef HAVE_TIMING
static double time_now()
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
    double cycle_time;
#endif

#ifdef HAVE_SIGNAL
    if(signal(SIGINT, sig_handler) == SIG_ERR) {
        fprintf(stderr, "Warning: Can not catch SIGINT.\n");
    }
#endif

    argp_parse(&gs_argp, argc, argv, 0, 0, &gs_arg);
#ifdef HAVE_TIMING
    cycle_time = 1 / gs_arg.frequency;
#endif

    init_screen();

    computer_reset(&comp);

    {
        FILE *fp;
        int i;
        if((fp = fopen(gs_arg.ram_file, "rb")) == NULL) {
            fprintf(stderr, "ERROR: Can not open file '%s' for reading.\n'", gs_arg.ram_file);
            goto clean;
        }
        for(i = 0; i < COMPUTER_RAM_SIZE; i++) {
            int c = fgetc(fp);
            if(c == EOF) break;
            comp.ram[i] = (unsigned char)c;
        }
        fclose(fp);
    }

    if(gs_arg.fast) {
        while(computer_is_running(&comp)) {
            computer_step_instruction_fast(&comp);
        }
    } else {
        while(computer_is_running(&comp)) {
#ifdef HAVE_TIMING
            double cycle_start = time_now();
#endif
            computer_step_cycle(&comp);
#ifdef HAVE_TIMING
            while(time_now() < cycle_start + cycle_time);
#endif
        }
    }

    if(gs_arg.print_total_clock_cycles) {
        printf("Total clock-cycles: %ld.\n", comp.clock_cycle);
    }

clean:
    finalize_screen();

    return 0;
}

