# 32-bit values are stored with least significant bit first
origin:
. 0 # 00000000 = ld   ra ra
pV0:
. 236 # 11101100 = xor  rd ra
pK0:
. 244 # 11110100 = xor  rb ra -- i.e. ra = 1
cycle:
. 10110101 # = not  rb rb -- i.e. rb = 255
pK1:
. 252 # 11111100 = cmp  rd ra
get_next_V: # when getting here from jump, rb = rc = 255
  data rc 1
  outa rc # keyboard
  data rc $K2
  xor  rd rd # rd = 0
  not  rd rb # rb = 255 = -1
get_input:
  ind  ra
  or   ra ra # check if zero
  jz   $get_input
  add  rb rc # subtract -1, generates carry
  st   rc ra
  shl  rd rd # shift in carry, carry unset
  cmp  rb rd
  ja   $get_input
  data rb 6
  outa rb # hex-number printer
  # Set cycle = 0, since $cycle = 3, rb = 2*$cycle
  shr  rb rb
  # we will need a 1, so shr again
  shr  rb rc # rc = 1
  xor  ra ra
  st   rb ra
  # Set sum = 0
  data rb $sum
  data rd $V1
zero_sum_again:
  st   rb ra
  add  rc rb
  cmp  rd rb
  ja   $zero_sum_again
start_cycle:
  # sum += delta
  data ra $sum
  data rb $delta
  data rc $origin_1
  jmp  $binary_oper
origin_1:
start_half_cycle:
  # Implement: v0 += ((v1<<4) + k0) ^ (v1 + sum) ^ ((v1>>5) + k1)
  # A = B = C = V1, done in 24 bytes
  data ra $tmp_A # ra = tmp_A
  data rb 4
  data rc $pV0 # rc = &pV0
  ld   rc rc   # rc = pV0
  xor  rb rc   # rc = pV1
set_tmp_again:
  ld   rc rd   # rd = pV1[n]
  st   ra rd   # tmp_A[n] = pV1[n]
  add  rb ra   # ra = tmp_B + n
  st   ra rd   # tmp_B[n] = pV1[n]
  add  rb ra   # ra = tmp_C + n
  st   ra rd   # tmp_C[n] = pV1[n]
  data rd 249
  add  rd ra   # ra = ra + 249 = ra + (249 - 256) = ra - 7
  # carry will now be set
  data rd 0
  add  rd rc   # since carry is set, this will increase rc by 1
  data rd $tmp_B
  cmp  rd ra
  ja   $set_tmp_again
  # here, ra = $tmp_B = 11011000, rb = 00000100, rc = ?, rd = $tmp_B
  # A <<= 4
  xor  rc rc # rc = 0 = $origin
  st   rc ra # $origin = 11011000, i.e. after four shr a carry will be generated
  data rc 1
shift_left_again:
  data ra $tmp_A
shift_next_byte:
  shr  rb rb # restore carry
  ld   ra rb
  shl  rb rb
  st   ra rb
  shl  rb rb # store carry
  clf
  add  rc ra
  cmp  rd ra
  ja   $shift_next_byte
  # here, ra = $tmp_B, rb = 0 or 1, rc = 1, rd = $tmp_B
  xor  rb rb
  ld   rb ra
  shr  ra ra
  st   rb ra
  jc   $shift_left_done
  jmp  $shift_left_again
shift_left_done:
  # C >>= 5
  # A += K0
  data ra $tmp_A
  data rb $pK0
  ld   rb rb
  data rc $origin_2
  jmp  $binary_oper
origin_2:
  # here, ra = $tmp_A + 4 = $tmp_B
  # B += sum
  #data ra $tmp_B
  data rb $sum
  data rc $origin_3
  jmp  $binary_oper
origin_3:
  # here, ra = $tmp_B + 4 = $tmp_C
  # C += K1
  #data ra $tmp_C
  data rb $pK1
  ld   rb rb
  data rc $origin_4
  jmp  $binary_oper
origin_4:
  # A ^= B
  data ra $tmp_A_xor
  data rb $tmp_B
  data rc $origin_5
  jmp  $binary_oper
origin_5:
  # here, rb = $tmp_B + 4 = $tmp_C
  # A ^= C
  data ra $tmp_A_xor
  #data rb $tmp_C
  data rc $origin_6
  jmp  $binary_oper
origin_6:
  # V0 += A
  data ra $pV0
  ld   ra ra
  data rb $tmp_A
  data rc $origin_7
  jmp  $binary_oper
origin_7:
  # The half cycle is now done, switch V0/V1, K0/K2 and K1/K3
  data rd 4
  data ra $pV0
switch_again:
  ld   ra rb # rb = &V0 or &V1 in the first iteration
  xor  rd rb # if rb was &V0, it will now be &V1, and vice versa
  st   ra rb # store new rb back to $pV0
  shl  ra ra # make ra point to the next variable to switch
  cmp  rd ra
  jae  $switch_again # if ra <= 4, make the jump
  # Check if we have done both half cycles
  # Here, rb will be either $K1 or $K3, and rd will be 4
  # If rb is $K1, we have done both half cycles
  # $K1 = 11111100, $K3 = 11111000
  # That means that if rb & rd is zero, rb is $K3, and we are not done
  and  rb rd
  jz   $start_half_cycle
  # If we get here, we are done with both half cycles
  # Check if we should end the loop
  data ra 96 # = 3 * 32
  data rb $cycle # = 3
  ld   rb rd # rd = 3 * number of completed cycles
  add  rb rd # rd += 3
  st   rb rd
  cmp  ra rd
  ja   $start_cycle
  # If we get gere, we are done with the encryption
  # Print the encrypted value
  data ra $K2
  xor  rc rc
  not  rc rb # rb = 255 = -1
print_again:
  add  rb ra # subtract 1, will generate carry
  ld   ra rd
  outd rd
  shl  rc rc # carry will be shifted in, carry unset
  cmp  rc rb
  # when equal, ra = $V1, rb = 255, rc = 255, rd = random
  je   $get_next_V
  jmp  $print_again
binary_oper: # (ra=&a | oper, rb=&b, rc=&origin, on ret: a = a OP b)
             # requires: &a % 4 == &b % 4 == 0
             # oper = 0 means addition
             # oper = 1 means xor
             # on output, ra, rb, rc, rd =
             # &a + 4, &b + 4, &origin, 0
             # ra must be < 252, i.e. ra can not be $K1
  # Store &origin at $origin
  xor  rd rd # $origin = 0, so rd = $origin
  st   rd rc
  # Set the correct operation
  shr  ra ra # will set carry if oper is xor
  data rd 105 # $oper_add / 2
  add  rd rd # = $oper_add + carry
  ld   rd rd
  data rc $binary_oper_impl
  st   rc rd # *$binary_oper_impl = *($oper_add + carry)
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
  data rc $origin # ra = &origin
  ld   rc rc # ra = origin
  jmpr rc    # jump to $origin
# filling
PRAGMA POS 210
oper_add:
  add  rc rd
oper_xor:
  xor  rc rd
PRAGMA POS 212
tmp_A:
. 0
tmp_A_xor:
. 0
. 0
. 0
tmp_B: # 216 = 11011000
. 0
. 0
. 0
. 0
tmp_C:
. 0
. 0
. 0
. 0
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
