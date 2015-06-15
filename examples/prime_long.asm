data ra 3
outa ra # Integer printer
data ra 2
outd ra # Print prime 2
outa ra # ASCII printer
data ra 10
outd ra # Print new line

start_prime: # No register value assumptions
  data rb $prime0
  ld   rb ra
  data rd 2
  clf
  xor  rc rc # Must be done before the add, since I want to use the carry from the add
  add  rd ra
  st   rb ra # *prime0 += 2

  data rb $prime1
  ld   rb ra
  add  rc ra # Uses carry from previous add
  st   rb ra # *prime1 +=[WITH_CARRY] 0
  jc   $done

  data ra 1
  data rb $base_divisor
  st   rb ra # Set *base_divisor = 1

start_base_divisor: # No register value assumptions
    data rb $base_divisor
    ld   rb ra
    data rd 2
    clf
    add  rd ra
    jc   $print_prime # We found a prime
    st   rb ra # *base_divisor += 2

    data rb $prime1
    ld   rb rb # rb = *prime1
    and  rb rb
    jz   $compare_base_divisor__prime0
    # Here ra = *base_divisor
    jmp  $continue_base_divisor

compare_base_divisor__prime0: # Uses ra = *base_divisor
    data rb $prime0
    ld   rb rb # rb = *prime0
    cmp  ra rb
    je   $print_prime # This is a prime
    # Here ra = *base_divisor

continue_base_divisor: # Uses ra = *base_divisor
    xor  rc rc
    data rd $cur_divisor0
    st   rd ra
    data rd $cur_divisor1
    st   rd rc

    ld   rd rd
    # Here: ra = *base_divisor, rb = ?, rc = 0, rd = *cur_divisor1

start_cur_divisor: # Uses ra = *base_divisor, rd = *cur_divisor1
      data rb $prime1
      ld   rb rb # rb = *prime1
      cmp  rd rb
      ja   $start_base_divisor
      je   $compare_prime0__cur_divisor0
      # Here ra = *base_divisor
      jmp  $increase_cur_divisor

# Logically assumes *prime1 == *cur_divisor1
compare_prime0__cur_divisor0: # Uses ra = *base_divisor
      data rb $prime0
      ld   rb rb
      data rd $cur_divisor0
      ld   rd rd
      cmp  rd rb
      je   $start_prime # This is not a prime, so continue with next
      ja   $start_base_divisor
      # Here ra =  *base_divisor

increase_cur_divisor: # Uses ra = *base_divisor
      data rb $cur_divisor0
      ld   rb rd # rd = *cur_divisor0
      clf
      xor  rc rc # rc = 0
      add  ra rd
      st   rb rd # *cur_divisor0 += *base_divisor
      data rb $cur_divisor1
      ld   rb rd # rd = *cur_divisor1
      add  rc rd # Uses carry from previous add
      st   rb rd # *cur_divisor1 +=[WITH_CARRY] 0
      # Here ra = *base_divisor, rd = *cur_divisor1
      jc   $start_base_divisor
      jmp  $start_cur_divisor

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

prime0:
. 1
prime1:
. 0
base_divisor:
. 0
cur_divisor0:
. 0
cur_divisor1:
. 0
