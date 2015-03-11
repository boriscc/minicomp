ld   ra rc
outa rc

input_start:
  data ra 'a'
  data rb $offset
  ld   rb rb # rb = *offset
  add  rb ra # ra = 'a' + *offset
  outd ra
  data ra '?'
  outd ra

  shr  rc rc
  outa rc
get_input:
  ind  rd
  not  rd rd
  not  rd rd
  jz   $get_input
  data ra '0'
  cmp  ra rd
  je   $input_done
  ja   $end # User entered ascii < '0', i.e. invalid
  data ra '9'
  cmp  rd ra
  ja   $input_end # User entered ascii > '9', i.e. invalid

  # '0' = 0011 0000
  # Calculate rd = rd - '0' = rd + (~'0' + 1) = rd + (1100 1111 + 1) = rd + 11010000
  data ra 11010000
  add  ra rd
  clf

  # Store the value entered
  data ra $user_data
  data rb $offset
  ld   rb rb # rb = *offset
  add  rb ra # ra = user_data + *offset
  st   ra rd
  
  # Increase offset by 1
  add  rc rb # rb = *offset + 1
  data ra $offset
  st   ra rb # *offset = rb
  data ra 10
  cmp  ra rb
  je   $input_done

input_end:
  shl  rc rc
  outa rc
  jmp  $input_start

input_done:
  xor  ra ra # ra = 0, will contain sum
  xor  rb rb # loop counter

sum_start:
  data rd $user_data
  add  rb rd
  ld   rd rd # rd = *(user_data + rb)
  add  rd ra # ra += rd
  add  rc rb # rb += 1
  data rd $offset
  ld   rd rd # rd = *offset
  cmp  rd rb
  je   $sum_done
  jmp  $sum_start

sum_done:
  data rb 3
  outa rb
  outd ra

  shl  rc rc
  outa rc
  data ra 10
  outd ra

  shl  rc rc
  outa rc
  outd rc # terminate

offset:
. 0

user_data:
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
. 0
