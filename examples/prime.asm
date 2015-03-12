# Prints all the primes < 128
# Uses Eratosthenes sieve, not assuming 2 is a prime so all natural
# numbers > 1 are sieved up to 128.
# Usage: Just run and all primes < 128 will be printed.
jmp  $start
. 0 # This is adress 2, so prime number = adress number
. 0 # If the value is 0 that means prime, 1 means not prime.
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
. 0
start:
  data rd 1
  add  rd ra # ra = 1
test_prime:
  add  rd ra
  ld   ra rb
  cmp  rb rd
  je   $test_prime # rb == 1
  ja   $done       # rb > 1, i.e. we are past the list
  # rb == 0, prime found:
  data rc 3
  outa rc # Integer printer
  outd ra # print prime
  xor  rd rc # rc = 2
  outa rc # ASCII printer
  data rc 10
  outd rc # new line
  xor  rc rc
  add  ra rc
  data rb 127
sieve_loop_start:
  add  ra rc # Add current prime
  cmp  rc rb
  ja   $test_prime # If we are past 127
  st   rc rd # Set number rc to not prime
  jmp  $sieve_loop_start

done:
  data rd 4
  outa rd # Power button
  outd rd
