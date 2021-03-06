data ra $prime_list_all
data rb 3
data rc 1
print_list: # Uses ra = $cur_prime, rb = 3, rc = 1
outa rb # Integer printer
ld   ra rd
and  rd rd
jz   $start_prime
outd rd
add  rc ra
xor  rc rb # rb = 2
outa rb # ASCII printer
data rd 10
outd rd
or   rc rb # rb = 3
jmp $print_list

start_prime: # No register value assumptions
  # Increase LSB of current (prime) number and update prime_add
  data rb $prime_add
  ld   rb rd # rd = current add
  data ra 6 # 0000 0110
  xor  rd ra # ra: 2->4 , 4->2 = next add
  st   rb ra # store next add
  data rb $prime0
  ld   rb ra
  xor  rc rc # Must be done before the add, since I want to use the carry from the add
  add  rd ra
  st   rb ra # *prime0 += 2 or 4

  # Increase MSB of current (prime) number
  data rb $prime1
  ld   rb ra
  add  rc ra # Uses carry from previous add
  jc   $done
  st   rb ra # *prime1 +=[WITH_CARRY] 0

  data ra $prime_list_at_three
  data rb $prime_list_index
  st   rb ra

start_divisor: # Uses CARRY_FLAG_UNSET
    data ra $prime_list_index
    ld   ra rc # rc = *prime_list_index
    data rd 1
    add  rd rc
    st   ra rc # *prime_list_index += 1
    ld   rc rd # rd = **prime_list_index = divisor
    and  rd rd
    jz   $print_prime # End of the list, so is a prime
    data rc $cur_divisor
    st   rc rd

    # prime_index is a pointer to the current 
    # byte of the (prime) number to test, starting with
    # the most significant byte
    data rd $prime_index
    st   rd rd # *prime_index = $prime_index
    xor  rb rb # rb = remainder = 0

# See if divisor divides the prime, by calculating the remainder
start_long_div: # Uses rb = remainder
    clf # Get rid of carry

    data ra 1
    data rc $prime_index
    ld   rc rd # rd = *prime_index
    add  ra rd # rd += 1

    data ra $prime0
    cmp  rd ra
    ja   $end_long_div

    st   rc rd # *prime_index += 1
    ld   rd rc # rc = **prime_index = prime
    data ra $cur_prime_byte
    st   ra rc

    # prime_pos has a 1 at the current bit
    data rc 10000000 # rc = prime_pos

# Decrease rc as low as possible
    data ra $prime1
    cmp  rd ra
    ja   $next_bit
    ld   ra ra # ra = *prime1
optimize_prime_pos:
    cmp  ra rc
    jae  $next_bit
    shr  rc rc
    jmp  $optimize_prime_pos

# Start on the next bit in the current byte of the (prime) number
next_bit: # Uses rb = remainder, rc = prime_pos
    xor  ra ra # ra = overflow = 0
    shl  rb rb # rb *= 2
    add  ra ra # ra = carry from shl = overflow

    data rd $cur_prime_byte
    ld   rd rd # rd = *cur_prime_byte
    and  rc rd # prime_pos & prime
    data rd 1
    jz   $done_setting
set_to_one: # Uses ra = overflow, rb = remainder, rc = prime_pos, rd = 1
    or   rd rb # rb |= 1
done_setting: # Uses ra = overflow, rb = remainder, rc = prime_pos, rd = 1
    cmp  ra rd
    data ra $cur_divisor
    ld   ra ra # ra = *cur_divisor
    je   $subtract_divisor
    cmp  rb ra
    jae  $subtract_divisor
    jmp  $remainder_updated
subtract_divisor: # Uses ra = divisor, rb = remainder, rc = prime_pos, rd = 1
    not  ra ra
    add  rd ra
    add  ra rb
    clf
remainder_updated: # Uses rb = remainder, rc = prime_pos
    shr  rc rc
    jc   $start_long_div
    jmp  $next_bit
end_long_div: # Uses rb = remainder
    and  rb rb
    jz   $start_prime
    jmp  $start_divisor

print_prime:
  data ra 16
  outa ra # 16-bit integer printer
  data ra $prime0
  ld   ra ra
  outd ra # Send first byte
  data ra $prime1
  ld   ra ra
  outd ra # Send second byte, will print
  data ra 2
  outa ra # ASCII printer
  data ra 10
  outd ra # Print new line
  jmp  $start_prime

done:
  data rd 4
  outa rd # Power button
  outd rd

prime_add:
. 4
cur_prime_byte:
. 0
cur_divisor:
. 0
prime_index:
. 0
prime1:
. 0
prime0:
. 253
prime_list_index:
. 0
prime_list_all:
. 2
prime_list_at_three:
. 3
. 5
. 7
. 11
. 13
. 17
. 19
. 23
. 29
. 31
. 37
. 41
. 43
. 47
. 53
. 59
. 61
. 67
. 71
. 73
. 79
. 83
. 89
. 97
. 101
. 103
. 107
. 109
. 113
. 127
. 131
. 137
. 139
. 149
. 151
. 157
. 163
. 167
. 173
. 179
. 181
. 191
. 193
. 197
. 199
. 211
. 223
. 227
. 229
. 233
. 239
. 241
. 251
. 0
