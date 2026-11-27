# error: division of floating-point numbers (`/`) is not supported
meta:
  id: float_division_int
  endian: le
seq:
  - id: a
    type: f4
  - id: n
    type: u1
instances:
  per_n:
    value: a / n
