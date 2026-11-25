# integer expressions: overflow, shifts, division and modulo of negative numbers, conditions
meta:
  id: x_expr
  endian: le
seq:
  - id: a
    type: s4
  - id: b
    type: s4
  - id: c
    type: u8
  - id: d
    type: u1
  - id: bytes
    size: 3
instances:
  sum:
    value: a + b
  diff:
    value: a - b
  prod:
    value: a * b
  quot:
    value: a / b
  rest:
    value: a % b
  big:
    value: c * 2
  shl:
    value: a << d
  shr:
    value: a >> d
  mix:
    value: (a & 0xff) | (b ^ 3)
  neg:
    value: -a
  pick:
    value: 'a > b ? a : b'
  flag:
    value: a < b and not (d == 0)
  first_byte:
    value: bytes[0]
  max_byte:
    value: bytes.max
  len_ok:
    value: bytes.size == 3
