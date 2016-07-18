#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include "computer.h"
#include <argp.h>
#include "config_impl.h"

static int gs_in_line = 0;
static int gs_error_nr = 0;

struct arguments {
    int print_label_value;
    char *asm_file;
    char *ram_file;
};

static struct arguments gs_arg = { 0, NULL, NULL };

char const *argp_program_version = "asm_compiler " MINICOMP_VERSION;
char const *argp_program_bug_address = "<boris.carlsson@gmail.com>";

static char gs_argp_doc[] = "asm_compiler - Compile assembler into machine code for the minicomp computer.\n";
static char gs_argp_args_doc[] = "asm-file ram-file";

static struct argp_option gs_argp_options[] = {
    { "print-label-value", 'L', NULL, 0, "Print numerical value of all labels", 0 },
    { "no-print-label-value", 'l', NULL, OPTION_HIDDEN, "Do not print numerical value of all labels", 0 },
    { 0, 0, 0, 0, 0, 0 }
};

static error_t parse_opt(int key, char *arg, struct argp_state *state)
{
    struct arguments *arguments = state->input;
    
    switch (key) {
        case 'L':
            arguments->print_label_value = 1;
            break;
        case 'l':
            arguments->print_label_value = 0;
            break;
        case ARGP_KEY_ARG:
            if(state->arg_num == 0) arguments->asm_file = arg;
            if(state->arg_num == 1) arguments->ram_file = arg;
            break;
        case ARGP_KEY_END:
            if(state->arg_num != 2) argp_usage(state);
            break;
        default:
        return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

static struct argp gs_argp = { gs_argp_options, parse_opt, gs_argp_args_doc, gs_argp_doc, 0, 0, 0 };

static void *malloc_safe(size_t s)
{
    void *d;

    if((d = malloc(s)) == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(EXIT_FAILURE);
    }

    return d;
}

static void report_error(char const *msg, ...)
    __attribute__((format(printf, 1, 2)));

static void report_error(char const *msg, ...)
{
    va_list arg;

    va_start(arg, msg);

    if(gs_in_line >= 0) {
        fprintf(stderr, "%s:%d Error: ", gs_arg.asm_file, gs_in_line);
    } else {
        fprintf(stderr, "%s: Error: ", gs_arg.asm_file);
    }
    vfprintf(stderr, msg, arg);
    fprintf(stderr, ".\n");

    gs_error_nr++;
}

/* Used to store locations in RAM where a label is used,
 * so that the base value of the label can be inserted there. */
struct label_pos_list {
    int pos; /* Position in RAM */
    struct label_pos_list *next;
};

/* List of all the labels. */
struct label_list {
    char *name;
    int base; /* Location of the actual label */
    struct label_pos_list *pos; /* Locations in RAM where the label is used */
    struct label_list *next;
};

static struct label_list *label_list_alloc(char *name)
{
    struct label_list *label = malloc_safe(sizeof(struct label_list));

    label->name = malloc_safe(strlen(name) + 1);
    strcpy(label->name, name);
    label->base = -1;
    label->pos = NULL;
    label->next = NULL;

    return label;
}

static struct label_pos_list *label_pos_list_add_pos(struct label_pos_list *pos, int val)
{
    struct label_pos_list *p = pos;

    if(pos == NULL) {
        pos = malloc_safe(sizeof(struct label_pos_list));
        pos->next = NULL;
        pos->pos = val;
        return pos;
    }

    /* Get to the last label_pos */
    while(p->next) p = p->next;

    p->next = malloc_safe(sizeof(struct label_pos_list));
    p->next->next = NULL;
    p->next->pos = val;

    return pos;
}

static struct label_list *label_list_add_pos(struct label_list *label, char *name, int pos)
{
    struct label_list *p = label;

    if(label == NULL) {
        label = label_list_alloc(name);
        label->pos = label_pos_list_add_pos(label->pos, pos);
        return label;
    }

    for(p = label; ; p = p->next) {
        if(strcmp(p->name, name) == 0) {
            p->pos = label_pos_list_add_pos(p->pos, pos);
            return label;
        }
        if(p->next == NULL) break;
    }

    /* The label does not exist, so create it and add the pos */
    p->next = label_list_alloc(name);
    p->next->pos = label_pos_list_add_pos(p->next->pos, pos);

    return label;
}

static struct label_list *label_list_set_base(struct label_list *label, char *name, int base)
{
    struct label_list *p = label;

    if(label == NULL) {
        label = label_list_alloc(name);
        label->base = base;
        return label;
    }

    for(p = label; ; p = p->next) {
        if(strcmp(p->name, name) == 0) {
            /* If already set */
            if(p->base >= 0) {
                report_error("Duplicate label \"%s\"", p->name);
            }
            p->base = base;
            return label;
        }
        if(p->next == NULL) break;
    }

    /* The label does not exist, so create it and add the base value */
    p->next = label_list_alloc(name);
    p->next->base = base;
    return label;
}

/* Characters that are treated as whitespace */
static int isignore(char c)
{
    return isspace(c) || c == ',';
}

/* Remove whitespace (as defined by isignore()) from start and end
 * of string by returning the position of the first non-whitespace
 * and moving the end of the string to the last non-whitespace. */
static char *trim(char *s)
{
    char *end;

    /* Skip unimportant stuff at the beginning */
    while(isignore(*s)) s++;

    /* If nothing is left of the string */
    if(*s == 0) {
        return s;
    }

    /* Skip unimportant stuff at the end */
    end = s + strlen(s) - 1;
    while(end > s && isignore(*end)) end--;

    *(end + 1) = '\0';

    return s;
}

/* Get numerical value of register from its name (ra, rb, rc, rd) */
static int get_reg(char *name)
{
    int i;

    if(name == NULL) {
        fprintf(stderr, "Expected register name.\n");
        exit(EXIT_FAILURE);
    }

    for(i = 0; i < COMPUTER_REG_NR; i++) {
        if(strcmp(computer_reg_name[i], name) == 0) {
            return i;
        }
    }

    fprintf(stderr, "Expected register name, got '%s'.\n", name);
    exit(EXIT_FAILURE);
}

/* Set RAM-value, and check that the value and position is okay. */
static void set_ram(unsigned char *ram, int *pos, int val)
{
    if(val < 0 || val > 255) {
        fprintf(stderr, "Internal compiler error 2.\n");
        exit(EXIT_FAILURE);
    }
    if(*pos == 256) {
        report_error("Program too large");
    }
    if(*pos < 256) {
        ram[*pos] = (unsigned char)val;
    }
    (*pos)++;
}

/* Parse a number, either as binary, decimal, hexadecimal, octal, character or label */
static unsigned char get_number(char *s, struct label_list **label, int ram_pos)
{
    char *p;
    long val;

    if(s == NULL) {
        fprintf(stderr, "Expected number.\n");
        exit(EXIT_FAILURE);
    }

    /* Check if number is a char */
    if(strlen(s) == 3 && s[0] == '\'' && s[2] == '\'') {
        return (unsigned char)s[1];
    }

    /* Check if number is a label */
    if(s[0] == '$') {
        *label = label_list_add_pos(*label, s+1, ram_pos);
        /* We return 0 now, and will later set all the label positions to the base value.
         * This is necessary since the base value might not be set at this point. */
        return 0;
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
            return (unsigned char)number;
        }
    }

    /* Parse number normally, see strtol for details */
    val = strtol(s, &p, 0);
    if(*p) {
        fprintf(stderr, "Expected a number, single char enclosed in \"'\" or label starting with '$', got '%s'.\n", s);
        exit(EXIT_FAILURE);
    }

    if(val < 0 || val > 255) {
        fprintf(stderr, "Invalid number: %ld.\n", val);
        exit(EXIT_FAILURE);
    }

    return (unsigned char)val;
}

int main(int argc, char *argv[])
{
    FILE *in, *out;
    unsigned char ram[COMPUTER_RAM_SIZE];
    int ram_pos = 0;
    struct label_list *label = NULL;
    char line[BUFSIZ];
    int i;

    argp_parse(&gs_argp, argc, argv, 0, 0, &gs_arg);

    if((in = fopen(gs_arg.asm_file, "r")) == NULL) {
        fprintf(stderr, "Could not open '%s' for reading.\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    while(fgets(line, BUFSIZ, in)) {
        char *tline = trim(line);
        char *sub1 = NULL;
        char *sub2 = NULL;
        int bad;

        gs_in_line++;

        /* Skip empty lines and comments */
        if(tline[0] == '\0' || tline[0] == '#') continue;

        /* Convert line to uppercase and parse character literals. */
        for(i = 0; tline[i]; i++) {
            /* An ugly way to parse char literals. A char literal is always three chars,
             * so replace it with a three digit number which will always suffice. I do this
             * so that the e.g. the char literal ' ' is not misstaken for a space. */
            if(tline[i] == '\'' && tline[i+1] && tline[i+2] == '\'') {
                sprintf(&tline[i], "%3u", tline[i+1]);
                i += 2;
            } else {
                tline[i] = (char)toupper(tline[i]);
            }
        }

        /* Remove comments */
        if((sub1 = strchr(tline, '#'))) {
            *sub1 = '\0';
        }
        tline = trim(tline);

        sub1 = strpbrk(tline, " ,;\t");
        if(sub1) {
            /* Now tline will be the first word of the line */
            sub1[0] = '\0';
            sub1++;
        }
        /* If there are more than one word. sub1 will be the second word, sub2 the third. */
        if(sub1) {
            sub1 = trim(sub1);
            sub2 = strpbrk(sub1, " ,;\t");
            if(sub2) {
                sub2[0] = '\0';
                sub2++;
            }
            if(sub2) {
                sub2 = trim(sub2);
                if(strpbrk(sub2, " ,;\t")) {
                    report_error("Invalid syntax (too many words)");
                }
            }
        }

        /* Label */
        if(tline[strlen(tline) - 1] == ':') {
            tline[strlen(tline) - 1] = '\0';
            if(strlen(tline)) {
                if(tline[strlen(tline) - 1] == ':') {
                    tline[strlen(tline) - 1] = '\0';
                    if(strlen(tline)) {
                        label = label_list_set_base(label, tline, ram_pos + 1);
                    } else {
                        report_error("Too short label name (0 chars)");
                    }
                } else {
                    label = label_list_set_base(label, tline, ram_pos);
                }
            } else {
                report_error("Too short label name (0 chars)");
            }
            continue;
        }

        /* Check if the line is raw data */
        if(tline[0] == '.' && tline[1] == '\0') {
            if(sub1 == NULL || sub2 != NULL) {
                report_error("Bad data format, expected \". <number>\"");
            }
            set_ram(ram, &ram_pos, (unsigned char)get_number(sub1, &label, ram_pos));
            continue;
        }

        /* Check if the line is a PRAGMA line */
        if(strcmp(tline, "PRAGMA") == 0) {
            if(sub1 == NULL) {
                report_error("Bad format: Expected a pragma type: \"POS\", \"SETPOS\"");
            }
            if(strcmp(sub1, "POS") == 0) {
                unsigned char requested_pos;

                if(sub2 == NULL) {
                    report_error("Expected numerical position after pragma pos");
                }

                requested_pos = get_number(sub2, &label, ram_pos);
                if(requested_pos == 0) {
                    report_error("pragma pos cannot be a label or the position 0");
                }
                if(ram_pos != requested_pos) {
                    report_error("pragma pos mismatch: requested(%d) != actual(%d)", requested_pos, ram_pos);
                }
            } else if(strcmp(sub1, "SETPOS") == 0) {
                unsigned char requested_pos;

                if(sub2 == NULL) {
                    report_error("Expected numerical position after pragma setpos");
                }

                requested_pos = get_number(sub2, &label, ram_pos);
                if(requested_pos == 0) {
                    report_error("pragma setpos cannot be a label or the position 0");
                }
                if(ram_pos > requested_pos) {
                    report_error("actual pos (%d) is larger than requested pos (%d) is setpos", ram_pos, requested_pos);
                }
                ram_pos = requested_pos;
            } else {
                report_error("Unknown pragma \"%s\"", sub1);
            }
            continue;
        }

        /* Chech if this is an ALU op */
        for(i = 0; i < COMPUTER_ALU_OP_NR; i++) {
            if(strcmp(computer_alu_op_name[i], tline) == 0) {
                set_ram(ram, &ram_pos, (unsigned char)(128 + (i<<4) + (get_reg(sub1)<<2) + get_reg(sub2)));
                break;
            }
        }
        /* If an ALU op was found, go to next line. */
        if(i < COMPUTER_ALU_OP_NR) continue;

        bad = 0; /* Will be 1 if too many arguments are present on the line. */
        /* Parse non-ALU ops. */
        if(strcmp(tline, computer_instr_name[COMPUTER_INSTR_LD]) == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_LD << 4) + (get_reg(sub1)<<2) + get_reg(sub2)));
        } else if(strcmp(tline, computer_instr_name[COMPUTER_INSTR_ST]) == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_ST << 4) + (get_reg(sub1)<<2) + get_reg(sub2)));
        } else if(strcmp(tline, computer_instr_name[COMPUTER_INSTR_DATA]) == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_DATA << 4) + get_reg(sub1)));
            set_ram(ram, &ram_pos, (unsigned char)get_number(sub2, &label, ram_pos));
        } else if(strcmp(tline, computer_instr_name[COMPUTER_INSTR_JMPR]) == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_JMPR << 4) + get_reg(sub1)));
            if(sub2) bad = 1;
        } else if(strcmp(tline, computer_instr_name[COMPUTER_INSTR_JMP]) == 0) {
            set_ram(ram, &ram_pos, (unsigned char)(COMPUTER_INSTR_JMP << 4));
            set_ram(ram, &ram_pos, (unsigned char)get_number(sub1, &label, ram_pos));
            if(sub2) bad = 1;
        } else if(strcmp(tline, computer_instr_name[COMPUTER_INSTR_CLF]) == 0) {
            set_ram(ram, &ram_pos, (unsigned char)(COMPUTER_INSTR_CLF << 4));
            if(sub1 || sub2) bad = 1;
        } else if(strcmp(tline, "IND") == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_IO << 4) +  0 + get_reg(sub1)));
            if(sub2) bad = 1;
        } else if(strcmp(tline, "INA") == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_IO << 4) +  4 + get_reg(sub1)));
            if(sub2) bad = 1;
        } else if(strcmp(tline, "OUTD") == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_IO << 4) +  8 + get_reg(sub1)));
            if(sub2) bad = 1;
        } else if(strcmp(tline, "OUTA") == 0) {
            set_ram(ram, &ram_pos, (unsigned char)((COMPUTER_INSTR_IO << 4) + 12 + get_reg(sub1)));
            if(sub2) bad = 1;
        } else if(tline[0] == 'J') {
            int ram_tmp = COMPUTER_INSTR_JXXX << 4;

            for(i = 1; i < (int)strlen(tline); i++) {
                int j;
                for(j = 0; j < COMPUTER_FLAG_NR; j++) {
                    if(tline[i] == computer_flag_name[j]) {
                        ram_tmp |= 1 << j;
                        break;
                    }
                }
                if(j == COMPUTER_FLAG_NR) {
                    report_error("Unknown instruction \"%s\"", tline);
                }
            }
            set_ram(ram, &ram_pos, (unsigned char)ram_tmp);
            set_ram(ram, &ram_pos, (unsigned char)get_number(sub1, &label, ram_pos));
            if(sub2) bad = 1;
        } else {
            report_error("Unknown instruction \"%s\"", tline);
        }

        if(bad) {
            report_error("Invalid syntax for op \"%s\" (too many words)", tline);
        }
    }

    fclose(in);
    gs_in_line = -1;

    /* Set label positions. */
    {
        struct label_list *p;

        /* Loop over labels. */
        for(p = label; p; p = p->next) {
            struct label_pos_list *q;

            /* If the label position is not set. */
            if(p->base < 0) {
                report_error("Undefined label \"%s\"", p->name);
            } else if(gs_arg.print_label_value) {
                printf("Label \"%s\" at ram-position %d.\n", p->name, p->base);
            }
            /* Loop over all positions. */
            for(q = p->pos; q; q = q->next) {
                ram[q->pos] = (unsigned char)p->base;
            }
        }
    }

    if(gs_error_nr) {
        fprintf(stderr, "%d error%s found.\n", gs_error_nr, (gs_error_nr == 1) ? "" : "s");
        exit(EXIT_FAILURE);
    }

    /* Write RAM-data to out-file. */
    if((out = fopen(gs_arg.ram_file, "wb")) == NULL) {
        fprintf(stderr, "Error: Could not open '%s' for writing.\n", gs_arg.ram_file);
        exit(EXIT_FAILURE);
    }

    for(i = 0; i < ram_pos; i++) {
        if(fputc(ram[i], out) == EOF) {
            fprintf(stderr, "Error: Could not write to \"%s\".\n", gs_arg.ram_file);
            exit(EXIT_FAILURE);
        }
    }
    fclose(out);

    return 0;
}

