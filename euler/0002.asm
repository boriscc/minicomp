# Each new term in the Fibonacci sequence is generated by adding the previous two terms. By starting with 1 and 2, the first 10 terms will be:
#
# 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, ...
#
# By considering the terms in the Fibonacci sequence whose values do not exceed four million, find the sum of the even-valued terms.

# Solution:
#   a, b and sum are 24-bit, add every third term to sum. In each iter: a -> a + b, swap a <-> b
#   4000000 - 1 = 00111101 00001000 11111111
# Runs in 1552 instructions

start:
  data ra $mod_three
  ld   ra rb
  data rc 1
  cmp  rb rc # to see if *mod_three > 1
  ja   $reset_mod_three
  add  rc rb
  st   ra rb # *mod_three += 1
  jmp  $mod_three_updated
reset_mod_three:
  xor  rb rb
  st   ra rb # *mod_three = 0

  # sum = sum + b
  # Add b0 to sum0
  data ra $b0
  ld   ra ra # ra = *b0
  data rb $sum0
  ld   rb rd # rd = *sum0
  add  ra rd
  st   rb rd

  # Add b1 to sum1
  data ra $b1
  ld   ra ra # ra = *b1
  data rb $sum1
  ld   rb rd # rd = *sum1
  add  ra rd
  st   rb rd

  # Add b2 to sum2
  data ra $b2
  ld   ra ra # ra = *b2
  data rb $sum2
  ld   rb rd # rd = *sum2
  add  ra rd
  st   rb rd

mod_three_updated:
  # Simultaneously set a = b and b = a + b
  # And check if a + b > 3999999
# ==>, =>*, >**
# 1 >: x=001, 1 <=: x=000
# 2 >: DONE , 2 ==: DONE IF x==1, 2 <: NOT DONE
  # Add b0 to a0
  data ra $a0
  ld   ra rc # rc = *a0
  data rb $b0
  ld   rb rd # rd = *b0
  add  rd rc # rc = *a0 + *b0
  st   ra rd
  st   rb rc

  # Add b1 to a1
  data ra $a1
  ld   ra rc # rc = *a1
  data rb $b1
  ld   rb rd # rd = *b1
  add  rd rc # rc = *a1 + *b1 + carry
  st   ra rd
  st   rb rc

  data ra 0
  add  ra ra
  data rb 00001000
  cmp  rb rc
  data rb 0
  jae  $no_set_one
  data rb 1
no_set_one:
  data rc $temp
  st   rc rb
  shr  ra ra

  # Add b2 to a2
  data ra $a2
  ld   ra rc # rc = *a2
  data rb $b2
  ld   rb rd # rd = *b2
  add  rd rc # rc = *a2 + *b2 + carry
  st   ra rd
  st   rb rc

  data rb 00111101
  cmp  rc rb
  ja   $done
  je   $extra_check
  jmp  $start
extra_check:
  data ra $temp
  ld   ra ra
  and  ra ra
  jz   $start
  jmp  $done

temp:
. 0

done:
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

  data rd 4
  outa rd
  outd rd

# Adds two 24-bit numbers, 28 instructions
# IN:
#   ra = address to a0
#   rb = address to b0
#   *ret_addr = return address
# OUT:
#   ra = address to a2
#   rb = address to b2
#   rc = 
#   rd = 1
#   flags: from add of last byte
#adder_24:
#  clf
#  # Add a0 to b0
#  ld   ra rc # rc = *a0
#  ld   rb rd # rd = *b0
#  add  rc rd
#  st   rd rb
#
#  data rc 0
#  add  rc rc
#  data rd 1
#  add  rd ra
#  add  rd rb
#  shr  rc rc
#
#  # Add a1 to b1
#  ld   ra rc # rc = *a1
#  ld   rb rd # rd = *b1
#  add  rc rd
#  st   rd rb
#
#  data rc 0
#  add  rc rc
#  data rd 1
#  add  rd ra
#  add  rd rb
#  shr  rc rc
#
#  # Add a2 to b2
#  ld   ra rc # rc = *a2
#  ld   rb rd # rd = *b2
#  add  rc rd
#  st   rd rb
#
#  data rc $ret
#  ld   rc rc
#  jmpr rc

mod_three:
. 2
a0:
. 1
a1:
. 0
a2:
. 0
b0:
. 2
b1:
. 0
b2:
. 0
sum0:
. 0
sum1:
. 0
sum2:
. 0
