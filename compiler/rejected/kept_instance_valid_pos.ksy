# error: parse instance `limit` is first needed by the `valid` of the field `a` and depends on `_io.pos` or `_io.eof`
#
# `valid` is evaluated after the field is read, so `_io.pos` is the position behind the field.
meta:
  id: kept_instance_valid_pos
  endian: le
seq:
  - id: a
    type: u1
    valid:
      max: limit
instances:
  limit:
    pos: _io.pos + 1
    type: u1
