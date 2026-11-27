# A repetition of bit fields with a valid on each element, and nothing else: Parse has no use for a first
# assignment of the whole record, and does not write one.
meta:
  id: repeat_bits_valid
  endian: le
seq:
  - id: bits
    type: b4
    valid:
      max: 12
    repeat: expr
    repeat-expr: 4
