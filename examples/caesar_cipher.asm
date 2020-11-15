# Simple version of Caesar cipher
# It will only encrypt lower-case letters 'a' to 'z'
# All other input will be unaltered
# At the start of the program it will print "S:",
# at which point a letter from a to z should be inputed, where
# 'a' means a right-shift of 0, and 'b' a right-shift of 1, and so on.
# Then "I:" will be printed, here input your text. Press enter when you are done.
# Then "O:" will be printed followed by the encrypted text
#
# 26 letters in the alphabet (a-z)
# 'a' = 97
# -'a' = -97 + 256 = 159
# 'z' = 122
get_shift:
  data ra 2
  outa ra # ASCII printer
  data rb 'S'
  outd rb
  data rb ':'
  outd rb
  shr  ra ra
  outa ra # Keyboard
get_shift_again:
  ind  rb
  or   rb rb
  jz   $get_shift_again
  data rc 159 # = -'a' = 159
  add  rc rb
  data rc 26
  cmp  rb rc
  jae  $get_shift
  data rc $shift
  st   rc rb
get_text:
  clf
  data rd $buffer
  data ra 2
  outa ra # ASCII printer
  data rb 'I'
  outd rb
  data rb ':'
  outd rb
  shr  ra ra
  outa ra # keyboard
get_text_again:
  ind  rb
  or   rb rb
  jz   $get_text_again
  st   rd rb # store at current buffer position
  add  ra rd # increase buffer position by one
  jc   $encrypt_text
  data rc 10 # = '\n'
  cmp  rb rc
  je   $encrypt_text
  jmp  $get_text_again
encrypt_text:
  clf
  data rd $buffer
  data ra 2
  outa ra # ASCII printer
  shr  ra ra
  data rb 'O'
  outd rb
  data rb ':'
  outd rb
encrypt_text_again:
  ld   rd rb
  data rc 'a'
  cmp  rc rb
  ja   $print_encrypted
  data rc 'z'
  cmp  rb rc
  ja   $print_encrypted
  data rc $shift
  ld   rc rc
  add  rc rb # This cannot overflow since 'z' + 25 < 256
  data rc 'z'
  cmp  rc rb
  jae  $print_encrypted
  # subtract 26 i.e. add -26 + 256 = 230
  data rc 230
  add  rc rb # this will overflow
  clf
print_encrypted:
  outd rb
  add  ra rd # increase buffer position by one
  data rc 10 # = '\n'
  jc   $print_newline
  cmp  rb rc
  je   $get_text
  jmp  $encrypt_text_again
print_newline:
  outd rc
  jmp  $get_text

shift:
. 0
buffer:
