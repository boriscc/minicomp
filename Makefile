GCC ?= gcc
USE_TIMING = 1
USE_SIGNAL = 1
USE_NCURSES = 0
DEBUG = 0

CFLAGS = -O2 -funroll-loops -std=gnu99 -Wall -pedantic -W -Wextra -Werror -Wno-unused-parameter -Wno-unknown-pragmas -Wconversion -Wshadow -Wpointer-arith -Wcast-align -Wwrite-strings -ggdb3
EX_DIR = examples
EX = hello_world.asm alphabet.asm add_from_keyboard.asm mastermind.asm
EX_ASM_FILES = $(patsubst %,$(EX_DIR)/%,$(EX))
EX_RAM_FILES = $(patsubst %.asm,%.ram,$(EX_ASM_FILES))

ifeq ($(USE_TIMING), 1)
    CFLAGS += -DHAVE_TIMING
    LDFLAGS += -lrt
endif

ifeq ($(USE_SIGNAL), 1)
    CFLAGS += -DHAVE_SIGNAL
endif

ifeq ($(USE_NCURSES), 1)
    CFLAGS += -DHAVE_NCURSES
    LDFLAGS += -lncurses
endif

ifeq ($(DEBUG), 1)
    CFLAGS += -DDEBUG
endif

all: simulator asm_compiler examples

simulator: simulator.o computer.o peri.o
	$(GCC) $(CFLAGS) $(LDFLAGS) $^ -o $@

asm_compiler: asm_compiler.o computer.o peri.o
	$(GCC) $(CFLAGS) $(LDFLAGS) $^ -o $@

examples: $(EX_RAM_FILES)

%.ram: %.asm asm_compiler
	./asm_compiler $< $@

%.o: %.c $(wildcard *.h)
	$(GCC) $(CFLAGS) -c $< -o $@

clean:
	-rm -f asm_compiler.o simulator.o computer.o peri.o asm_compiler simulator $(EX_RAM_FILES)

.PHONY: all clean examples
