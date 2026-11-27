# error: bit field `a` of big-endian bit order where bits of a little-endian read may be left
#
# The type `le_t` ends with four bits of a little-endian read, which are left for the big-endian bit field `a` of the
# parent.
meta:
  id: bit_order_bits_after_type
seq:
  - id: t
    type: le_t
  - id: a
    type: b4
types:
  le_t:
    meta:
      bit-endian: le
    seq:
      - id: n
        type: b4
