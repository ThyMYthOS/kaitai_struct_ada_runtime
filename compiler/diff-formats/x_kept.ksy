# parse instances that the seq needs: a count that comes from a chain of two, a size and a switch from the
# instance of a nested type, a condition on bytes, a position from the stream where the instance is first
# needed (the end of a repeat-until), arguments of a type, a validation on another stream, failures inside them
meta:
  id: x_kept
  endian: le
seq:
  - id: top
    type: u1
  - id: tag_at
    type: u1
  - id: items
    type: u1
    repeat: expr
    repeat-expr: second
  - id: guard
    type: u1
    if: tag == [0x41, 0x42]
  - id: named
    type: str
    size: trailer.name_len
    encoding: ASCII
  - id: sw
    type:
      switch-on: trailer.mode
      cases:
        1: u1
        2: u2
  - id: vals
    type: u1
    repeat: until
    repeat-until: _ == limit
  - id: checked
    type: u1
    valid:
      max: root_top
  - id: sub
    type: sub_type(trailer.name_len)
instances:
  trailer:
    pos: _io.size - 6
    type: trailer_type
  last_byte:
    pos: _io.size - 1
    type: u1
  second:
    pos: last_byte
    type: u1
  tag:
    pos: 2
    size: 2
  root_top:
    io: _root._io
    pos: 0
    type: u1
  limit:
    pos: _io.pos + 1
    type: u1
    valid:
      max: 200
  twice:
    value: second * 2
  unused_by_seq:
    pos: 1
    type: u1
types:
  trailer_type:
    seq:
      - id: count
        type: u2
      - id: mode
        type: u1
      - id: name_len
        type: u1
      - id: pad
        type: u2
  sub_type:
    params:
      - id: len
        type: u1
    seq:
      - id: body
        type: u1
        repeat: expr
        repeat-expr: len
