#include "computer.h"
#include "peri.h"
#include <string.h>
#include "config_impl.h"
#ifdef HAVE_NCURSES
#   include <ncurses.h>
#endif

char const *computer_reg_name[COMPUTER_REG_NR] = {
    "RA", "RB", "RC", "RD" };

char const *computer_alu_op_name[COMPUTER_ALU_OP_NR] = {
    "ADD", "SHR", "SHL", "NOT", "AND", "OR", "XOR", "CMP" };

char const *computer_instr_name[COMPUTER_INSTR_NR] = {
    "LD", "ST", "DATA", "JMPR", "JMP", "JXXX", "CLF", "IO" };
    
char const computer_flag_name[COMPUTER_FLAG_NR] = {
    'Z', 'E', 'A', 'C' };

void computer_reset(computer *comp)
{
    memset(comp, 0, sizeof(*comp));
    comp->is_running = 1;
    comp->io_input[PERI_ADDR_KEYBOARD] = peri_keyboard_buffered_input;
    comp->io_output[PERI_ADDR_ASCII_PRINTER] = peri_ascii_printer_output;
    comp->io_output[PERI_ADDR_INTEGER_PRINTER] = peri_integer_printer_output;
    comp->io_output[PERI_ADDR_INTEGER16_PRINTER] = peri_integer16_printer_output;
    comp->io_output[PERI_ADDR_INTEGER24_PRINTER] = peri_integer24_printer_output;
    comp->io_output[PERI_ADDR_INTEGER32_PRINTER] = peri_integer32_printer_output;
    comp->io_output[PERI_ADDR_TERMINATE] = peri_terminate_output;
    comp->io_input[PERI_ADDR_RANDOM] = peri_random_input;
}

int computer_is_running(computer *comp)
{
    return comp->is_running;
}

static unsigned char get_flag(unsigned char flag, unsigned char pos)
{
    return (flag >> pos) & 1;
}

static void set_flag(unsigned char *flag, unsigned char pos)
{
    *flag |= (unsigned char)(1 << pos);
}

/*
static void unset_flag(unsigned char *flag, unsigned char pos)
{
    *flag &= (unsigned char)(~(1 << pos));
}
*/

static void alu_comp(unsigned char a, unsigned char b, unsigned char carry_in, unsigned char op, unsigned char *c, unsigned char *flag)
{
    *flag = 0;
    if(a > b) {
        set_flag(flag, COMPUTER_FLAG_A_LARGER);
    } else if(a == b) {
        set_flag(flag, COMPUTER_FLAG_EQUAL);
    }

    if(op == COMPUTER_ALU_ADD) {
        int sum = (a + b + carry_in);
        if(sum > 255) {
            set_flag(flag, COMPUTER_FLAG_CARRY);
        }
        *c = (unsigned char)(sum & 255);
    } else if(op == COMPUTER_ALU_SHL) {
        if(a & 128) {
            set_flag(flag, COMPUTER_FLAG_CARRY);
        }
        *c = (unsigned char)((a << 1) + carry_in);
    } else if(op == COMPUTER_ALU_SHR) {
        if(a & 1) {
            set_flag(flag, COMPUTER_FLAG_CARRY);
        }
        *c = (unsigned char)((a >> 1) + (carry_in << 7));
    } else if(op == COMPUTER_ALU_NOT) {
        *c = (unsigned char)(~a);
    } else if(op == COMPUTER_ALU_AND) {
        *c = (unsigned char)(a & b);
    } else if(op == COMPUTER_ALU_OR) {
        *c = (unsigned char)(a | b);
    } else if(op == COMPUTER_ALU_XOR) {
        *c = (unsigned char)(a ^ b);
    } else if(op == COMPUTER_ALU_CMP) {
        /* Do nothing */
    }

    if(op != COMPUTER_ALU_CMP && *c == 0) set_flag(flag, COMPUTER_FLAG_ZERO);
}

