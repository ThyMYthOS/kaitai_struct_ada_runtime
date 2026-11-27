# Arithmetic on bit fields in value instances: the accessors run after Parse, so what they know of a field
# is its type. A field of N bits is below 2**N, and the sums and products that cannot overflow ask no question.
meta:
  id: bits_arith
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
