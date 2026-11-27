# error: bit field `b` of little-endian bit order where bits of a big-endian read may be left
#
# The number of bits that the repetition reads depends on the data: three elements of 4 bits leave 4 bits, four leave none.
meta:
  id: bit_order_repeat
seq:
  - id: count
    type: u1
  - id: xs
    type: b4
    repeat: expr
    repeat-expr: count
  - id: b
    type: b4le
