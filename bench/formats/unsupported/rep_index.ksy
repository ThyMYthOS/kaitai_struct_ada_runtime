meta:
  id: rep_index
  endian: le
  imports:
    - bench_rep
seq:
  - id: head
    type: bench_rep
  - id: num_refs
    type: u4
  - id: refs
    type: ref
    repeat: expr
    repeat-expr: num_refs
types:
  ref:
    seq:
      - id: idx
        type: u4
      - id: tag
        size: _root.head.items[idx].len
