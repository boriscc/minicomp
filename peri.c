#include "peri.h"
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include "config_impl.h"
#ifdef HAVE_NCURSES
#   include <ncurses.h>
#else
#   include <unistd.h>
#   include <termios.h>
#   define ERR 0
#endif

static int gs_input_mode = PERI_INPUT_MODE_RAW;
static char gs_input_line_buf[BUFSIZ];
static char *gs_input_line_buf_pos = gs_input_line_buf;
static unsigned char gs_input_buf[BUFSIZ];
static unsigned char *gs_input_buf_head = gs_input_buf;
static unsigned char *gs_input_buf_tail = gs_input_buf;

int my_getch()
{
#ifdef HAVE_NCURSES
    return getch();
#else
    char buf = 0;

    struct termios old;
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
#endif
}

static int parse_number(char *s)
{
    if(strlen(s) == 3 && s[0] == '\'' && s[2] == '\'') {
        return s[1];
    }

    /* Check if number is in binary */
    if(strlen(s) == 8) {
        int i;
        int bad = 0;

        for(i = 0; i < 8; i++) {
            if(s[i] != '0' && s[i] != '1') {
                bad = 1;
                break;
            }
        }
        if(bad == 0) {
            int number = 0;
            for(i = 0; i < 8; i++) {
                number |= (s[i] == '1') << (7-i);
            }
            return number;
        }
    }

    return (int)strtol(s, NULL, 0);
}

static void get_keyboard_input(computer *comp)
{
    int c;

    while ((c = my_getch()) != ERR) {
        if (gs_input_mode == PERI_INPUT_MODE_RAW) {
            *gs_input_buf_head = (unsigned char)c;
            gs_input_buf_head = gs_input_buf + ((size_t)gs_input_buf_head + 1) % sizeof(gs_input_buf);
        } else if (gs_input_mode == PERI_INPUT_MODE_NUMBER) {
            if (c == '\n') {
                *gs_input_line_buf_pos = '\0';
                int number = parse_number(gs_input_line_buf);
                if (number >= 0 && number <= 0xff) {
                    *gs_input_buf_head = (unsigned char)number;
                    gs_input_buf_head = gs_input_buf + ((size_t)gs_input_buf_head + 1) % sizeof(gs_input_buf);
                } else {
                    peri_ascii_printer_output(comp, (unsigned char)'E');
                }
                gs_input_line_buf_pos = gs_input_line_buf;
            } else {
                *gs_input_line_buf_pos++ = (char)c;
            }
            peri_ascii_printer_output(comp, (unsigned char)c);
        }
    }
}


void peri_keyboard_buffered_input(computer *comp, unsigned char *key)
{
    get_keyboard_input(comp);
    if (gs_input_buf_head == gs_input_buf_tail) {
        *key = 0;
    } else {
        *key = *gs_input_buf_tail;
        gs_input_buf_tail = gs_input_buf + ((size_t)gs_input_buf_tail + 1) % sizeof(gs_input_buf);
    }
}

void peri_keyboard_has_input(computer *comp, unsigned char *has_input)
{
    get_keyboard_input(comp);
    *has_input = gs_input_buf_head != gs_input_buf_tail;
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

void peri_hex_printer_output(computer *comp, unsigned char i)
{
#ifdef HAVE_NCURSES
    printw("%02x", i);
    refresh();
#else
    printf("%02x", i);
    fflush(stdout);
#endif
}

void peri_integer16_printer_output(computer *comp, unsigned char i)
{
    static unsigned long len = 0;
    static unsigned long num = 0;

    num += (unsigned long)i << (8*len);
    len++;
    if(len == 2) {
#ifdef HAVE_NCURSES
        printw("%ld", num);
        refresh();
#else
        printf("%ld", num);
        fflush(stdout);
#endif
        len = 0;
        num = 0;
    }
}

void peri_integer24_printer_output(computer *comp, unsigned char i)
{
    static unsigned long len = 0;
    static unsigned long num = 0;

    num += (unsigned long)i << (8*len);
    len++;
    if(len == 3) {
#ifdef HAVE_NCURSES
        printw("%ld", num);
        refresh();
#else
        printf("%ld", num);
        fflush(stdout);
#endif
        len = 0;
        num = 0;
    }
}

void peri_integer32_printer_output(computer *comp, unsigned char i)
{
    static unsigned long len = 0;
    static unsigned long num = 0;

    num += (unsigned long)i << (8*len);
    len++;
    if(len == 4) {
#ifdef HAVE_NCURSES
        printw("%ld", num);
        refresh();
#else
        printf("%ld", num);
        fflush(stdout);
#endif
        len = 0;
        num = 0;
    }
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

void peri_keyboard_set_input_mode(int input_mode)
{
    gs_input_mode = input_mode;
}
