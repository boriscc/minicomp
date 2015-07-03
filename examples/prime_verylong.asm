# This program will take a very long time, but theoretically it will print
# all primes < 2^32 = 4,294,967,296. The idea is:
#   print 2
#   print 3
#   for n = 5 to 2^32-1, alternating step 2 and 4
#       for m = 5 to min(n-1, 2^16-1), alternating step 2 and 4
#           if n % m == 0: not prime, test next n
#       print n
#   exit
# For git version d1ecada, I made the following estimates for this program:
# Total number of clock-cycles: 2.957e+13
# Clock-cycles per natural number: 6.885e+03
# Clock-cycles per tested number: 2.065e+04
# Total time @ 1 GHz : 1.87 months
#   (i.e. 1 giga-instructions per second, 1 instr = 6 clock cycles)

# Numbers larger than 8 bit are stored as x0, x1, x2, ..., with x0 being the least
# significant byte.

# Print "2\n3\n"
# I have some data locations here that do not need initial values.
# This is a good place since these first lines of code are only executed
# once in the beginning.
# R16 contains the remainder after the long division n32 / m16
R1:
R0:: # double :: means the position after this position
data rc 2
# m16 is the number to divide n32 with, if the remainder is zero, n32 is not prime
m1:
outa rc # ASCII printer
m0:
# m_add contains the number to increase m16 with. Will alternate between 4 and 2, so
# that both even numbers and numbers divisible by three are omitted.
m_add:: # must be directly after m0
data rc '2'
outd rc # Print prime 2
# MODULE N_CUR_VAL
n_cur_val: # = *n_cur
# END MODULE N_CUR_VAL
# n32_larger_than_16 is set to != 0 when n32 >= 2^16. This is needed for the evaluation
# of n32 == m16, which is needed so that the m16 loop stops before it reaches n32
n32_larger_than_16::
data rd 10
outd rd # new line
data rc '3'
outd rc # Print prime 3
outd rd # new line
jmp  $next_n

# Same as m_add, but for n32
n_add:
. 4
# n32 is for the outer loop, each n32 is then divided by m16, and if all divisions have
# remainder != 0, then n32 is prime.
# Any n32 value can be entered as start value, as long as n32 - 1 is divisible by 6.
n3:
. 0
n2:
. 0
n1:
. 0
PRAGMA POS 19
n0: # this must be position 19
. 1
# n_cur is a pointer to the current byte in n32 that is looped over when doing
# long division n32 / m16
n_cur:
. 0

# Routine to print n32 when it is a prime
is_prime: # REG: (*, *, *, 0), FLAG: *
# 20 bytes
  data ra 32
  outa ra # 32-bit integer printer
  data ra $n0
  data rb $n_add # Used to terminate the loop
  not  rd rc # rc = 11111111
print_again:
  ld   ra rd # load current n32 byte
  outd rd # send it to printer
  add  rc ra # ra = ra - 1
  cmp  ra rb # To see if we should terminate the loop
  ja   $print_again
  data ra 2
  outa ra # ASCII printer
  data ra 10
  outd ra # Print new line

# Here we start with the next n32 value to test for primality
next_n: # REG: (*, *, *, *), FLAG: C UNSET, REST *
  # Set rd = number to add. Store next adder
  data rb $n_add
  ld   rb rd # rd = number to add, either 2 or 4
  data ra 6
  xor  rd ra # ra: 2->4, 4->2 = next add
  st   rb ra # store next add

  # n32 = n32 + 2 or 4
  # 16 bytes (+3 further down to set rb)
  # No loop requires 22 bytes
  # This loop is a bit strange due to the limitation of only four registers, therefore
  # I store a needed carry in ra, which is <= 38 so I can left shift ra and use LSB
  # to store the carry.
  data ra 38 # 2 * $n0 = 2 * 19, times 2 to store carry in LSB
  shl  rb rb # needed since 2*addr will be compared to rb
add_again:
  shr  ra ra # restore ra and set carry
  ld   ra rc # rc = *nx
  add  rd rc
  st   ra rc
  shl  ra ra # Store carry bit, carry will be 0
  data rd 11111110 # -2 -- not -1 since ra is multiplied by two (shifted left once)
  add  rd ra
  xor  rd rd # To add only the carry in the coming additions
  cmp  ra rb
  ja   $add_again

  # Terminate if overflow
  # This works since rb will be larger than ra only if
  # ra has a carry in the LSB from the last add.
  cmp  rb ra
  ja   $done

  # Here rc = *n3
  data rb $n2
  ld   rb rb # rb = *n2
  # set n32_larger_than_16 (0 if n32 < 2^16, otherwise > 0)
  or   rb rc # will be > 0 if either *n2 > 0 or *n3 > 0
  data ra $n32_larger_than_16
  st   ra rc # Stores a values > 0 if n32 >= 2^16

  # Set m16 = 1
  # rd will be 0 here, from the loop above
  data ra $m1
  st   ra rd # *m1 = 0
  data rd 1
  add  rd ra # ra = &m0
  st   ra rd # *m0 = 1

  # Set m_add to 4
  add   rd ra # ra = &m_add
  data  rc 4
  st    ra rc

