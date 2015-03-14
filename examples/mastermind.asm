# Program to play mastermind as the code breaker.
# You get 12 tries to guess the correct code, which
# consists of four numbers, one to six.
# Usage: At the prompt, enter four digits in the
# range 1-6, then the program tells you first how many
# of those were correct and in the right place, then
# how many were correct but in the wrong place.
ld   ra rb # ra=0 => rb=1
ld   rb rd # rb=1 => rd=7
data ra 5
outa ra
data rc $correct

# Need rd=7, rb=1, rc=$correct, use ra
set_correct: # Generate the correct code
  ind  ra
  and  rd ra
  and  rd ra
  jze  $set_correct
  st   rc ra
  add  rb rc
  ld   rc ra
  cmp  rb ra
  je   $set_correct

# need: none
set_correct_done:
  data ra 2
  outa ra # ascii printer
new_guess: # Prompt the user for the next guess
  data rb '?'
  outd rb
  shr  ra ra
  outa ra # keyboard
  data rc 11010000 # -'0'
  data rd $guess
# Will use that rc = -'0' and rd = $guess
next_sub_guess: # Prompt the user for the next digit
  clf  # Needed to clear the carry flag in the add rc ra line
  ind  ra # Get key
  add  rc ra
  jz   $next_sub_guess
  data rb 6
  cmp  ra rb
  ja   $next_sub_guess
  data rb 1
  st   rd ra
  add  rb rd
  ld   rd ra
  cmp  ra rb
  jae  $next_sub_guess

# Will use rb = 1, rd = $guess + 4
guess_done:
  data rc 3
  outa rc # integer printer
  data ra $guess
print_next_guess: # Print the guess the user made
  ld   ra rc
  outd rc
  add  rb ra
  cmp  rd ra
  ja   $print_next_guess

# Use rb = 1
print_guess_done:
  shl  rb ra # ra = 2
  outa ra # ascii printer
  data rc '-'
  outd rc
  data rc '>'
  outd rc
  add  rb ra # ra = 3
  outa ra # integer printer

  # ra will be used as index
  xor  ra ra
  # Set *nr_correct = 0
    data rb $nr_correct
    st   rb ra
  jmp $calc_nr_correct_exact_next
add_correct_exact:
  # Invert the correct to indicate it has been accounted for
    not  rb rb
    st   rc rb
  # Scramble the guess too
    data rd $guess
    add  ra rd
    st   rd rd
  data rd 1
  # increase *nr_correct by 1
    data rb $nr_correct
    ld   rb rc
    add  rd rc
    st   rb rc
calc_nr_correct_exact_next_pre:
    add  rd ra
calc_nr_correct_exact_next: # Calculate the number of correct guesses
                            # in the correct spot he user made
  data rc $correct
  add  ra rc
  ld   rc rb
  or   rb rb
  jz   $calc_nr_correct_exact_done
  cmp  rc rb # A bit ugly, assume rc < 250
  ja   $calc_nr_correct_exact_tmp
  not  rb rb
calc_nr_correct_exact_tmp:
  data rd $guess
  add  ra rd
  ld   rd rd
  cmp  rb rd
  je   $add_correct_exact
  st   rc rb
  data rd 1
  jmp  $calc_nr_correct_exact_next_pre

calc_nr_correct_exact_done:
# Here (ra, rb, rc, rd) = (4, 0, $correct+4, 1)
  # Print *nr_correct
    data rc $nr_correct
    ld   rc rc
    outd rc
  # See if game is won
    cmp  rc ra
    je   $game_won
  # Store $correct in $tmp1
    data ra $correct
    data rc $tmp1
    st   rc ra
  # Set *nr_correct = 0
    data rc $nr_correct
    st   rc rb
# Here, (ra, rb, rc, rd) = ($correct, 0, $nr_correct, 1)
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
# Here, (ra, rb, rc, rd) = (-, rnd, *tmp1, 1)
calc_nr_correct_outer: # Outer loop (correct list) to calculate
                       # number of correct but wrong place
  data ra $guess
  jmp  $calc_nr_correct_inner
calc_nr_correct_add:
  # Scramble the guess to indicate it has been accounted for
    st   ra ra
  # increase *nr_correct by 1
    data rb $nr_correct
    ld   rb rc
    add  rd rc
    st   rb rc
  jmp  $calc_nr_correct_outer_pre
calc_nr_correct_inner_pre:
  add  rd ra
calc_nr_correct_inner: # The inner loop over the guess list
  ld   ra rb # rb = *guess
  or   rb rb
  jz   $calc_nr_correct_outer_pre
  data rc $tmp1
  ld   rc rc # rc = *tmp
  ld   rc rc # rc = **tmp = *correct
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
  # See if more guesses are allowed
    add  ra rc
    cmp  rc rb
    ja   $new_guess

game_lost:
# Here, (ra, rb, rc, rd) = (2, 12, 12, 1)
  data ra $lose_msg
  jmp  $game_end
game_won:
# Here, (ra, rb, rc, rd) = (4, 0, 4, 1)
  data ra $win_msg
game_end:
  shl  rd rc
  outa rc # ascii printer
game_end_loop:
  ld   ra rb
  or   rb rb
  jz   $terminate
  outd rb
  add  rd ra
  jmp  $game_end_loop

terminate:
# Here rc = 2
  shl  rc ra
  outa ra
  outd ra

tmp1:
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
. 10
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
. ' '
. ':'
. '('
. 10
. 0
