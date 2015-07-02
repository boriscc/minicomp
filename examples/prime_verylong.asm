# This program will take forever, but theoretically it will print
# all primes < 2^32 = 4,294,967,296. The idea is:
#   print 2
#   for n = 3 to 2^32-1, step 2
#       for m = 3 to min(n-1, 2^16-1), step 2
#           if n % m == 0: not prime, test next n
#       print n
#   exit

# Print "2\n3\n"
R1:
R0::
data rc 2
pos:
outa rc # ASCII printer
m1:
m0::
data rc '2'
m_add:
outd rc
# MODULE N_CUR_VAL
n_cur_val:
# END MODULE N_CUR_VAL
n32_larger_than_16::
data rd 10
outd rd
data rc '3'
outd rc
outd rd
jmp  $next_n

prime_add:
. 4
n3:
. 0
n2:
. 0
n1:
. 0
n0: # this is position 19
. 1
n_cur:
. 0

is_prime: # REG: (*, *, *, 0), FLAG: *
# 20 bytes
  data ra 32
  outa ra # 32-bit integer printer
  data ra $n0
  data rb $prime_add
  not  rd rc # rc = 11111111
print_again:
  ld   ra rd
  outd rd
  add  rc ra
  cmp  ra rb
  ja   $print_again
  data ra 2
  outa ra # ASCII printer
  data ra 10
  outd ra # Print new line

next_n: # REG: (*, *, *, *), FLAG: C UNSET, REST *
  # Set rd = number to add. Store next adder
  data rb $prime_add
  ld   rb rd # rd = number to add
  data ra 6
  xor  rd ra # ra: 2->4, 4->2 = next add
  st   rb ra # store next add

  # n32 = n32 + 2 or 4
  # 16 bytes (+3 further down to set rb)
  # No loop requires 22 bytes
  data ra 38 # 2 * $n0
  shl  rb rb # needed since 2*addr will be compared to rb
add_again:
  shr  ra ra
  ld   ra rc
  add  rd rc
  st   ra rc
  shl  ra ra # Store carry bit, carry will be 0
  data rd 11111110
  add  rd ra
  xor  rd rd
  cmp  ra rb
  ja   $add_again
  shr  ra ra # to set carry

  # Terminate if overflow
  jc   $done

  # Here rc = *n3
  data rb $n2
  ld   rb rb # rb = *n2
  # set n32_larger_than_16 (0 if n32 < 2^16, otherwise > 0)
  or   rb rc
  data ra $n32_larger_than_16
  st   ra rc # Stores a values > 0 if n32 >= 2^16

  # Set m16 = 1
  xor  rb rb
  data ra $m1
  st   ra rb # *m1 = 0
  data rb 1
  add  rb ra # ra = &m0
  st   ra rb # *m0 = 1

  # Set m_add to 4
  add   rb ra # ra = &m_add
  data  rc 4
  st    ra rc

next_m: # REG: (*, *, *, *), FLAG: C UNSET
  # m16 = m16 + 2 or 4
  data rb $m_add
  ld   rb rd # rd = current add
  data ra 6
  xor  rd ra # ra: 2->4, 4->2 = next add
  st   rb ra # store next add
  data ra $m0
  ld   ra rb
  add  rd rb
  st   ra rb
  data rc $n0
  ld   rc rc
  shl  rd rd # to store carry bit
  xor  rb rc # rc = 0 means *n0 == *m0
  shr  rd rd # restore carry bit
  data rd 0
  data ra $m1
  ld   ra rb
  add  rd rb
  jc   $is_prime
  st   ra rb
  data ra $n1
  ld   ra ra
  xor  rb ra # ra = 0 means *n1 == *m1
  or   rc ra # ra = 0 means *n0 == *m0 && *n1 == *m1
  jz   $check_if_m_equal_n
  jmp  $set_R_16_zero
# MODULE NEXT_M_MOD
###next_m_mod:
###  xor  rc rc
###  data rd 2
###  data ra $m0
###  ld   ra rb
###  add  rd rb
###  st   ra rb
###  data ra $m1
###  ld   ra rb
###  add  rc rb
###  jc   $is_prime
###  st   ra rb
###  jmp  $set_R_16_zero
# END MODULE NEXT_M_MOD
check_if_m_equal_n: # REG: (*, *, *, *), FLAG: *
  data rd $n32_larger_than_16
  ld   rd rd
  or   rd rd
  jz   $is_prime
# MODULE NEXT_M_MOD
###  # We no longer need to compare n and m, so use next_m_mod instead.
###  data ra $next_m_jump_data
###  data rb $next_m_mod
###  st   ra rb
# END MODULE NEXT_M_MOD

