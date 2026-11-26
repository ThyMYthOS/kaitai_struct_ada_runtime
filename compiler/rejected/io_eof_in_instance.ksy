# error: `_io.eof` in an expression of a parse instance
meta:
  id: io_eof_in_instance
  endian: le
seq:
  - id: a
    type: u2
instances:
  maybe:
    pos: 0
    type: u1
    if: not _io.eof
