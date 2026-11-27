# error: bit field `y` of little-endian bit order where bits of a big-endian read may be left
#
# The type of `x` is chosen by the data: a type that ends with four bits that it left, or one that reads whole bytes.
meta:
  id: bit_order_switch
seq:
  - id: kind
    type: u1
  - id: x
    type:
      switch-on: kind
      cases:
        0: whole
        1: half
  - id: y
    type: b4le
types:
  whole:
    seq:
      - id: v
        type: u1
  half:
    seq:
      - id: v
        type: b4
