#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "computer.h"

void *malloc_safe(size_t s)
{
    void *d;

    if((d = malloc(s)) == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(EXIT_FAILURE);
    }

    return d;
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

struct label_list *label_list_alloc(char *name)
{
    struct label_list *label = malloc_safe(sizeof(struct label_list));

    label->name = malloc_safe(strlen(name) + 1);
    strcpy(label->name, name);
    label->base = 0;
    label->pos = NULL;
    label->next = NULL;

    return label;
}

struct label_pos_list *label_pos_list_add_pos(struct label_pos_list *pos, int val)
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

struct label_list *label_list_add_pos(struct label_list *label, char *name, int pos)
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

struct label_list *label_list_set_base(struct label_list *label, char *name, int base)
{
    struct label_list *p = label;

    if(label == NULL) {
        label = label_list_alloc(name);
        label->base = base;
        return label;
    }

    for(p = label; ; p = p->next) {
        if(strcmp(p->name, name) == 0) {
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
int isignore(char c)
{
    return isspace(c) || c == ',';
}

/* Remove whitespace (as defined by isignore()) from start and end
 * of string by returning the position of the first non-whitespace
 * and moving the end of the string to the last non-whitespace. */
char *trim(char *s)
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
int get_reg(char *name)
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
void set_ram(unsigned char *ram, int *pos, int val)
{
    if(val < 0 || val > 255) {
        fprintf(stderr, "Internal compiler error 2.\n");
        exit(EXIT_FAILURE);
    }
    if(*pos > 255) {
        fprintf(stderr, "Program too large.\n");
        exit(EXIT_FAILURE);
    }
    ram[(*pos)++] = (unsigned char)val;
}

/* Parse a number, either as binary, decimal, hexadecimal, octal, character or label */
unsigned char get_number(char *s, struct label_list **label, int ram_pos)
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
    int in_line = 0;
    int i;

    if(argc != 3) {
        fprintf(stderr, "Usage: %s <asm-file> <ram-file>\n", argv[0]);
        exit(EXIT_FAILURE);
    }
    if((in = fopen(argv[1], "r")) == NULL) {
        fprintf(stderr, "Could not open '%s' for reading.\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    while(fgets(line, BUFSIZ, in)) {
        char *tline = trim(line);
        char *sub1 = NULL;
        char *sub2 = NULL;
        int bad;

        in_line++;

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
                    fprintf(stderr, "Invalid syntax at line %d.\n", in_line);
                    exit(EXIT_FAILURE);
                }
            }
        }

        /* Label */
        if(tline[strlen(tline) - 1] == ':') {
            tline[strlen(tline) - 1] = '\0';
            label = label_list_set_base(label, tline, ram_pos);
            continue;
        }

        /* Check if the line is raw data */
        if(tline[0] == '.' && tline[1] == '\0') {
            if(sub1 == NULL || sub2 != NULL) {
                fprintf(stderr, "Bad format at line %d. Expected: \". <number>\"\n", in_line);
                exit(EXIT_FAILURE);
            }
            set_ram(ram, &ram_pos, (unsigned char)get_number(sub1, &label, ram_pos));
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
                if(tline[i] == 'Z') {
                    ram_tmp |= 1 << COMPUTER_FLAG_ZERO;
                } else if(tline[i] == 'E') {
                    ram_tmp |= 1 << COMPUTER_FLAG_EQUAL;
                } else if(tline[i] == 'A') {
                    ram_tmp |= 1 << COMPUTER_FLAG_A_LARGER;
                } else if(tline[i] == 'C') {
                    ram_tmp |= 1 << COMPUTER_FLAG_CARRY;
                } else {
                    fprintf(stderr, "Unknown instruction '%s' on line %d.\n", tline, in_line);
                    exit(EXIT_FAILURE);
                }
            }
            set_ram(ram, &ram_pos, (unsigned char)ram_tmp);
            set_ram(ram, &ram_pos, (unsigned char)get_number(sub1, &label, ram_pos));
            if(sub2) bad = 1;
        } else {
            fprintf(stderr, "Unknown instruction '%s' on line %d.\n", tline, in_line);
            exit(EXIT_FAILURE);
        }

        if(bad) {
            fprintf(stderr, "Too many arguments on line %d.\n", in_line);
            exit(EXIT_FAILURE);
        }
    }

    fclose(in);

    /* Set label positions. */
    {
        struct label_list *p;

        /* Loop over labels. */
        for(p = label; p; p = p->next) {
            struct label_pos_list *q;

            /* If the label position is not set. */
            if(p->base == 0) {
                fprintf(stderr, "Undefined label '%s'.\n", p->name);
                exit(EXIT_FAILURE);
            }
            /* Loop over all positions. */
            for(q = p->pos; q; q = q->next) {
                ram[q->pos] = (unsigned char)p->base;
            }
        }
    }

    if((out = fopen(argv[2], "wb")) == NULL) {
        fprintf(stderr, "Could not open '%s' for writing.\n", argv[2]);
        exit(EXIT_FAILURE);
    }

    /* Write RAM-data to out-file. */
    for(i = 0; i < ram_pos; i++) {
        if(fputc(ram[i], out) == EOF) {
            fprintf(stderr, "Could not write to '%s'.\n", argv[2]);
            exit(EXIT_FAILURE);
        }
    }
    fclose(out);

    return 0;
}

