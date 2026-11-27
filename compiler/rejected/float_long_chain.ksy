# error: an expression with more than 8 operations on floating-point numbers
meta:
  id: float_long_chain
  endian: le
seq:
  - id: x
    type: f8
instances:
  product:
    value: x * x * x * x * x * x * x * x * x * x
