# error: division of floating-point numbers (`/`) is not supported
meta:
  id: float_division
  endian: le
seq:
  - id: a
    type: f8
  - id: b
    type: f8
instances:
  ratio:
    value: a / b
