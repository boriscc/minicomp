ld   ra rb # ra=0 => rb=1
ld   rb rd # rb=1 => rd=7
data ra 5
outa ra
data rc $correct

# Need rd=7, rb=1, rc=$correct, use ra
set_correct:
  ind  ra
  and  rd ra
  and  rd ra
  jze  $set_correct
  st   rc ra
  add  rb rc
  ld   rc ra
  or   ra ra
  jz   $set_correct_done
  jmp  $set_correct

# need: none
set_correct_done:
  data ra 2
  outa ra # ascii printer
new_guess:
  data rb '?'
  outd rb
  shr  ra ra
  outa ra # keyboard
  data rd $guess
next_sub_guess:
  ind  ra # Get key
  or   ra ra
  jz   $next_sub_guess
  data rb '6'
  cmp  ra rb
  ja   $next_sub_guess
  data rb '1'
  cmp  rb ra
  ja   $next_sub_guess
  data rc 11010000 # -'0'
  add  rc ra
  clf
  add  rc rb # rb = 1
  clf
  st   rd ra
  add  rb rd
  ld   rd rb
  or   rb rb
  jz   $guess_done
  jmp  $next_sub_guess

guess_done:
  data ra 3
  outa ra # integer printer
  data rd $guess
  data rb 1
print_next_guess:
  ld   rd rc
  or   rc rc
  jz   $print_guess_done
  outd rc
  add  rb rd
  jmp  $print_next_guess

print_guess_done:
  shl  rb rb
  outa rb # ascii printer
  data rc '-'
  outd rc
  data rc '>'
  outd rc
  outa ra # integer printer

  # ra will be used as index
  xor  ra ra
  # Set *nr_correct_exact = 0
    data rb $nr_correct_exact
    st   rb ra
  jmp $calc_nr_correct_exact_next
add_correct_exact:
  # Invert the correct to indicate it has been accounted for
    not  rb rb
    st   rd rb
  # Scramble the guess too
    data rd $guess
    st   rd rd
  data rd 1
  # increase *nr_correct_exact by 1
    data rb $nr_correct_exact
    ld   rb rc
    add  rd rc
    st   rb rc
calc_nr_correct_exact_next_pre:
    add  rd ra
calc_nr_correct_exact_next:
  data rd $correct
  add  ra rd
  ld   rd rb
  cmp  rd rb # A bit ugly, assume rd < 250
  ja   $calc_nr_correct_exact_tmp
  not  rb rb
calc_nr_correct_exact_tmp:
  or   rb rb
  jz   $calc_nr_correct_exact_done
  data rc $guess
  add  ra rc
  ld   rc rc
  cmp  rb rc
  je   $add_correct_exact
  st   rd rb
  data rd 1
  jmp  $calc_nr_correct_exact_next_pre

calc_nr_correct_exact_done:
  # Print *nr_correct_exact
    data ra $nr_correct_exact
    ld   ra ra
    outd ra
  # Store $guess in $tmp1
    data ra $guess
    data rb $tmp1
    st   rb ra
  # Set *nr_correct = 0
    data rb $nr_correct
    xor  ra ra
    st   rb ra
  data rd 1
  jmp $calc_nr_correct_outer

calc_nr_correct_outer_pre:
  # increase *tmp1 by 1
    data rb $tmp1
    ld   rb rc
    add  rd rc
    st   rb rc
  # Check if **tmp1 == 0
    ld   rc rb
    or   rb rb
    jz   $calc_nr_correct_done
calc_nr_correct_outer:
  data ra $correct
  jmp  $calc_nr_correct_inner
calc_nr_correct_add:
  # Invert the correct to indicate it has been accounted for
    not  rb rb
    st   ra rb
  # increase *nr_correct by 1
    data rb $nr_correct
    ld   rb rc
    add  rd rc
    st   rb rc
calc_nr_correct_inner_pre:
  add  rd ra
calc_nr_correct_inner:
  ld   ra rb
  or   rb rb
  jz   $calc_nr_correct_outer_pre
  data rc $tmp1
  ld   rc rc # rc = *tmp
  ld   rc rc # rc = **tmp
  cmp  rb rc
  je   $calc_nr_correct_add
  jmp  $calc_nr_correct_inner_pre

calc_nr_correct_done:
  # Print *nr_correct
    data ra $nr_correct
    ld   ra rb
    outd rb
  # Increase nr_guess
    add  rd ra # works because $nr_guess = $nr_correct + 1
    ld   ra rb
    add  rd rb
    st   ra rb
  # Set ascii output
    shl  rd ra # ra = 2
    outa ra # ascii printer
  # Print new line
    data rc 10
    outd rc
  # See if game is won
    shl  ra rc # rc = 4
    data rd $nr_correct_exact
    ld   rd rd
    cmp  rd rc
    je   $game_won
  # See if game is lost
    data rc 12
    cmp  rb rc
    je   $game_lost
  # New guess
    jmp  $new_guess

game_won:
  data rb $win_msg
  jmp  $game_end
game_lost:
  data rb $lose_msg
game_end:
  shr  ra ra
game_end_loop:
  ld   rb rc
  or   rc rc
  jz   $terminate
  outd rc
  add  ra rb
  jmp  $game_end_loop

terminate:
  data ra 4
  outa ra
  outd ra

tmp1:
. 0
nr_correct_exact:
. 0
nr_correct:
. 0
nr_guess:
. 0
correct:
. 1
. 1
. 1
. 1
. 0
guess:
. 1
. 1
. 1
. 1
. 0
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
lose_msg:
. 'Y'
. 'o'
. 'u'
. ' '
. 'L'
. 'o'
. 's'
. 'e'
. '.'
#. ' '
#. ':'
#. '('
. 10
. 0
