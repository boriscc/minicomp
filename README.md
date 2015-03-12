The simulator simulates an 8-bit computer, described by J. Clark Scott in the
book "But how do it know?". simulator.c is an interface to the functions in
computer.c, where all functions to interpret and execute the machine code are.
Each clock cycle of the 8-bit computer is simulated. The simulation is on
register level, meaning that in each clock cycle, the correct registers and ram
locations are written/read according to the specification of the 8-bit
computer.

To compile, run

make

.asm-files are compiled with

./asm_compiler <.asm-file> <.ram-file>

.ram-files are run with

./simulator <.ram-file>

minicomp consists of two programs:

simulator and asm_compiler

The asm compiler compiles assembler code into machine code for the 8-bit
computer. See the example in examples/ to get a hang on the syntax. It is
basically the same as described in the book. The only extensions are that
numbers can be writen in several ways, it is possible to use labels, it is
possible to store data and comments can be inserted.

All numbers can be written in any of the following forms:
  * Binary, eight zeros and ones, e.g. 00100111
  * Decimal, e.g. 34 or 0 or 255.
  * Hexadecimal, e.g. 0xa0, 0x4
  * ASCII value of character, e.g. 'a', '0', '='
  * Numerical value of label, e.g. $myLabel, $start
All numbers must be in the rand [0, 255], otherwise there will be a compile
error.

Labels are defined by a single word with a colon at the end, e.g.:
myLabel:
start:
All labels are case insensitive, the same goes for operators and register
names.

Data is stored using a line of the form
. Number
where Number should be replaced by a number in the format above.

Comments are started with a #. Everything after the first # on a line is
ignored by the compiler.
