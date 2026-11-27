# The second element of a repetition of structures with a count from the data: Parse keeps it in the record, and
# the invariant of its loop says that it is there once the loop is past the second turn.
meta:
  id: repeat_second
  endian: le
seq:
  - id: n
    type: u1
  - id: recs
    type: rec
    repeat: expr
    repeat-expr: n
instances:
  second_a:
    value: recs[1].a
types:
  rec:
    seq:
      - id: a
        type: u1
