# The prime factors of 13195 are 5, 7, 13 and 29.
#
# What is the largest prime factor of the number 600851475143 ?

# Solution: A = 600... Loop n from 2 until done, while n divides A, A = A/n, if n == A: print A and exit
# A 40-bit number, n 16-bit number
# 600851475143 = 10001011 11100101 10001001 11101010 11000111
# Runs in 4171178 instructions

new_n:
  # Increase n
  data ra 2
  data rb $n0
  ld   rb rc
  add  ra rc
  st   rb rc
  data rb $n1
  data ra 0
  ld   rb rc
  add  ra rc
  st   rb rc

  # If n == A: goto $done
  data rb $A4
  ld   rb rb
  or   rb ra
  data rb $A3
  ld   rb rb 
  or   rb ra
  data rb $A2
  ld   rb rb 
  or   rb ra
  jz   $n_A_check1
  jmp  $new_division
n_A_check1:
  data rb $A1
  ld   rb rb 
  data rc $n1
  ld   rc rc
  cmp  rb rc
  je   $n_A_check0
  jmp  $new_division
n_A_check0:
  data rb $A0
  ld   rb rb 
  data rc $n0
  ld   rc rc
  cmp  rb rc
  je   $done

new_division:
  # Divide A by n, Q = A/n, R = A%n
  # A_index is a pointer to the current 
  # byte of A to test, starting with
  # the most significant byte
  data rd $A_index
  st   rd rd # *A_index = $A_index
  data rd $Q_index
  st   rd rd # *Q_index = $Q_index
  # Set R = 0
  xor  rb rb
  data rd $R0
  st   rd rb
  data rd $R1
  st   rd rb
  # Set Q = 0
  data rd $Q0
  st   rd rb
  data rd $Q1
  st   rd rb
  data rd $Q2
  st   rd rb
  data rd $Q3
  st   rd rb
  data rd $Q4
  st   rd rb

# See if n divides A, by calculating the remainder
start_long_div:
  clf # Get rid of carry

  data ra 1
  data rc $Q_index
  ld   rc rd # rd = *Q_index
  add  ra rd # rd += 1
  st   rc rd # *Q_index += 1
  data rc $A_index
  ld   rc rd # rd = *A_index
  add  ra rd # rd += 1
  st   rc rd # *A_index += 1

  data ra $A0
  cmp  rd ra
  ja   $end_long_div

  ld   rd rc # rc = **A_index = A
  data ra $cur_A_byte
  st   ra rc

  # A_pos has a 1 at the current bit
  data rc 10000000 # rc = A_pos

# Start on the next bit in the current byte of A
next_bit: # Uses rc = A_pos
  # Multiply R by 2
  data rb $R0
  ld   rb ra
  shl  ra ra
  st   rb ra
  data rb $R1
  ld   rb ra
  shl  ra ra # Will not produce overflow
  st   rb ra

  data rd $cur_A_byte
  ld   rd rd # rd = *cur_A_byte
  and  rc rd # A_pos & A
  data rd 1
  jz   $done_setting
set_to_one: # Uses rc = A_pos, rd = 1
  data ra $R0
  ld   ra rb
  or   rd rb # rb |= 1
  st   ra rb
done_setting: # Uses rc = A_pos, rd = 1
  # See if R >= n
  data ra $n1
  ld   ra ra # ra = *n1
  data rb $R1
  ld   rb rb # rb = *R1
  cmp  rb ra
  ja   $subtract_n
  je   $test_R0_n0
  jmp  $remainder_updated
test_R0_n0:
  data ra $n0
  ld   ra ra
  data rb $R0
  ld   rb rb
  cmp  rb ra
  jae  $subtract_n
  jmp  $remainder_updated
subtract_n: # Uses rc = prime_pos, rd = 1
  data ra $n0
  ld   ra ra
  not  ra ra
  add  rd ra # Will not overflow since *n0 is odd
  data rb $R0
  ld   rb rd
  add  ra rd
  st   rb rd

  data rb $R1
  ld   rb rd
  data ra 0
  add  ra rd # Add the carry
  data ra $n1
  ld   ra ra
  not  ra ra
  add  ra rd
  st   rb rd

  # Get current Q, OR with rc and store
  data rb $Q_index
  ld   rb rb
  ld   rb ra
  or   rc ra
  st   rb ra

remainder_updated: # Uses rc = prime_pos
  shr  rc rc
  jc   $start_long_div
  jmp  $next_bit
end_long_div: # Uses rb = remainder

  # If R == 0: set A = Q and goto $new_division
  data ra $R1
  ld   ra ra
  and  ra ra
  jz   $R_0_check0
  jmp  $new_n
R_0_check0:
  data ra $R0
  ld   ra ra
  and  ra ra
  jz   $update_A
  jmp  $new_n
update_A:
  data rd 1
  data ra $A4
  data rb $Q4
update_A_repeat:
  ld   rb rc
  st   ra rc
  add  rd ra
  add  rd rb
  data rc $A0
  cmp  rc ra
  jae  $update_A_repeat
  jmp  $new_division

done:
  data rd 16
  outa rd
  data rd $A0
  ld   rd rd
  outd rd
  data rd $A1
  ld   rd rd
  outd rd
  data rd 2
  outa rd
  data rd 10
  outd rd
  data rd 4
  outa rd
  outd rd

cur_A_byte:
. 0
A_index:
. 0
A4:
. 10001011
A3:
. 11100101
A2:
. 10001001
A1:
. 11101010
A0:
. 11000111

n1:
. 0
n0:
. 1

Q_index:
. 0
Q4:
. 0
Q3:
. 0
Q2:
. 0
Q1:
. 0
Q0:
. 0

R1:
. 0
R0:
. 0

