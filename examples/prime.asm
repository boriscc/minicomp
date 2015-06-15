# Prints all the primes < 256
# Uses Eratosthenes sieve, assuming 2 is a prime so all odd natural
# numbers > 1 are sieved up to 256.
# Usage: Just run and all primes < 256 will be printed.
ld   ra rd # rd = ram[ra] = ram[0] = 3
# 0 = ld   ra ra => ra = ram[ra] = ram[0] = 3
. 0 # This is address 1 and number 3, so number = 2 * adress + 1
# 0 = ld   ra ra => ra = ram[ra] = ram[1] = 0, so ra = 3 * (address & 1)
. 0 # If the value is 0 that means prime, 1 means not prime.
. 0 # address 3
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0 # address 127 => number = 255, ra = 3
# Here ra = rd = 3
start:
  shr  rd rd # rd = 1, carry flag set
  outa ra # Integer printer
  xor  rd ra # ra = 2
  outd ra # Print 2
  outa ra # ASCII printer
  data ra 10
  outd ra # new line
# Here ra = 10, rb = rc = 0, rd = 1
test_prime: # Uses rb = index, rd = 1
# rb is used as ram index
  clf  # needed since the shl in sieve_loop_start will overflow
  add  rd rb # rb++
  ld   rb ra # ra = ram[rb]
  cmp  ra rd # Compare ra=ram[rb] and rd=1
  je   $test_prime # ra == 1
  ja   $done       # ra > 1, i.e. we are past the list
  # ra == 0, prime found:
  # ra = 0, rb = ram index, rc = ?, rd = 1
  data rc 3
  outa rc # Integer printer
  shl  rb ra # ra = 2 * index
  add  rd ra # ra = 2 * index + 1 = prime
  outd ra # print prime
  xor  rd rc # rc = 2
  outa rc # ASCII printer
  data rc 10
  outd rc # new line
  # ra = prime, rb = index, rc = 10, rd = 1
  xor  rc rc
  add  rb rc # rc = index2 = index
sieve_loop_start:
  add  ra rc # rc = index2 += prime
  shl  rc rc # rc *= 2
  jc   $test_prime # If we overflow (past 255) we are done
  shr  rc rc # rc /= 2
  st   rc rd # Set number rc to not prime
  jmp  $sieve_loop_start
done:
  data rd 4
  outa rd # Power button
  outd rd
