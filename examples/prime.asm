jmp  $start
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
. 0
. 0
start:
  data rd 1
  add  rd ra
test_prime:
  add  rd ra
  ld   ra rb
  cmp  rb rd
  je   $test_prime # rb == 1
  ja   $done       # rb > 1, i.e. we are past the list
  # rb == 0, prime found:
  data rc 3
  outa rc
  outd ra # print prime
  xor  rd rc # rc = 2
  outa rc
  data rc 10
  outd rc # new line
  xor  rc rc
  add  ra rc
  data rb 127
sieve_loop_start:
  add  ra rc
  cmp  rc rb
  ja   $test_prime
  st   rc rd
  jmp  $sieve_loop_start

done:
  data rd 4
  outa rd
  outd rd
