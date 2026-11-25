meta:
  id: str_ordering
  encoding: UTF-8
seq:
  - id: a
    size: 2
    type: str
  - id: b
    size: 2
    type: str
instances:
  a_lt_b:
    value: a < b
  a_le_b:
    value: a <= b
  a_gt_pound:
    value: a > "£"
  pound_ge_b:
    value: '"£" >= b'
  literals:
    value: '"b" > "a"'
