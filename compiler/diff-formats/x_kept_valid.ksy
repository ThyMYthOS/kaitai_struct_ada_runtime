# a parse instance that depends on the position of the stream and is first needed by the `valid` of the elements of
# a repeat-until, in the first turn, before the end condition needs it
meta:
  id: x_kept_valid
seq:
  - id: vals
    type: u1
    repeat: until
    repeat-until: _ == limit
    valid:
      max: limit
instances:
  limit:
    pos: _io.pos + 1
    type: u1
