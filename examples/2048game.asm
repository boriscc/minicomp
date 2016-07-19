# Program to play the game 2048 (http://2048game.com/)
# The game consists of a 4x4-board with initially two bricks
# on it. The goal is to create a brick with value 2048.
# The value of a brick is 2^n, where n is the displayed number
# The character ':' means n=10, ';' means n=11 (2048)
# The four moves are entered using the numbers 1-4
# 1 = left, 2 = down, 3 = up, 4 = right
# You win if you get a 2048 brick, you lose if there is
# no valid move.

# add a random brick to the board, a n=1 with 90% chance and a n=2 with 10% chance.
add_random:
  # ra, rb, rc, rd; flags = *, *, *, *; *
  data ra 5  # 00000101
  data rd 25 # 00011001
  outa ra
get_rnd_val:
  # ra, rb, rc, rd; flags = 5, *, *, 25; *
  ind  rb # rb = random value
  cmp  ra rb
  jae  $get_rnd_val # values 0-5 are invalid, left are 250 different values
  and  rd ra # ra = 1
  xor  rc rc
  add  rd rb # will give carry with prob 25/250
  add  rc ra # add carry to ra
  # ra = 1 with 90% chance and 2 with 10% chance
get_rnd_pos:
  # ra, rb, rc, rd; flags = val, *, 0, *; *
  data rd 31
  ind  rb
  and  rd rb
  data rd $board
  add  rd rb # This could overflow
  ld   rb rd
  cmp  rd rc
  ja   $get_rnd_pos
  st   rb ra

# here, (ra, rb, rc, rd) = (val, addr, 0, 0)
check_init:
  # NO JUMP HERE
  data rd $initialized
  ld   rd rb
  st   rd ra # non-zero value
  and  rb rb
  jz   $add_random

# here, (ra, rb, rc, rd) = (val, 1 or 2, 0, $initialized)
print_board:
  # NO JUMP HERE
  # no reg deps, assumes carry not set
  data ra 2
  outa ra # ascii printer
  shr  ra ra # ra = 1
  data rc '0'
  data rd $board
print_char:
  # ra, rb, rc, rd; flags = 1, board[i], '0', $board; !C
  ld   rd rb # rb = board[i]
  #to see if rb == 0
  cmp  rb ra
  jae  $print_char_not_zero
  #this will cause rb + rc to be '.'
  data rb 254
print_char_not_zero:
  # ra, rb, rc, rd; flags = 1, board[i], '0', $board; !C
  add  rc rb # rb = board[i] + '0'
  clf
  outd rb
  add  ra rd # i++, will overflow when done, so that rd = 0
  cmp  rd ra
  ja   $print_char

# here, (ra, rb, rc, rd) = (1, 218, '0' [48], 0)
get_input:
  # ra, rb, rc, rd; flags = 1, *, *, *; !C
  # uses ra = 1
  outa ra # ra = 1, so keyboard
  data ra 3
  data rc 207
get_input_again:
  # ra, rb, rc, rd; flags = 3, *, 207, *; !C
  ind  rd
  add  rc rd # if valid input, 0 <= rd <= 3
  cmp  rd ra
  # Get new input if invalid
  ja   $get_input_again

  # here, (ra, rb, rc, rd) = (3, 218, -'1' [207], move)
init_move:
  # NO JUMP HERE
  # Store the current move data in the *_cur variables
  # Uses: rd = move
  shl  rd rb # rb = 2*move
  add  rb rd # rd = 3*move
  data rb $move_data_pre
  shr  ra ra # ra = 1, carry set
  add  rd rb # rb points to correct move data
  data rc $offset_step_cur # rc points to the cur data
  ld   rb rd # offset_step
  st   rc rd
  add  ra rb
  add  ra rc
  ld   rb rd # step
  st   rc rd
  add  ra rb
  add  ra rc
  ld   rb rd # offset
  st   rc rd

  # Prepare looping
  # here, (ra, rb, rc, rd) = (1, $move_data+3*move+2, $offset_cur, *($move_data+3*move+2))
  # set *changed = 0
  data rb $changed
  xor  rc rc
  st   rb rc
outer_move_loop:
  # ra, rb, rc, rd; flags = *, *, *, *offset_cur; !C
  # assumes rd = *offset_cur
  # set *pos_first = *pos_second = $board + *offset_cur
  data rb $board
  add  rd rb # rb = $board + offset, may overflow, in which case we are done
  jc   $check_changed
  data rd $pos_first
  st   rd rb # *pos_first = rb
  data rd $pos_second
  st   rd rb # *pos_second = rb
  # If *first == 218, that means we are done
  ld   rb ra # ra = *first
  shl  ra ra
  jc   $check_changed
