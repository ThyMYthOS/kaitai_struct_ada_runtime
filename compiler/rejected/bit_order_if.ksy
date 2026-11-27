# error: bit field `b` of little-endian bit order where bits of a big-endian read may be left
#
# Whether bits are left depends on the data: `a` is read only if `flag` is above 128.
meta:
  id: bit_order_if
seq:
  - id: flag
    type: u1
  - id: a
    type: b4
    if: flag > 128
  - id: b
    type: b4le
