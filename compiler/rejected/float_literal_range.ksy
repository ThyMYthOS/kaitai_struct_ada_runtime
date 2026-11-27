# error: float literal 1.0E+400, which is beyond the range of a 64-bit float
meta:
  id: float_literal_range
  endian: le
seq:
  - id: a
    type: f8
instances:
  huge:
    value: a + 1.0e400