inner_move_loop:
  # ra, rb, rc, rd; flags = *, *pos_second, *, $pos_second; !C
  # increase second_addr with step_cur
  # assumes rd = $pos_second, rb = *pos_second
  data rc $step_cur
  ld   rc rc # rc = *step_cur
  add  rc rb # can overflow
  st   rd rb
  ld   rb ra # ra = *second
  # if *pos_second < $board, that means we are done
  data rc $board
  cmp  rc rb
  ja   $outer_move_loop_post
  # If *second == 218 we are done
  shl  ra ra
  jc   $outer_move_loop_post
  # here, (ra, rb, rc, rd) = (2 * *second, *pos_second, $board, $pos_second)
  shr  ra ra # ra = *second
  # If *second == 0, start next interation
  jz   $inner_move_loop
  # Check if *first == 0
  data rb $pos_first
  ld   rb rb # rb = *pos_first
  ld   rb rd # rd = *first
  and  rd rd
  jz   $move_slide
  # See if *second == *first
  cmp  ra rd
  je   $move_merge
  # here, rb = *pos_firsrt, rd = *first
  jmp  $increase_first
move_merge:
  # ra, rb, rc, rd; flags = *, *pos_first, *, *first; !C
  # here: (ra, rb, rc, rd) = (*second, *pos_first, *step_cur, *first)
  # assumes rd = *first, rb = *pos_first
  # *first += 1
  data rc 1
  add  rc rd
  st   rb rd
  # Check if won
  data ra 11
  cmp  ra rd
  ja   $not_won
  shl  rc ra
  outa ra
  data ra $win_msg
win_print:
  ld   ra rd
  outd rd
  add  rc ra
  cmp  rd rc
  jae  $win_print
not_won:
  # *second = 0
  xor  ra ra
  data rc $pos_second
  ld   rc rc # rc = *pos_second
  st   rc ra
  # *changed = non zero
  data rc $changed
  st   rc rc
  # here, (ra, rb, rc, rd) = (0, *pos_first, $changed, *first)
increase_first:
  # ra, rb, rc, rd; flags = *, *pos_first, *, *; !C
  # increase *pos_first, assumes rb = *pos_first
  data ra $pos_first
  data rc $step_cur
  ld   rc rc # rc = *step_cur
  add  rb rc # rc = *pos_first, can overflow
  st   ra rc
  # if *pos_first == *pos_second: goto inner_move_loop
  data rd $pos_second
  ld   rd rb # rb = *pos_second
  cmp  rc rb
  je   $inner_move_loop
  # here, (ra, rb, rc, rd) = ($pos_first, *pos_second, *pos_first, $pos_second)
move_slide:
  # ra, rb, rc, rd; flags = *, *, *, *; *
  data rd $pos_second
  ld   rd rb # rb = *pos_second
  # assumes rb = *pos_second, rd = $pos_second
  # *first = *second
  data ra $pos_first
  ld   ra ra # ra = *pos_first
  ld   rb rc # rc = *second
  st   ra rc # *first = *second
  # *second = 0
  xor  rc rc
  st   rb rc # *second = 0
  # *changed = non zero
  data rc $changed
  st   rc rc
  jmp  $inner_move_loop
outer_move_loop_post:
  # ra, rb, rc, rd; flags = *, *, *, *; *
  clf
  data ra $offset_cur
  data rb $offset_step_cur
  ld   rb rb # rb = *offset_step_cur
  ld   ra rd # rd = *offset_cur
  add  rb rd # may overflow
  st   ra rd
  clf
  jmp  $outer_move_loop
check_changed:
  # ra, rb, rc, rd; flags = *, *, *, *; *
  data ra 1
  data rb $changed
  ld   rb rb # rb = *changed
  cmp  rb ra
  jae  $add_random
  jmp  $get_input

win_msg:
. 'Y'
. 'o'
. 'u'
. ' '
. 'W'
. 'i'
. 'n'
. '!'
. 10
. 0
initialized:
. 0
changed:
. 0
pos_first:
. 0
pos_second:
move_data_pre:
. 0

move_data:
. 5 # offset_step, move left
. 1 # step, move left
. 0 # offset, move left
. 255 # offset_step, move down
. 251 # step, move down
. 18 # offset, move down
. 1 # offset_step, move up
. 5 # step, move up
. 0 # offset, move up
. 251 # offset_step, move right
. 255 # step, move right
. 18 # offset, move right
offset_step_cur:
. 0
step_cur:
. 0
offset_cur:
. 0

pragma setpos 235
board:
. 0
. 0
. 0
. 0
. 218
. 0
. 0
. 0
. 0
. 218
. 0
. 0
. 0
. 0
. 218
. 0
. 0
. 0
. 0
. 218
# This should be the last byte of the program
pragma pos 255
. 218

