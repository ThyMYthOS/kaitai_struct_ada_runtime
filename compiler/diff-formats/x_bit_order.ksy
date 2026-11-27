# The bit order changes only at a byte boundary, in every way that stays generated: after bit fields of the other order
# that fill whole bytes (counted: 3 + 5, 4 + 4, 12 + 4 bits), where the boundary is reached only through the bits of a
# nested type or of the elements of a repetition, after a type that ends at a boundary, after a field that is read as
# whole bytes, after a substream, in a switch whose cases all read one byte, and where a type of the other order starts
# a bit field of its own after a boundary. (Where the order changes inside a byte the description is rejected, see
# compiler/rejected/bit_order_*.ksy.)
meta:
  id: x_bit_order
  endian: le
seq:
  - id: sel
    type: u1
  - id: a
    type: b3
  - id: b
    type: b5
  - id: c
    type: b4le
  - id: d
    type: b4le
  - id: e
    type: b3
  - id: five
    type: five_be
  - id: f
    type: b12le
  - id: g
    type: b4le
  - id: h
    type: b2
  - id: i
    type: b6
  - id: pair
    type: le_pair
  - id: j
    type: b4
  - id: k
    type: b4
  - id: nibbles
    type: b4
    repeat: expr
    repeat-expr: 2
  - id: l
    type: b8le
  - id: sw
    type:
      switch-on: sel
      cases:
        1: byte_be
        2: byte_le
        _: byte_whole
  - id: m
    type: b1le
  - id: n
    type: b7le
  - id: o
    type: b3
  - id: p
    type: u1
  - id: q
    type: b5le
  - id: sub
    type: le_half
    size: 1
  - id: r
    type: b4
  - id: s
    type: b4
  - id: pairs
    type: b2
    repeat: expr
    repeat-expr: 4
  - id: tail
    type: le_half
  - id: w
    type: b5le
    enum: e
  - id: z
    type: u1
instances:
  peek:
    pos: 0
    type: le_pair
enums:
  e:
    0: zero
    1: one
    5: five
types:
  five_be:
    seq:
      - id: v
        type: b5
  le_pair:
    meta:
      bit-endian: le
    seq:
      - id: x
        type: b3
      - id: y
        type: b5
  byte_be:
    seq:
      - id: v
        type: b8
  byte_le:
    meta:
      bit-endian: le
    seq:
      - id: v
        type: b8
  byte_whole:
    seq:
      - id: v
        type: u1
  le_half:
    meta:
      bit-endian: le
    seq:
      - id: x
        type: b3