set_R_16_zero: # REG: (*, *, *, *), FLAG: *
  # Set R16 = 0
  xor  rd rd
  data ra $R0
  st   ra rd
  data ra $R1
  st   ra rd

  # Set *n_cur = &n3
  data ra $n_cur
  data rb $n3
  st   ra rb

# MODULE N_CUR_VAL
  # Set *n_cur_val = **n_cur
  data ra $n_cur_val
  ld   rb rd
  st   ra rd
# END MODULE N_CUR_VAL

# MODULE OPTIMIZE_POS
  #ld   rb rd # rd = *n3 # comment if using N_CUR_VAL
  # Set *pos = 2^7
  data ra $pos
  data rb 10000000
  and  rd rd
  jz   $pre_pre_next_n_cur
optimize_pos:
  cmp  rd rb
  jae  $pre_next_pos
  shr  rb rb
  jmp  $optimize_pos
# END MODULE OPTIMIZE_POS

next_n_cur: # REG: (*, *, *, *), FLAG: *
  # Set *pos = 2^7
  data ra $pos
  data rb 10000000
pre_next_pos:
  st   ra rb

next_pos: # REG: (&pos, *pos, *, *), FLAG: *
  # If *pos & *n_cur_val (**n_cur): set carry
# MODULE N_CUR_VAL
  data rc $n_cur_val # Change to n_cur_val if using N_CUR_VAL (otherwise n_cur)
# END MODULE N_CUR_VAL
  ld   rc rc
# MODULE N_CUR_VAL
  #ld   rc rc # Add this if not using n_cur_val
# END MODULE N_CUR_VAL
  and  rb rc
  jz   $dont_set_carry
  data rb 1
  shr  rb rb # Will set carry
dont_set_carry: # REG (*, *, *, *), FLAG: C ?, REST *
  # R16 <<= 1
  data ra $R0
  ld   ra rb
  shl  rb rb # rb = *R0
  st   ra rb
  data rc $R1
  ld   rc rd
  shl  rd rd # rd = *R1
  st   rc rd

  # If overflow in R16 or R16 >= m16: R16 = R16 - m16
  jc   $subtract_m16
  data rc $m1
  ld   rc rc # rc = *m1
  # Compare *m1 >? *R1
  cmp  rc rd
  ja   $dont_subtract
  je   $check_lowbit
  jmp  $subtract_m16_post
check_lowbit: # REG: (*, *R0, *, *R1), FLAG: *
  data ra $m0
  ld   ra ra # ra = *m0
  cmp  ra rb
  ja   $dont_subtract
subtract_m16: # REG: (*, *R0, *, *R1), FLAG: *
  # Load m16
  data rc $m1
  ld   rc rc # rc = *m1
subtract_m16_post: # REG: (*, *R0, *m1, *R1), FLAG: *
  data ra $m0
  ld   ra ra # ra = *m0

  # R16 = R16 + (~m16 + 1)
  # ~m16
  not  ra ra
  not  rc rc
  # add ~m16
  add  ra rb
  add  rc rd
  # add 1
  data ra 1
  xor  rc rc
  add  ra rb
  add  rc rd
  clf
  data rc $R1
  st   rc rd
  add  ra rc
  st   rc rb

dont_subtract: # REG: (*, *, *, *), FLAG: C UNSET, REST *
  # pos >>= 1
  data ra $pos
  ld   ra rb
  shr  rb rb
  st   ra rb
  jc   $pre_next_n_cur
  jmp  $next_pos
# MODULE OPTIMIZE POS
pre_pre_next_n_cur:
  shl  rb rb # Will make rb = 0 and set carry
# END MODULE POTIMIZE POS
pre_next_n_cur: # REG: (*, 0, *, *), FLAG: C SET, REST *
  # Set *n_cur = *n_cur + 1
  data ra $n_cur
  ld   ra rc
  add  rb rc # Will add 1, since rb = 0 and carry is set
  st   ra rc # *n_cur++
# MODULE N_CUR_VAL
  # Set *n_cur_val = **n_cur
  data rd $n_cur_val
  ld   rc rb
  st   rd rb
# END MODULE N_CUR_VAL

  # See if there are more bytes of n to loop through
  cmp  ra rc
  ja   $next_n_cur # if &n_cur > *n_cur

calc_R_16_done: # REG: (*, *, *, *), FLAG: *
  data ra $R0
  ld   ra ra
  data rb $R1
  ld   rb rb
  or   ra rb
  jz   $next_n
# MODULE NEXT_M_MOD
###next_m_jump_data::
# END MODULE NEXT_M_MOD
  jmp  $next_m

done: # REG: (*, *, *, *), FLAG: *
  data rd 4
  outa rd # Power button
  outd rd

