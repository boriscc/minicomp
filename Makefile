GCC ?= gcc

CFLAGS = -O2 -funroll-loops -std=gnu99 -Wall -pedantic -W -Wextra -Werror -Wno-unused-parameter -Wno-unknown-pragmas -Wconversion -Wshadow -Wpointer-arith -Wcast-align -Wwrite-strings -ggdb3 -Wno-format-security
EX_DIR = examples
EX = hello_world.asm alphabet.asm add_from_keyboard.asm prime.asm mastermind.asm prime_long.asm prime_verylong.asm 2048game.asm tea_encrypt.asm caesar_cipher.asm
CEX = prime_verylong.casm
EX_ASM_FILES = $(patsubst %,$(EX_DIR)/%,$(EX))
EX_RAM_FILES = $(patsubst %.asm,%.ram,$(EX_ASM_FILES))
CEX_ASM_FILES = $(patsubst %,$(EX_DIR)/%,$(CEX))
CEX_RAM_FILES = $(patsubst %.casm,%.cram,$(CEX_ASM_FILES))

-include Makefile.inc

all: simulator asm_compiler examples

simulator: simulator.o computer.o peri.o
	$(GCC) $(CFLAGS) $(LDFLAGS) $^ -o $@

asm_compiler: asm_compiler.o computer.o peri.o
	$(GCC) $(CFLAGS) $(LDFLAGS) $^ -o $@

examples: $(EX_RAM_FILES) $(CEX_RAM_FILES)

%.ram: %.asm asm_compiler
	./asm_compiler $< $@

%.cram: %.casm asm.py uv.lock pyproject.toml
	uv run python asm.py compile $< $@

%.o: %.c $(wildcard *.h) config.h
	$(GCC) $(CFLAGS) -c $< -o $@

config.h:
	$(error Run ./configure.sh first)

clean:
	-rm -f asm_compiler.o simulator.o computer.o peri.o asm_compiler simulator $(EX_RAM_FILES) $(CEX_RAM_FILES) config.h Makefile.inc

.PHONY: all clean examples
