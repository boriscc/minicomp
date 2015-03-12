# Prints hello world in a simple manner.
# Usage: Just run and "Hello, World!" will be printed.
ld   ra rc  # Will load address 0 into rc, address 0 = 00000010
outa rc # ASCII printer
data ra 'H'
outd ra
data ra 'e'
outd ra
data rd 'l'
outd rd
outd rd
data rb 'o'
outd rb
data ra ','
outd ra
data ra ' '
outd ra
data ra 'W'
outd ra
outd rb
data ra 'r'
outd ra
outd rd
data ra 'd'
outd ra
data ra '!'
outd ra
data ra 10 # new line
outd ra
shl  rc rc # 2 * 2 = 4
outa rc # Power button
outd rc
