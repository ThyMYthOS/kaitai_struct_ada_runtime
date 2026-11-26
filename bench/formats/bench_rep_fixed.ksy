meta:
  id: bench_rep_fixed
  endian: le
seq:
  - id: num_items
    type: u4
  - id: items
    type: u1
    repeat: expr
    repeat-expr: num_items
