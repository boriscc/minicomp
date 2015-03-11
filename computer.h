#ifndef COMPUTER_H_
#define COMPUTER_H_

#define COMPUTER_RAM_SIZE 256
#define COMPUTER_ADDR_SIZE 256
#define COMPUTER_REG_NR 4
#define COMPUTER_INSTR_LEN 7

#define COMPUTER_FLAG_ZERO     0
#define COMPUTER_FLAG_EQUAL    1
#define COMPUTER_FLAG_A_LARGER 2
#define COMPUTER_FLAG_CARRY    3

#define COMPUTER_ALU_ADD 0 /* 1000RARB */
#define COMPUTER_ALU_SHL 1 /* 1001RARB */
#define COMPUTER_ALU_SHR 2 /* 1010RARB */
#define COMPUTER_ALU_NOT 3 /* 1011RARB */
#define COMPUTER_ALU_AND 4 /* 1100RARB */
#define COMPUTER_ALU_OR  5 /* 1101RARB */
#define COMPUTER_ALU_XOR 6 /* 1110RARB */
#define COMPUTER_ALU_CMP 7 /* 1111RARB */
#define COMPUTER_ALU_OP_NR 8

#define COMPUTER_INSTR_LD   0 /* 0000RARB; RA, RB */
#define COMPUTER_INSTR_ST   1 /* 0001RARB; RA, RB */
#define COMPUTER_INSTR_DATA 2 /* 0010??RB+byte; byte; total size 2 */
#define COMPUTER_INSTR_JMPR 3 /* 0011??RB; RB */
#define COMPUTER_INSTR_JMP  4 /* 0100????+byte; total size 2 */
#define COMPUTER_INSTR_JXXX 5 /* 0101CAEZ+byte; total size 2 */
#define COMPUTER_INSTR_CLF  6 /* 0110????; -- */
#define COMPUTER_INSTR_IO   7 /* 0111[IO][DA]RB; RB */
#define COMPUTER_INSTR_NR   8

#define COMPUTER_IO_INPUT  0
#define COMPUTER_IO_OUTPUT 1
#define COMPUTER_IO_DATA 0
#define COMPUTER_IO_ADDR 1

extern char const *computer_reg_name[COMPUTER_REG_NR];
extern char const *computer_alu_op_name[COMPUTER_ALU_OP_NR];
extern char const *computer_instr_name[COMPUTER_INSTR_NR];

typedef struct computer computer;

struct computer {
    unsigned char mar;
    unsigned char ram[COMPUTER_RAM_SIZE];
    unsigned char reg[COMPUTER_REG_NR];
    unsigned char ir, iar, tmp, acc, flags;
    unsigned char io_addr;
    void (*io_output[COMPUTER_ADDR_SIZE])(computer *, unsigned char);
    void (*io_input[COMPUTER_ADDR_SIZE])(computer *, unsigned char *);

    unsigned long clock_cycle;
    int is_running;
};

void computer_reset(computer *comp);
int computer_is_running(computer *comp);
/* Step a single clock cycle */
void computer_step_cycle(computer *comp);
/* Step an entire instruction */
void computer_step_instruction(computer *comp);

#endif

