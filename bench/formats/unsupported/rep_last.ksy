meta:
  id: rep_last
  endian: le
  imports:
    - bench_rep
seq:
  - id: head
    type: bench_rep
  - id: tail
    size: head.items.last.len
