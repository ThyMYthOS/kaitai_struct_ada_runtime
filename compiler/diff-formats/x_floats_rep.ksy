meta:
  id: x_floats_rep
  endian: le
doc: |
  Floats of the elements of repetitions that Parse keeps, for the comparison with the Python target
  (scripts/diff-python.sh): the first, the last and a numbered element of a repetition of structures in
  float expressions, also in the condition of a repeat-until that uses its own field.
seq:
  - id: n
    type: u1
  - id: recs
    type: rec
    repeat: expr
    repeat-expr: n
  - id: more
    type: rec
    repeat: until
    repeat-until: _.x > recs.first.x or more.size >= 3 or more.last.x < more.first.x
instances:
  fx:
    value: recs.first.x * 2.0
  hi:
    value: recs.last.x > 1.5
  second:
    value: recs[1].x.to_i
types:
  rec:
    seq:
      - id: x
        type: f4
