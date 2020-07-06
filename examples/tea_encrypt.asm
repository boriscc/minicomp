origin:
. 0 # 00000000 = ld   ra ra
pV0:
. 232 # 11101000 = xor  ra rd
pK0:
. 240 # 11110000 = xor  rc rd
cycle:
. 0 # 00000000 = ld   ra ra
pK1:
. 248 # 11111000 = cmp  rb rd
get_next_V:
  clf
  data rc $V0
  data ra 1
  data rd 1
  outa ra # keyboard
get_input:
  ind  rb
  or   rb rb
  jz   $get_input
  st   rc rb
  add  ra rc # add 1
  shl  rd rd
  jc   $have_next_V
  jmp  $get_input
have_next_V:
  clf
  # cycle = sum = 0
  data ra $cycle
  data rc 1
  xor  rb rb
  st   ra rb
  add  rc ra
  st   ra rb
  add  rc ra
  st   ra rb
  add  rc ra
  st   ra rb
  add  rc ra
  st   ra rb
start_cycle:
  data ra 2
  outa ra
  data ra 'Q'
  outd ra
start_half_cycle:
  data ra 2
  outa ra
  data ra '-'
  outd ra
  # The half cycle is now done, switch V0/V1, K0/K2 and K1/K3
  data rd 4
  data ra $pV0
switch_again:
  ld   ra rb # rb = &V0 or &V1 in the first iteration
  xor  rd rb # if rb was &V0, it will now be &V1, and vice versa
  st   ra rb # store new rb back to $pV0
  shl  ra ra # make ra point to the next variable to switch
  cmp  ra rd
  ja   $done_switching # if ra is 8, make the jump
  jmp  $switch_again
done_switching:
  # Check if we have done both half cycles
  # Here, rb will be either $K1 or $K3, and rd will be 4
  # If rb is $K1, we have done both half cycles
  # $K1 = 11111000, $K3 = 11111100
  # That means that if rb & rd is zero, rb is $K1, and we are done
  and  rb rd
  jz   $half_cycles_done
  jmp  $start_half_cycle
half_cycles_done:
  # If we get here, we are done with both half cycles
  # Check if we should end the loop
  data ra 32
  data rb $cycle
  data rc 1
  ld   rb rd # rd = number of completed cycles
  add  rc rd # rd = updated number of completed cycles
  st   rb rd
  cmp  ra rd
  ja   $start_cycle
  # If we get gere, we are done with the encryption
  # Print the encrypted value
  data ra 6
  outa ra # hex-number printer
  data ra $V0
  data rb 1
  data rc 1
print_again:
  ld   ra rd
  outd rd
  add  rb ra # add 1
  shl  rc rc
  jz   $get_next_V
  jmp  $print_again
# Filling
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
PRAGMA POS 224
delta:
. 0x9e
. 0x37
. 0x79
. 0xb9
sum:
. 0
. 0
. 0
. 0
V0: # 232
. 0
. 0
. 0
. 0
V1:
. 0
. 0
. 0
. 0
K0:
. 0
. 1
. 2
. 3
K2:
. 8
. 9
. 10
. 11
K1:
. 4
. 5
. 6
. 7
K3:
. 12
. 13
. 14
. 15
