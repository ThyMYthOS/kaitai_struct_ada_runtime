# parse instances: positions, sizes, conditions, another stream
meta:
  id: x_instances
  endian: le
seq:
  - id: ofs
    type: u2
  - id: len
    type: u1
  - id: flag
    type: u1
instances:
  at_ofs:
    pos: ofs
    type: u2
  chunk:
    pos: ofs
    size: len
  text:
    pos: ofs
    size: len
    type: str
    encoding: ASCII
  opt:
    pos: ofs + 1
    type: u1
    if: flag != 0
  head:
    io: _root._io
    pos: 0
    type: u1
  last:
    pos: _io.size - 1
    type: u1
  beyond:
    pos: ofs + len
    type: u4
