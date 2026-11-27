# error: `%` of floating-point numbers
meta:
  id: float_modulo
  endian: le
seq:
  - id: a
    type: f8
instances:
  rest:
    value: a % 2.5
