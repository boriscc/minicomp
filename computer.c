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
    "ADD", "SHL", "SHR", "NOT", "AND", "OR", "XOR", "CMP" };

char const *computer_instr_name[COMPUTER_INSTR_NR] = {
    "LD", "ST", "DATA", "JMPR", "JMP", "JXXX", "CLF", "IO" };

void computer_reset(computer *comp)
{
    memset(comp, 0, sizeof(*comp));
    comp->is_running = 1;
    comp->io_input[PERI_ADDR_KEYBOARD] = peri_keyboard_buffered_input;
    comp->io_output[PERI_ADDR_ASCII_PRINTER] = peri_ascii_printer_output;
    comp->io_output[PERI_ADDR_INTEGER_PRINTER] = peri_integer_printer_output;
    comp->io_output[PERI_ADDR_TERMINATE] = peri_terminate_output;
    comp->io_input[PERI_ADDR_RANDOM] = peri_random_input;
}

int computer_is_running(computer *comp)
{
    return comp->is_running;
}

unsigned char get_flag(unsigned char flag, unsigned char pos)
{
    return (flag >> pos) & 1;
}

void set_flag(unsigned char *flag, unsigned char pos)
{
    *flag |= (unsigned char)(1 << pos);
}

void unset_flag(unsigned char *flag, unsigned char pos)
{
    *flag &= (unsigned char)(~(1 << pos));
}

void alu_comp(unsigned char a, unsigned char b, unsigned char carry_in, unsigned char op, unsigned char *c, unsigned char *flag)
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

    if(*c == 0) set_flag(flag, COMPUTER_FLAG_ZERO);
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

