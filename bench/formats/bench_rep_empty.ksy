meta:
  id: bench_rep_empty
  endian: le
seq:
  - id: num_items
    type: u4
  - id: flag
    type: u1
  - id: items
    type: item(flag)
    repeat: expr
    repeat-expr: num_items
types:
  item:
    params:
      - id: flag
        type: u1
    seq:
      - id: v
        type: u1
        if: flag != 0
