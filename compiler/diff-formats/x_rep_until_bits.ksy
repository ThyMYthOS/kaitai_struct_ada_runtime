# Repetitions of bit fields until a condition, started in the middle of a byte: the loop has a turn for every bit that
# is left, at most, an element can end in the middle of the data, and the elements that the condition and the instances
# use are kept (the bound of `_ + nibbles.first` is the one of 4 bits).
meta:
  id: x_rep_until_bits
  endian: le
seq:
  - id: lead
    type: b1
  - id: flags
    type: b1
    repeat: until
    repeat-until: _
  - id: head
    type: b3
  - id: nibbles
    type: b4
    repeat: until
    repeat-until: _ == 3 or _ + nibbles.first == 30
  - id: tail
    type: u1
instances:
  first_plus:
    value: nibbles.first + 1
  mixed:
    value: nibbles.last * 1000 + nibbles.first
