# error: whose elements are unsigned integers of 64 bits that may not fit a signed 64-bit integer
#
# Expressions are computed in signed 64 bits, so the least of unsigned integers of 8 bytes is not always a value.
meta:
  id: rep_min_u8
  endian: le
seq:
  - id: items
    type: u8
    repeat: eos
instances:
  smallest:
    value: items.min
