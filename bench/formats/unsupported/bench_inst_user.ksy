meta:
  id: bench_inst_user
  endian: le
seq:
  - id: numbers
    type: u1
    repeat: expr
    repeat-expr: header.qty
  - id: entries
    type: s2
    repeat: until
    repeat-until: _ == header.limit
instances:
  header:
    pos: _io.size - 6
    type: header_obj
types:
  header_obj:
    seq:
      - id: qty
        type: u2
      - id: limit
        type: s2
      - id: tag
        size: 2
