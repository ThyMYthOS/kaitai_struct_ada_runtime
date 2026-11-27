meta:
  id: x_rep_self
  endian: le
doc: |
  Repetitions whose end depends on the repetition itself, for the comparison with the Python target
  (scripts/diff-python.sh): the condition of a repeat-until is evaluated when the field already holds
  the element just read, so `x.last` is that element, `x.size` counts it, and `x.first` and `x[1]` are
  there from the first and the second turn on.
seq:
  - id: recs
    type: rec
    repeat: until
    repeat-until: recs.last.a == 0 or recs.first.a == recs.size
  - id: pairs
    size: 2
    repeat: until
    repeat-until: (pairs.size > 1 and _ == pairs.first) or (pairs.size > 2 and pairs[1] == pairs.last)
  - id: nib
    type: b4
    repeat: until
    repeat-until: nib.last == nib.first + 1 or nib.size == 6
types:
  rec:
    seq:
      - id: a
        type: u1
        valid:
          expr: _ != 99
