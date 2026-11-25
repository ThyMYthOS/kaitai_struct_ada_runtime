meta:
  id: bits_in_repeat
seq:
  - id: a
    type: b4
  # every element goes on in the byte that the one before it left open
  - id: items
    type: nib
    repeat: expr
    repeat-expr: 3
  - id: d
    type: u1
types:
  nib:
    seq:
      - id: lo
        type: b4
