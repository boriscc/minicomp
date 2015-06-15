#ifndef PERI_H_
#define PERI_H_

#include "computer.h"

#define PERI_ADDR_KEYBOARD 1
#define PERI_ADDR_ASCII_PRINTER 2
#define PERI_ADDR_INTEGER_PRINTER 3
#define PERI_ADDR_TERMINATE 4
#define PERI_ADDR_RANDOM 5
#define PERI_ADDR_INTEGER16_PRINTER 16
#define PERI_ADDR_INTEGER24_PRINTER 24
#define PERI_ADDR_INTEGER32_PRINTER 32

void peri_keyboard_buffered_input(computer *comp, unsigned char *key);
void peri_keyboard_unbuffered_input(computer *comp, unsigned char *key);

void peri_ascii_printer_output(computer *comp, unsigned char c);
void peri_integer_printer_output(computer *comp, unsigned char i);
void peri_integer16_printer_output(computer *comp, unsigned char i);
void peri_integer24_printer_output(computer *comp, unsigned char i);
void peri_integer32_printer_output(computer *comp, unsigned char i);

void peri_terminate_output(computer *comp, unsigned char c);

void peri_random_input(computer *comp, unsigned char *rnd);

#endif

