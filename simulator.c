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
#include "peri.h"
#ifdef HAVE_SIGNAL
#   include <signal.h>
#endif

#ifdef HAVE_TIMING
#   ifndef _POSIX_MONOTONIC_CLOCK
#       error "No monotonic-clock present!"
#   endif
#endif

static computer gs_comp;
static unsigned long gs_profile_count[COMPUTER_RAM_SIZE] = { 0 };

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
    int batch_mode;
    int profile;
    unsigned long print_interval;
    char *ram_file;
    int number_input;
};

static struct arguments gs_arg = {
#ifdef HAVE_TIMING
    1000,
#endif
    0, 0, 0, 0, 0, NULL, 0 };

char const *argp_program_version = "simulator " MINICOMP_VERSION;
char const *argp_program_bug_address = "<boris.carlsson@gmail.com>";

static char gs_argp_doc[] = "simulator - Simulate programs for the minicomp computer.\n";
static char gs_argp_args_doc[] = "ram-file";

static struct argp_option gs_argp_options[] = {
#ifdef HAVE_TIMING
    { "frequency", 'f', "N", 0, "Set clock frequency. Default 1000", 0 },
#endif
    { "fast", 'F', NULL, 0, "Fast simulation (will ignore frequency)", 0 },
    { "print-cycles", 'C', "N", 0, "Print elapsed cycles every N cycles", 0 },
    { "no-print-cycles", 'c', NULL, OPTION_HIDDEN, "Print elapsed cycles every N cycles", 0 },
    { "print-total-cycles", 'T', NULL, 0, "Print final elapsed clock cycles", 0 },
    { "no-print-total-cycles", 't', NULL, OPTION_HIDDEN, "Print final elapsed clock cycles", 0 },
    { "batch-mode", 'B', NULL, 0, "Enable batch mode (no tty fiddling)", 0 },
    { "no-batch-mode", 'b', NULL, OPTION_HIDDEN, "Enable batch mode (no tty fiddling)", 0 },
    { "profile", 'P', NULL, 0, "Print profile information at the end", 0 },
    { "no-profile", 'p', NULL, OPTION_HIDDEN, "Print profile information at the end", 0 },
    { "number-input", 'N', NULL, 0, "Parse input as numbers before sending to computer", 0 },
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
        case 'C':
            arguments->print_interval = (unsigned long)strtol(arg, NULL, 10);
            break;
        case 'c':
            arguments->print_interval = 0;
            break;
        case 't':
            arguments->print_total_clock_cycles = 0;
            break;
        case 'T':
            arguments->print_total_clock_cycles = 1;
            break;
        case 'b':
            arguments->batch_mode = 0;
            break;
        case 'B':
            arguments->batch_mode = 1;
            break;
        case 'p':
            arguments->profile = 0;
            break;
        case 'P':
            arguments->profile = 1;
            break;
        case 'N':
            arguments->number_input = 1;
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
    if(gs_arg.batch_mode == 0) {
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
    }
#endif
}

static void finalize_screen()
{
#ifdef HAVE_NCURSES
    endwin();
#else
    if(gs_arg.batch_mode == 0) {
        if(tcsetattr(0, TCSADRAIN, &gs_term_old) < 0) {
            perror ("tcsetattr ~ICANON");
        }
    }
#endif
}

static void finalize()
{
    if(gs_arg.print_total_clock_cycles) {
        printf("Total clock-cycles: %ld.\n", gs_comp.clock_cycle);
    }
    if(gs_arg.profile) {
        int i;
        
        printf("--- Profiling information ---\n");
        printf("%3s: %-10s %20s %7s\n", "pos", "instr.", "count", "percent");
        for(i = 0; i < COMPUTER_RAM_SIZE; i++) {
            char name[10];
            computer_get_instruction_name(gs_comp.ram[i], name);
            printf("%03d: %-10s %20lu %6.2f%%\n", i, name, gs_profile_count[i], 600 * (double)gs_profile_count[i] / (double)gs_comp.clock_cycle);
        }
    }
    finalize_screen();
}

#ifdef HAVE_SIGNAL
static void sig_handler(int signo)
{
    if(signo == SIGINT) {
        finalize();
        exit(EXIT_FAILURE);
    }
}
#endif

int main(int argc, char *argv[])
{
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

    if (gs_arg.number_input) {
        peri_keyboard_set_input_mode(PERI_INPUT_MODE_NUMBER);
    }

    init_screen();

    computer_reset(&gs_comp);

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
            gs_comp.ram[i] = (unsigned char)c;
        }
        fclose(fp);
    }

    if(gs_arg.fast) {
        if(gs_arg.print_interval || gs_arg.profile) {
            unsigned long last_print = 0;
            while(computer_is_running(&gs_comp)) {
                if(gs_arg.print_interval && last_print + gs_arg.print_interval <= gs_comp.clock_cycle) {
                    printf("clock-cycles: %ld\n", gs_comp.clock_cycle);
                    last_print = gs_comp.clock_cycle;
                }
                if(gs_arg.profile) {
                    gs_profile_count[gs_comp.iar]++;
                }
                computer_step_instruction_fast(&gs_comp);
            }
        } else {
            while(computer_is_running(&gs_comp)) {
                computer_step_instruction_fast(&gs_comp);
            }
        }
    } else {
        unsigned long last_print = 0;
        while(computer_is_running(&gs_comp)) {
#ifdef HAVE_TIMING
            double cycle_start = time_now();
#endif
            computer_step_cycle(&gs_comp);
            
            if(gs_arg.print_interval) {
                if(last_print + gs_arg.print_interval <= gs_comp.clock_cycle) {
                    printf("clock-cycles: %ld\n", gs_comp.clock_cycle);
                    last_print = gs_comp.clock_cycle;
                }
            }
            if(gs_arg.profile) {
                gs_profile_count[gs_comp.iar]++;
            }
            
#ifdef HAVE_TIMING
            while(time_now() < cycle_start + cycle_time);
#endif
        }
    }

clean:
    finalize();

    return 0;
}

