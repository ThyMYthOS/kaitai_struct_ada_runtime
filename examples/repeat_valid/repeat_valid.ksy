# `valid` and `contents` on the elements of a repetition that is read with a
# cursor: each element is checked as it is read
meta:
  id: repeat_valid
  endian: le
seq:
  - id: marks
    contents: [0x4B, 0x53]
    repeat: expr
    repeat-expr: 2
  - id: pairs
    size: 2
    valid:
      expr: _ != [0x00, 0x00]
    repeat: eos
