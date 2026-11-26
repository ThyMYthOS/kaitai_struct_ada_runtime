meta:
  id: rep_prev_other
  endian: le
  imports:
    - bench_rep
seq:
  - id: head
    type: bench_rep
  - id: blocks
    type: block
    repeat: expr
    repeat-expr: head.num_items
types:
  block:
    seq:
      - id: buf
        size: _root.head.items[_index - 1].len
        if: _index > 0
