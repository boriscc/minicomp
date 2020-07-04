get_next_V:
  clf
  data rc $V0
  data ra 1
  data rd 1
  outa ra # keyboard
get_input:
  ind  rb
  or   rb rb
  jz   $get_input
  st   rc rb
  add  ra rc # add 1
  shl  rd rd
  jc   $have_next_V
  jmp  $get_input
have_next_V:
  clf
print_encrypted:
  data ra 6
  outa ra # hex-number printer
  data ra $V0
  data rb 1
  data rc 1
print_again:
  ld   ra rd
  outd rd
  add  rb ra # add 1
  shl  rc rc
  jz   $get_next_V
  jmp  $print_again
terminate:
  data ra 4
  outa ra
  outd ra
V0:
. 0
. 0
. 0
. 0
V1:
. 0
. 0
. 0
. 0
sum:
. 0
. 0
. 0
. 0
delta:
. 0x9e
. 0x37
. 0x79
. 0xb9
K0:
. 0
. 1
. 2
. 3
K1:
. 4
. 5
. 6
. 7
K2:
. 8
. 9
. 10
. 11
K3:
. 12
. 13
. 14
. 15
