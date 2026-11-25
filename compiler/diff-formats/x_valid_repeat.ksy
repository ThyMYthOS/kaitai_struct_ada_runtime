# valid on single fields and on repetitions
meta:
  id: x_valid_repeat
  endian: le
seq:
  - id: count
    type: u1
    valid:
      max: 5
  - id: small
    type: u2
    repeat: expr
    repeat-expr: count
    valid:
      min: 1
      max: 300
  - id: kind
    type: u1
    valid:
      any-of: [1, 2, 3]
  - id: ids
    type: s2
    repeat: eos
    valid:
      expr: _ != 7
