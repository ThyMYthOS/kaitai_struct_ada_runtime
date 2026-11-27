# Repetitions of bit fields until a condition, and what they do with the elements: one turn of the loop
# per bit that is left, at most, and the elements that expressions use (kept in the record) have the bound of
# their bits.
meta:
  id: repeat_bits_use
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
