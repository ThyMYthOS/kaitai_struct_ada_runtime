# a parse instance that depends on the position of the stream and is first needed by the `valid` of the elements of
# a repeat-until with a cursor, in the first turn, before the end condition needs it
meta:
  id: x_kept_valid_cursor
seq:
  - id: recs
    size: 2
    repeat: until
    repeat-until: _[0] == limit
    valid:
      expr: _[1] <= limit
instances:
  limit:
    pos: _io.pos + 2
    type: u1
