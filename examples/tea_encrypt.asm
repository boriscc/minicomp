origin:
. 0 # 00000000 = ld   ra ra
pV0:
. 236 # 11101100 = xor  rd ra
pK0:
. 244 # 11110100 = xor  rb ra
cycle:
. 0 # 00000000 = ld   ra ra
pK1:
. 252 # 11111100 = cmp  rd ra
get_next_V:
  data rc 1
  outa rc # keyboard
  data rc $K2
  xor  rd rd # rd = 0
  not  rd ra # ra = 255 = -1
get_input:
  ind  rb
  or   rb rb
  jz   $get_input
  add  ra rc # subtract -1, generates carry
  st   rc rb
  shl  rd rd # shift in carry, carry unset
  cmp  ra rd
  ja   $get_input
  # Set cycle = 0
  data ra $cycle
  xor  rb rb
  st   ra rb
  # Set sum = 0
  data ra $sum
  data rc 1
  st   ra rb
  add  rc ra
  st   ra rb
  add  rc ra
  st   ra rb
  add  rc ra
  st   ra rb
start_cycle:
  # sum += delta
  data ra $sum
  data rb $delta
  data rc $origin_1
  jmp  $binary_oper
origin_1:
  data ra 6 # DEBUG
  outa ra # DEBUG
  data ra 231 # DEBUG
  ld   ra ra
  outd ra # DEBUG
start_half_cycle:
  # FOR TESTING: V0 += K0
  #data ra $pV0
  #ld   ra ra
  #data rb $pK0
  #ld   rb rb
  #data rc $origin_2
  #jmp  $binary_oper
  data ra 2 # DEBUG
  outa ra # DEBUG
  data ra '-' # DEBUG
  outd ra # DEBUG
origin_2:
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
  # $K1 = 11111100, $K3 = 11111000
  # That means that if rb & rd is zero, rb is $K3, and we are not done
  and  rb rd
  jz   $start_half_cycle
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
  data ra $K2
  xor  rc rc
  not  rc rb # rb = 255 = -1
print_again:
  add  rb ra # subtract 1, will generate carry
  ld   ra rd
  outd rd
  shl  rc rc # carry will be shifted in, carry unset
  cmp  rc rb
  je   $get_next_V
  jmp  $print_again
binary_oper: # (ra=&a | oper, rb=&b, rc=&origin, on ret: a = a OP b)
             # requires: &a % 4 == &b % 4 == 0
             # oper = 0 means addition
             # oper = 1 means xor
  # Store &origin at $origin
  xor  rd rd # $origin = 0, so rd = $origin
  st   rd rc
  # Set the correct operation
  shr  ra ra # will set carry if oper is xor
  data rd 111 # $oper_add / 2
  add  rd rd # = $oper_add + carry
  ld   rd rd
  data rc $binary_oper_impl
  st   rc rd # *$binary_oper_impl = *($oper_add + carry)
  xor  rd rd
  # Remove the carry if set
  clf
  # Restore ra to the correct address
  shl  ra ra
binary_oper_loop:
  ld   ra rc # ra = &a[n], rc = a[n]
  ld   rb rd # rb = &b[n], rd = b[n]
binary_oper_impl:
  add  rc rd # rd += rc
  shl  rc rc # LSB of rc will contain carry flag from oper above
  clf        # in case the shl set the carry flag
  st   ra rd # a[n] = a[n] OP b[n]
  data rd 1  # rd = 1
  add  rd ra # ra = &a[n+1]
  add  rd rb # rb = &b[n+1]
  # See if we are done
  data rd 3  # rd = 3
  and  ra rd
  jz   $binary_oper_end
  shr  rc rc  # restore carry flag
  jmp  $binary_oper_loop
binary_oper_end:
  clf
  data ra $origin # ra = &origin
  ld   ra ra # ra = origin
  jmpr ra    # jump to $origin
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
PRAGMA POS 222
oper_add:
  add  rc rd
oper_xor:
  xor  rc rd
PRAGMA POS 224
delta:
. 0xb9
. 0x79
. 0x37
. 0x9e
sum:
. 0
. 0
. 0
. 0
V1: # 232
. 0
. 0
. 0
. 0
V0:
. 0
. 0
. 0
. 0
K2: # 240
. 11
. 10
. 9
. 8
K0:
. 3
. 2
. 1
. 0
K3:
. 15
. 14
. 13
. 12
K1:
. 7
. 6
. 5
. 4