void computer_step_cycle(computer *comp)
{
    int step = (int)(comp->clock_cycle % COMPUTER_INSTR_LEN);

    if(step == 0) {
        unsigned char flag_unused;
        comp->mar = comp->iar;
        alu_comp(comp->iar, 1, 0, 0, &comp->acc, &flag_unused);
    } else if(step == 1) {
        comp->ir = comp->ram[(int)comp->mar];
    } else if(step == 2) {
        comp->iar = comp->acc;
    } else if(step < 6) {
        unsigned char instr = (unsigned char)((comp->ir >> 4) & 15);
        unsigned char A = (unsigned char)((comp->ir >> 2) & 3);
        unsigned char B = (unsigned char)(comp->ir & 3);

        if(instr & 8) { /* ALU */
            if(step == 3) {
                comp->tmp = comp->reg[B];
            } else if(step == 4) {
                alu_comp(comp->reg[A], comp->tmp, get_flag(comp->flags, COMPUTER_FLAG_CARRY),
                         instr & 7, &comp->acc, &comp->flags);
            } else if(step == 5) {
                if((instr & 7) != COMPUTER_ALU_CMP) {
                    comp->reg[B] = comp->acc;
                }
            }
        } else if(instr == COMPUTER_INSTR_LD) {
            if(step == 3) {
                comp->mar = comp->reg[A];
            } else if(step == 4) {
                comp->reg[B] = comp->ram[comp->mar];
            }
        } else if(instr == COMPUTER_INSTR_ST) {
            if(step == 3) {
                comp->mar = comp->reg[A];
            } else if(step == 4) {
                comp->ram[comp->mar] = comp->reg[B];
            }
        } else if(instr == COMPUTER_INSTR_DATA) {
            if(step == 3) {
                unsigned char flag_unused;
                alu_comp(comp->iar, 1, 0, 0, &comp->acc, &flag_unused);
                comp->mar = comp->iar;
            } else if(step == 4) {
                comp->reg[B] = comp->ram[comp->mar];
            } else if(step == 5) {
                comp->iar = comp->acc;
            }
        } else if(instr == COMPUTER_INSTR_JMPR) {
            if(step == 3) {
                comp->iar = comp->reg[B];
            }
        } else if(instr == COMPUTER_INSTR_JMP) {
            if(step == 3) {
                comp->mar = comp->iar;
            } else if(step == 4) {
                comp->iar = comp->ram[comp->mar];
            }
        } else if(instr == COMPUTER_INSTR_JXXX) {
            if(step == 3) {
                unsigned char flag_unused;
                alu_comp(comp->iar, 1, 0, COMPUTER_ALU_ADD, &comp->acc, &flag_unused);
                comp->mar = comp->iar;
            } else if(step == 4) {
                comp->iar = comp->acc;
            } else if(step == 5) {
                if(comp->flags & comp->ir) {
                    comp->iar = comp->ram[comp->mar];
                }
            }
        } else if(instr == COMPUTER_INSTR_CLF) {
            if(step == 3) {
                unsigned char acc_unused;
                alu_comp(0, 1, 0, COMPUTER_ALU_ADD, &acc_unused, &comp->flags);
            }
        } else if(instr == COMPUTER_INSTR_IO) {
            int is_input = (((A >> 1) & 1) == COMPUTER_IO_INPUT);
            int is_data = ((A & 1) == COMPUTER_IO_DATA);
            if(step == 3 && !is_input) {
                if(is_data) {
                    if(comp->io_output[comp->io_addr]) {
                        comp->io_output[comp->io_addr](comp, comp->reg[B]);
                    }
                } else {
                    comp->io_addr = comp->reg[B];
                }
            } else if(step == 4 && is_input) {
                if(is_data) {
                    if(comp->io_input[comp->io_addr]) {
                        comp->io_input[comp->io_addr](comp, &comp->reg[B]);
                    }
                } else {
                    /* Can not get current address */
                }
            }
        }
    } else if(step == 6) {
        /* Do nothing */
    }

    comp->clock_cycle++;
}

void computer_step_instruction(computer *comp)
{
    int i;
    int stepper_pos = (int)(comp->clock_cycle % COMPUTER_INSTR_LEN);
    int step_nr = COMPUTER_INSTR_LEN - stepper_pos;

    for(i = 0; i < step_nr; i++) {
        computer_step_cycle(comp);
    }
}

static void fast_ADD(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;
    int sum = va + vb + get_flag(comp->flags, COMPUTER_FLAG_CARRY);

    comp->reg[b] = (unsigned char)(sum);
    comp->flags = 0;
    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    if(sum > 255) set_flag(&flags, COMPUTER_FLAG_CARRY);
    if(comp->reg[b] == 0) set_flag(&flags, COMPUTER_FLAG_ZERO);
    comp->flags = (unsigned char)flags;
}

static void fast_SHR(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;
    int carry_in = get_flag(comp->flags, COMPUTER_FLAG_CARRY);
    comp->reg[b] = (unsigned char)((va >> 1) + (carry_in << 7));

    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    if(va & 1) set_flag(&flags, COMPUTER_FLAG_CARRY);
    if(comp->reg[b] == 0) set_flag(&flags, COMPUTER_FLAG_ZERO);
    comp->flags = (unsigned char)flags;
}

static void fast_SHL(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;
    int carry_in = get_flag(comp->flags, COMPUTER_FLAG_CARRY);

    comp->reg[b] = (unsigned char)((va << 1) + carry_in);

    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    if(va & 128) set_flag(&flags, COMPUTER_FLAG_CARRY);
    if(comp->reg[b] == 0) set_flag(&flags, COMPUTER_FLAG_ZERO);
    comp->flags = (unsigned char)flags;
}

static void fast_NOT(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;

    comp->reg[b] = (unsigned char)~va;
    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    if(comp->reg[b] == 0) set_flag(&flags, COMPUTER_FLAG_ZERO);
    comp->flags = (unsigned char)flags;
}

static void fast_AND(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;

    comp->reg[b] = (unsigned char)(va & vb);
    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    if(comp->reg[b] == 0) set_flag(&flags, COMPUTER_FLAG_ZERO);
    comp->flags = (unsigned char)flags;
}

