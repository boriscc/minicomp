# This program will take forever, but theoretically it will print
# all primes < 2^32 = 4,294,967,296. The idea is:
#   print 2
#   for n = 3 to 2^32-1, step 2
#       for m = 3 to min(n-1, 2^16-1), step 2
#           if n % m == 0: not prime, test next n
#       print n
#   exit

# Print 2
data ra 3
outa ra
data ra 2
outd ra # Print 2
outa ra # ASCII printer
data ra 10
outd ra # Print new line

next_n: # REG: (*, *, *, *), FLAG: *
  # n32 = n32 + 2
  # TODO: Can be turned into a loop to save space
  # TODO: jc can be used to end adding when no more carry
  clf
  data rd 2
  data ra $n0
  ld   ra rb
  add  rd rb
  st   ra rb
  data rd 0
  data ra $n1
  ld   ra rb
  add  rd rb
  st   ra rb
  data ra $n2
  ld   ra rb
  add  rd rb
  st   ra rb
  data ra $n3
  ld   ra rc
  add  rd rc
  st   ra rc

  # Terminate if overflow
  jc   $done

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

next_m: # REG: (*, *, *, *), FLAG: *
  # m16 = m16 + 2
  clf
  data rd 2
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
check_if_m_equal_n: # REG: (*, *, *, *), FLAG: *
  data ra $n32_larger_than_16
  ld   ra ra
  or   ra ra
  jz   $is_prime

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

next_n_cur: # REG: (*, *, *, *), FLAG: *
  # Set *pos = 2^7
  data ra $pos
  data rb 10000000
  st   ra rb

next_pos: # REG: (*, *, *, *), FLAG: *
  # If *pos & *n_cur: set carry
  data ra $pos
  ld   ra ra
  data rb $n_cur
  ld   rb rb
  ld   rb rb
  and  ra rb
  jz   $dont_set_carry
  data rb 1
  shr  rb rb # Will set carry
dont_set_carry: # REG (*, *, *, *), FLAG: *
  # R16 <<= 1
  data ra $R0
  ld   ra rb
  shl  rb rb # rb = *R0
  st   ra rb
  data rc $R1
  ld   rc rd
  shl  rd rd # rd = *R1
  st   rc rd

  # Load m16
  data ra $m0
  ld   ra ra # ra = *m0
  data rc $m1
  ld   rc rc # rc = *m1

  # If overflow in R16 or R16 >= m16: R16 = R16 - m16
  jc   $subtract_m16
  # Check if R16 >= m16
  cmp  rd rc
  ja   $subtract_m16
  je   $check_lowbit
  jmp  $dont_subtract
check_lowbit: # REG: (*m0, *R0, *m1, *R1), FLAG: *
  cmp  ra rb
  ja  $dont_subtract
subtract_m16: # REG: (*m0, *R0, *m1, *R1), FLAG: *
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

dont_subtract: # REG: (*, *, *, *), FLAG: *
  # pos >>= 1
  clf
  data ra $pos
  ld   ra rb
  shr  rb rb
  st   ra rb
  jc   $pre_next_n_cur
  jmp  $next_pos
pre_next_n_cur: # REG: (*, 0, *, *), FLAG: C SET, REST *
  # Set *n_cur = *n_cur + 1
  data ra $n_cur
  ld   ra rc
  add  rb rc # Will add 1, since rb = 0 and carry is set
  st   ra rc # *n_cur++

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
  jmp  $next_m

is_prime: # REG: (*, *, *, *), FLAG: *
  # TODO: Print n
  data ra 32
  outa ra # 32-bit integer printer
  data ra $n0
  ld   ra ra
  outd ra # Send first byte
  data ra $n1
  ld   ra ra
  outd ra # Send second byte
  data ra $n2
  ld   ra ra
  outd ra # Send third byte
  data ra $n3
  ld   ra ra
  outd ra # Send fourth byte, will print
  data ra 2
  outa ra # ASCII printer
  data ra 10
  outd ra # Print new line
  jmp  $next_n

done: # REG: (*, *, *, *), FLAG: *
  data rd 4
  outa rd # Power button
  outd rd

n3:
. 0
n2:
. 0
n1:
. 0
n0:
. 1
n_cur:
. 0
n32_larger_than_16:
. 0
m1:
. 0
m0:
. 0
R1:
. 0
R0:
. 0
pos:
. 0
