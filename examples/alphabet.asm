ld   ra rc  # Will load address 0 into rc, address 0 = 00000010
outa rc

data ra 'a' # First letter
data rb 'z' # Last letter
data rd 1   # Step

loop:
  outd ra
  cmp ra rb
  je $end_loop
  add rd ra
  jmp $loop

end_loop:
  data ra 10
  outd ra

# Shut down
shl  rc rc # 2 * 2 = 4
outa rc
outd rc