static void fast_OR(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;

    comp->reg[b] = (unsigned char)(va | vb);
    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    if(comp->reg[b] == 0) set_flag(&flags, COMPUTER_FLAG_ZERO);
    comp->flags = (unsigned char)flags;
}

static void fast_XOR(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;

    comp->reg[b] = (unsigned char)(va ^ vb);
    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    if(comp->reg[b] == 0) set_flag(&flags, COMPUTER_FLAG_ZERO);
    comp->flags = (unsigned char)flags;
}

static void fast_CMP(computer *comp, int a, int b)
{
    int va = comp->reg[a];
    int vb = comp->reg[b];
    unsigned char flags = 0;

    if(va > vb) set_flag(&flags, COMPUTER_FLAG_A_LARGER);
    if(va == vb) set_flag(&flags, COMPUTER_FLAG_EQUAL);
    comp->flags = (unsigned char)flags;
}

static void fast_LD(computer *comp, int a, int b)
{
    comp->reg[b] = (unsigned char)(comp->ram[comp->reg[a]]);
}

static void fast_ST(computer *comp, int a, int b)
{
    comp->ram[comp->reg[a]] = (unsigned char)(comp->reg[b]);
}

static void fast_DATA(computer *comp, int a, int b)
{
    comp->iar = (unsigned char)(comp->iar + 1);
    comp->reg[b] = comp->ram[comp->iar];
}

static void fast_JMPR(computer *comp, int a, int b)
{
    comp->iar = (unsigned char)(comp->reg[b] - 1);
}

static void fast_JMP(computer *comp, int a, int b)
{
    comp->iar = (unsigned char)(comp->ram[(unsigned char)(comp->iar + 1)] - 1);
}

static void fast_JCAEZ(computer *comp, int a, int b)
{
    if(comp->flags & ((a << 2) + b)) {
        comp->iar = (unsigned char)(comp->ram[(unsigned char)(comp->iar + 1)] - 1);
    } else {
        comp->iar = (unsigned char)(comp->iar + 1);
    }
}

static void fast_CLF(computer *comp, int a, int b)
{
    comp->flags = 0;
}

static void fast_IO(computer *comp, int a, int b)
{
    if(a == 0) {
        comp->io_input[comp->io_addr](comp, &comp->reg[b]);
    } else if(a == 1) {
        comp->reg[b] = comp->io_addr;
    } else if(a == 2) {
        comp->io_output[comp->io_addr](comp, comp->reg[b]);
    } else {
        comp->io_addr = comp->reg[b];
    }
}

static void (*fast_func[16])(computer *, int, int) = {
    fast_LD, fast_ST, fast_DATA, fast_JMPR,
    fast_JMP, fast_JCAEZ, fast_CLF, fast_IO,
    fast_ADD, fast_SHR, fast_SHL, fast_NOT,
    fast_AND, fast_OR, fast_XOR, fast_CMP };

void computer_step_instruction_fast(computer *comp)
{
    unsigned char iar = comp->iar;
    unsigned char op = comp->ram[iar];

    fast_func[op >> 4](comp, (op >> 2) & 3, op & 3);
    
    comp->iar = (unsigned char)(comp->iar + 1);
    comp->clock_cycle += 6;
}

void computer_get_instruction_name(unsigned char instruction, char *name)
{
    int op = instruction >> 4;
    int a = (instruction >> 2) & 3;
    int b = instruction & 3;
    
    if(op & 8) { /* ALU operation */
        op &= 7;
        sprintf(name, "%-4s %2s %2s", computer_alu_op_name[op], computer_reg_name[a], computer_reg_name[b]);
    } else {
        if(op < 2) {
            sprintf(name, "%-4s %2s %2s", computer_instr_name[op], computer_reg_name[a], computer_reg_name[b]);
        } else if(op < 4) {
            sprintf(name, "%-4s %2s", computer_instr_name[op], computer_reg_name[b]);
        } else if(op == 4 || op == 6) {
            sprintf(name, "%-4s", computer_instr_name[op]);
        } else if(op == 5) { /* JXXX */
            int pos = 1;
            int i;
            int flags = (a << 2) + b;
            sprintf(name, "J   ");
            for(i = 0; i < COMPUTER_FLAG_NR; i++) {
                if(flags & (1 << i)) {
                    name[pos++] = computer_flag_name[i];
                }
            }
        } else { /* op == 7, IO */
            int io = a >> 1;
            int da = a & 1;
            int pos = 0;
            
            if(io == COMPUTER_IO_INPUT) {
                name[pos++] = 'I';
                name[pos++] = 'N';
            } else {
                name[pos++] = 'O';
                name[pos++] = 'U';
                name[pos++] = 'T';
            }
            if(da == COMPUTER_IO_DATA) {
                name[pos++] = 'D';
            } else {
                name[pos++] = 'A';
            }
            sprintf(name + 5, computer_reg_name[b]);
        }
    }
}