# Set the next m16 value and see if it divides n32
next_m: # REG: (*, *, *, *), FLAG: C UNSET
  # m16 = m16 + 2 or 4, and also check if m16 == n32
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
# Do the final check to see that *n3 == *n2 == 0
check_if_m_equal_n: # REG: (*, *, *, *), FLAG: *
  data rd $n32_larger_than_16
  ld   rd rd
  or   rd rd
  # if m16 == n32, then n32 is prime.
  jz   $is_prime

# Set R16 = 0 and begin the long division n32 / m16
set_R_16_zero: # REG: (*, *, *, *), FLAG: *
  # Set R16 = 0
  xor  rd rd
  data ra $R0
  st   ra rd
  data ra $R1
  st   ra rd

  # Set *n_cur = &n3, then *n_cur will decrease until past n0 and then the
  # long division is done.
  data ra $n_cur
  data rb $n3
  st   ra rb

# MODULE N_CUR_VAL
  # Set *n_cur_val = **n_cur, for faster access (actually increases performance)
  data ra $n_cur_val
  ld   rb rc
  st   ra rc
# END MODULE N_CUR_VAL

# MODULE OPTIMIZE_POS
  # Decrease *pos as far as possible to decrease the loop iterations needed
  #ld   rb rc # rc = *n3 # comment if using N_CUR_VAL
  # Set *pos = 2^7
  data ra $pos
  data rb 10000000
  and  rc rc
  jz   $pre_pre_next_n_cur # if *n3 == 0, go directly to n2
optimize_pos:
  cmp  rc rb
  jae  $pre_next_pos # if *n3 >= *pos, then we are done decreasing *pos
  shr  rb rb # decrease pos
  jmp  $optimize_pos
# END MODULE OPTIMIZE_POS

next_n_cur: # REG: (*, *, *n_cur_val, *), FLAG: *
  # Set *pos = 2^7
  data ra $pos
  data rb 10000000
# MODULE OPTIMIZE_POS
pre_next_pos:
# END MODULE OPTIMIZE_POS
  st   ra rb

# Start of the inner most loop
next_pos: # REG: (&pos, *pos, *n_cur_val, *), FLAG: *
  # If *pos & *n_cur_val (**n_cur): set carry
  and  rb rc
  add  rc ra # Since &pos = 11111111, this will set carry if rc > 0
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
  ja   $dont_subtract # Most of the times it will jump here
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

# Part of the inner most loop. Update pos 
dont_subtract: # REG: (*, *, *, *), FLAG: C UNSET, REST *
  # pos >>= 1
  data ra $pos
  ld   ra rb
  shr  rb rb
  st   ra rb
  jc   $pre_next_n_cur # if this n_cur is done, jump (not so often)
# Fetch *n_cur_val in preparation of jump to next_pos
# MODULE N_CUR_VAL
  data rc $n_cur_val # Change to n_cur_val if using N_CUR_VAL (otherwise n_cur)
# END MODULE N_CUR_VAL
  ld   rc rc
# MODULE N_CUR_VAL
  #ld   rc rc # Add this if not using n_cur_val
# END MODULE N_CUR_VAL
  jmp  $next_pos # go to next iteration of inner-most loop
# MODULE OPTIMIZE_POS
pre_pre_next_n_cur:
  shl  rb rb # Will make rb = 0 and set carry
# END MODULE OPTIMIZE_POS
pre_next_n_cur: # REG: (*, 0, *, *), FLAG: C SET, REST *
  # Set *n_cur = *n_cur + 1
  data ra $n_cur
  ld   ra rd
  add  rb rd # Will add 1, since rb = 0 and carry is set
  st   ra rd # *n_cur++
# MODULE N_CUR_VAL
  # Set *n_cur_val = **n_cur
  data rb $n_cur_val
  ld   rd rc
  st   rb rc
# END MODULE N_CUR_VAL

  # See if there are more bytes of n to loop through
  cmp  ra rd
  ja   $next_n_cur # if &n_cur > *n_cur

# The remainder of n32 / m16 is now stored in R16, check if it is zero
calc_R_16_done: # REG: (*, *, *, *), FLAG: *
  data ra $R0
  ld   ra ra
  data rb $R1
  ld   rb rb
  or   ra rb
  jz   $next_n # The remainder is zero, so n32 is not a prime
  jmp  $next_m # non-zero remainder

done: # REG: (*, *, *, *), FLAG: *
  data rd 4
  outa rd # Power button
  outd rd

. 0
. 0
. 0
. 0
PRAGMA POS 11111111
pos: # this need to be pos 11111111
. 0
