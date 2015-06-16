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
  data rb $prime0
  ld   rb ra
  data rd 2
  xor  rc rc # Must be done before the add, since I want to use the carry from the add
  add  rd ra
  st   rb ra # *prime0 += 2

  data rb $prime1
  ld   rb ra
  add  rc ra # Uses carry from previous add
  st   rb ra # *prime1 +=[WITH_CARRY] 0
  jc   $done

  data ra $prime_list_all
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

    data rd $prime_index
    st   rd rd # *prime_index = $prime_index
    xor  rb rb # rb = remainder = 0

# See if divisor divides the prime, by calculating the remainder
start_long_div: # Uses rb = remainder
    clf
    data ra 1
    data rc $prime_index
    ld   rc rd # rd = *prime_index
    add  ra rd # rd += 1
    st   rc rd # *prime_index += 1
    data rc $prime0
    cmp  rd rc
    ja   $end_log_div
    data rc 10000000 # rc = prime_pos

next_bit: # Uses rb = remainder, rc = prime_pos
    xor  ra ra # ra = overflow = 0
    shl  rb rb # rb *= 2
    add  ra ra # ra = carry from shl
    data rd $got_overflow
    st   rd ra

    data rd $prime_index
    ld   rd rd # rd = *prime_index
    ld   rd rd # rd = **prime_index = prime
    and  rc rd # prime_pos & prime
    jz   $done_setting
set_to_one:
    data rd 1
    or   rd rb # rb |= 1
done_setting: # Uses rb = remainder, rc = prime_pos
    data ra $got_overflow
    ld   ra ra # ra = *got_overflow
    data rd 1
    cmp  ra rd
    data ra $prime_list_index
    ld   ra ra # ra = *prime_list_index
    ld   ra ra # ra = **prime_list_index = divisor = xxxxxxx1
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
end_log_div: # Uses rb = remainder
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

got_overflow:
. 0
prime_index:
. 0
prime1:
. 0
prime0:
. 255
prime_list_index:
. 0
prime_list_all:
. 2
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
