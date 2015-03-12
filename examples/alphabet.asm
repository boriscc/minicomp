# Prints the alphabet
# Shows how a basic loop can look.
# Usage: Just run and the alphabet will be printed.

ld   ra rc  # Will load address 0 into rc, address 0 = 00000010
outa rc # ASCII printer

data ra 'a' # First letter
data rb 'z' # Last letter
data rd 1   # Step

loop:
  outd ra # Print ra
  cmp ra rb
  je $end_loop # If we have reached the last letter
  add rd ra # ra++
  jmp $loop

end_loop:
  data ra 10
  outd ra # Print new line

# Shut down
shl  rc rc # 2 * 2 = 4
outa rc # Power button
outd rc
