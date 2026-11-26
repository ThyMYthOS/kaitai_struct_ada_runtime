# error: integer literal 9223372036854775808 is above the largest signed 64-bit integer (2**63-1); expressions are computed in signed 64 bits, and such a literal is accepted only as an operand of a comparison with an unsigned field
meta:
  id: big_literal_arithmetic
  endian: le
seq:
  - id: a
    type: u8
instances:
  sum:
    value: a + 9223372036854775808
