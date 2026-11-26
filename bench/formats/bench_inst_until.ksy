meta:
  id: bench_inst_until
  endian: le
seq:
  - id: entries
    type: s2
    repeat: until
    repeat-until: _ == 7
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
