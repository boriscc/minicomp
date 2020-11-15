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

./asm\_compiler <.asm-file> <.ram-file>

.ram-files are run with

./simulator <.ram-file>

minicomp consists of two programs:

simulator and asm\_compiler

The asm compiler compiles assembler code into machine code for the 8-bit
computer. See the example in examples/ to get a hang on the syntax. It is
basically the same as described in the book. The only extensions are that
numbers can be writen in several ways, it is possible to use labels, it is
possible to store data, comments can be inserted, and "PRAGMA POS" is
available.

All numbers can be written in any of the following forms:
  * Binary, eight zeros and ones, e.g. 00100111
  * Decimal, e.g. 34 or 0 or 255.
  * Hexadecimal, e.g. 0xa0, 0x4
  * ASCII value of character, e.g. 'a', '0', '='
  * Numerical value of label, e.g. $myLabel, $start
All numbers must be in the range [0, 255], otherwise there will be a compile
error.

Labels are defined by a single word with one or two colons at the end, e.g.:

myLabel:

start::

All labels are case insensitive, the same goes for operators and register
names. One colon means the label is for the following position in ram. Two
colons means it is for the position after the next. This can be useful if the
next assembler line takes up two bytes in ram.

Data is stored using a line of the form

. Number

where Number should be replaced by a number in the format above.

Comments are started with a #. Everything after the first # on a line is
ignored by the compiler.

One pragma is available:

PRAGMA POS <position>

which tells the compiler that the following ram location must be position
<position> in the ram, e.g. PRAGMA POS 12 means that the following position
must be ram location 12. The first location is position 0.

The registers are:
   * RA 00
   * RB 01
   * RC 10
   * RD 11

The flags:
   * C = carry, set if an ALU operation overflow, otherwise unset
   * A = A larger, set in all ALU comparisons if A is larger than B, otherwise unset
   * E = equal, set if A == B in an ALU operation
   * Z = zero, set if the result of an ALU operation is zero, otherwise unset

All ALU operations set A, E and Z to the corresponding value.
Except CMP which does not touch Z.
C is used and set/unset by ADD, SHR and SHL.
All other ALU operations will set C to zero.

The op-codes are as follows:

   * LD   0000RARB      -- set value of RB to value at RAM address RA
   * ST   0001RARB      -- set value at RAM address RA to value of RB
   * DATA 0010??RB+byte -- set value of RB to value of byte
   * JMPR 0011??RB      -- jump to RAM position RB
   * JMP  0100????+byte -- Jump to RAM position byte
   * JXXX 0101CAEZ+byte -- jump ro RAM position byte if at least one of the specified flags are set
   *     C = carry, A = larger, E = equal, Z = zero
   *     JEZ = jump if equal or zero, JCAEZ = jump if any of the flags is set, JC = jump if carry is set
   * CLF  0110????      -- Clear flags
   * IND  011100RB      -- Read data from current IO address and store in RB
   * INA  011101RB      -- Read current address and store in RB (cannot be done, so this is a NOOP)
   * OUTD 011110RB      -- Output contents of RB to the current IO address
   * OUTA 011111RB      -- Set IO address to value of RB
   * ADD  1000RARB      -- RB = RA + RB + C, C set if overflow
   * SHR  1001RARB      -- RB = (C << 7) + RA >> 1, C = RA & 1
   * SHL  1010RARB      -- RB = RA << 1 + C, C = RB >> 7
   * NOT  1011RARB      -- RB = !RA
   * AND  1100RARB      -- RB = RA & RB
   * OR   1101RARB      -- RB = RA | RB
   * XOR  1110RARB      -- RB = RA ^ RB
   * CMP  1111RARB      -- NOOP (flags are still set as described above)

The peripheral units that are connected are:

   * 1   keyboard (input only, sends next ascii code, 0 means no input available)
   * 2   ASCII printer (output only)
   * 3   integer printer (output only)
   * 4   terminate (output only, turns off the computer when it receives data)
   * 5   random number generator (input only, random uniform number)
   * 6   hexadecimal printer (output only)
   * 16  16-bit integer printer (output only, outputs when it has received 2 bytes)
   * 24  24-bit integer printer (output only, outputs when it has received 3 bytes)
   * 32  32-bit integer printer (output only, outputs when it has received 4 bytes)

