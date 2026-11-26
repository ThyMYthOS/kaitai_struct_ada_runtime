# Repetitions of bit fields: the elements are integers and booleans that the
# cursor reads again from the buffer.
meta:
  id: repeat_bits
  endian: le
seq:
  - id: qty
    type: u4
  - id: nibbles
    type: b4
    repeat: expr
    repeat-expr: qty
  - id: tail
    type: u1
  - id: flags
    type: b1
    repeat: eos
