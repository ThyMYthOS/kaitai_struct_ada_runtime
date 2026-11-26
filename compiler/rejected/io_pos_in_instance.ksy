# error: `_io.pos` in an expression of a parse instance
#
# The Ada accessor of an instance is called after the parser has run, so it
# would read the position at the start of the type; the other targets read it
# when the instance is first used.  With the data 00 01 02 03 04 05 the
# instance is byte 2 in Ada and byte 4 in Python.
meta:
  id: io_pos_in_instance
  endian: le
seq:
  - id: a
    type: u2
instances:
  late:
    pos: _io.pos + 2
    type: u1
