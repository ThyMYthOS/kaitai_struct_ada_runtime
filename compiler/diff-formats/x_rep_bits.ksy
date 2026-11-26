# Repetitions of bit fields: a count, until the end, an enumeration, little endian bit order, and a byte between
meta:
  id: x_rep_bits
  endian: be
seq:
  - id: qty
    type: u1
  - id: nibbles
    type: b4
    repeat: expr
    repeat-expr: qty
  - id: wide
    type: b12
    repeat: expr
    repeat-expr: 2
  - id: kinds
    type: b2
    enum: kind
    repeat: expr
    repeat-expr: 3
  - id: sep
    type: u1
  - id: tail
    type: tail_le
enums:
  kind:
    0: zero
    1: one
    2: two
types:
  tail_le:
    meta:
      bit-endian: le
    seq:
      - id: lows
        type: b3
        repeat: expr
        repeat-expr: 3
      - id: flags
        type: b1
        repeat: eos
