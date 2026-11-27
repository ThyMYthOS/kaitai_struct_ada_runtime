# error: which is too small for a 64-bit float
meta:
  id: float_literal_tiny
  endian: le
seq:
  - id: a
    type: f8
instances:
  tiny:
    value: a + 1.0e-400
