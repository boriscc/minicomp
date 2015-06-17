#If we list all the natural numbers below 10 that are multiples of 3 or 5, we get 3, 5, 6 and 9. The sum of these multiples is 23.
#
#Find the sum of all the multiples of 3 or 5 below 1000.

# Solution: starting with n = 3, add cyclically 2,1,3,1,2,3,3 until >= 1000 = 00000011 11101000
# n is 16-bit, sum is 24-bit
# Runs in 20368 instructions

start:
# Add num to sum
  data rd $num0
  ld   rd ra
  data rb $sum0
  ld   rb rc
  add  ra rc
  st   rb rc
  
  data ra $num1
  ld   ra ra
  data rb $sum1
  ld   rb rc
  add  ra rc
  st   rb rc

  data ra 0
  data rb $sum2
  ld   rb rc
  add  ra rc # Will not produce carry
  st   rb rc

# Add delta to num
  data ra $delta_pos
  ld   ra rb
  ld   rb rb
  ld   rd rc
  add  rb rc
  st   rd rc
  data rb 0
  add  rb rb # Contains carry
  data rd 11101000
  cmp  rd rc
  ja   $not_done
  data ra 0
not_done:
  data rd $num1
  ld   rd rc
  add  rb rc # Will not produce carry
  st   rd rc
  data rd 3
  cmp  rd rc
  ja   $not_done2
  and  ra ra
  jz   $done
not_done2:

# Update delta_pos
  data ra $delta_pos
  ld   ra rb # rb = *delta_pos
  data rc 1
  add  rc rb
  cmp  ra rb
  ja   $no_reset # if $delta_pos > *delta_pos
  data rb $delta
no_reset:
  st   ra rb
  jmp  $start

done:
# Print sum
  data rd 24
  outa rd
  data rd $sum0
  ld   rd rd
  outd rd
  data rd $sum1
  ld   rd rd
  outd rd
  data rd $sum2
  ld   rd rd
  outd rd
  data rd 2
  outa rd
  data rd 10
  outd rd

# Exit
  data rd 4
  outa rd
  outd rd

num0:
. 3
num1:
. 0
sum0:
. 0
sum1:
. 0
sum2:
. 0
delta:
. 2
. 1
. 3
. 1
. 2
. 3
. 3
delta_pos:
. $delta
