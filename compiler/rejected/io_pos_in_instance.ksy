# error: `_io.pos` in an expression of a parse instance
#
# No expression of the sequence needs this instance, so Parse does not read it, and its accessor is called after the
# parser has run. It would read the position at the start of the type; the other targets read it when the instance
# is first used, which is after everything that was read before. With the data 00 01 02 03 04 05 the instance is
# byte 2 in Ada and byte 4 in Python. (For an instance that the sequence needs, `_io.pos` is the position where it
# is first needed: see examples/instance_kept.)
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
