# Bit fields before and after whole bytes, in both bit orders
meta:
  id: x_bits_mix
  endian: be
seq:
  - id: a
    type: b3
  - id: b
    type: b5
  - id: c
    type: u2
  - id: d
    type: b1
  - id: e
    type: b7
  - id: f
    type: b12
  - id: g
    type: u1
  - id: h
    type: b4
  - id: tail
    type: tail_le
types:
  tail_le:
    meta:
      bit-endian: le
    seq:
      - id: p
        type: u1
      - id: q
        type: b3
      - id: r
        type: b13
      - id: s
        type: b2
      - id: t
        type: u2le
