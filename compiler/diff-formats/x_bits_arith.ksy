# Arithmetic on bit fields of a type, of a nested type, under `if`, with `valid`, an enumeration and the other bit
# order (after a whole byte), for the comparison with the Python target: the instances that cannot overflow have a
# value, the others are not defined
meta:
  id: x_bits_arith
  endian: le
seq:
  - id: n
    type: b4
  - id: m
    type: b4
  - id: wide
    type: b12
  - id: pad
    type: b4
  - id: huge
    type: b63
  - id: last
    type: b1
  - id: flag
    type: u1
  - id: cond
    type: b4
    if: flag == 1
  - id: checked
    type: b3
    valid:
      max: 6
  - id: sub
    type: sub
  - id: kind
    type: b3
    enum: e
  - id: gap
    type: u1
  - id: le
    type: le_bits
instances:
  plus:
    value: n + 1
  sum:
    value: m + n
  scaled:
    value: n * 1000000000000
  big:
    value: n * 1000000000000000000
  wide_x:
    value: wide * 1000 + 1
  huge_plus:
    value: huge + 1
  cond_plus:
    value: cond + 1
  checked_plus:
    value: checked + 1
  sub_plus:
    value: sub.n + sub.v + 1
  le_plus:
    value: le.n * 2 + 1
  kind_plus:
    value: kind.to_i + 1
enums:
  e:
    1: one
    2: two
types:
  sub:
    seq:
      - id: n
        type: b5
    instances:
      v:
        value: n + 1
  le_bits:
    meta:
      bit-endian: le
    seq:
      - id: n
        type: b6
