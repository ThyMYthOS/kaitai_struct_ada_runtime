# error: bit field `n` of little-endian bit order where bits of a big-endian read may be left
#
# The type `le_t` starts with a little-endian bit field and is used after four bits of a big-endian read (the same as
# in bit_order_in_seq, through a nested type).
meta:
  id: bit_order_type_after_bits
seq:
  - id: a
    type: b4
  - id: t
    type: le_t
types:
  le_t:
    meta:
      bit-endian: le
    seq:
      - id: n
        type: b4
