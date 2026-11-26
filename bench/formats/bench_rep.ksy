meta:
  id: bench_rep
  endian: le
seq:
  - id: num_items
    type: u4
  - id: items
    type: item
    repeat: expr
    repeat-expr: num_items
types:
  item:
    seq:
      - id: len
        type: u1
      - id: name
        type: str
        size: len
        encoding: ASCII
      - id: v
        type: u1
