# `valid` and `contents` on each element of a repetition of bytes, strings and bit fields
meta:
  id: x_rep_valid
  endian: le
  encoding: ASCII
seq:
  - id: marks
    contents: [0x4B, 0x53]
    repeat: expr
    repeat-expr: 2
  - id: words
    type: str
    size: 2
    valid:
      any-of: ['"ab"', '"cd"', '"ef"']
    repeat: expr
    repeat-expr: 3
  - id: pairs
    size: 2
    valid:
      expr: _ != [0x00, 0x00]
    repeat: expr
    repeat-expr: 2
  - id: bits
    type: b4
    valid:
      max: 12
    repeat: expr
    repeat-expr: 4
  - id: tail
    type: u1
    repeat: eos
    valid:
      min: 1
