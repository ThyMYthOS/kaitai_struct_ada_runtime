meta:
  id: bench_inst_int
  endian: le
seq:
  - id: chunks
    type: chunk
    repeat: expr
    repeat-expr: 8
instances:
  num_chunks:
    pos: _io.size - 4
    type: u4
types:
  chunk:
    seq:
      - id: offset
        type: u4
      - id: len
        type: u4
