# bit fields that go on across the boundaries of types: a nested type, the
# elements of a repetition, the case of a switch and a conditional field
# start inside a byte; a whole-byte field aligns
meta:
  id: x_bits_types
seq:
  - id: sel
    type: u1
  - id: a
    type: b3
  - id: n
    type: node
  - id: b
    type: b2
  - id: items
    type: tri
    repeat: expr
    repeat-expr: 3
  - id: c
    type: b4
  - id: mid
    type: u1
  - id: f
    type: b2
  - id: sw
    type:
      switch-on: sel
      cases:
        1: node
        _: tri
  - id: g
    type: b3
  - id: opt
    type: tri
    if: sel == 1
  - id: tail
    type: u1
  - id: aligned
    type: node
types:
  node:
    seq:
      - id: x
        type: b5
      - id: y
        type: b6
  tri:
    seq:
      - id: v
        type: b3
