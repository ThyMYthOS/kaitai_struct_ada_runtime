meta:
  id: x_floats_seq
  endian: le
doc: |
  Floats in the expressions that steer the parser, for the comparison with the Python target
  (scripts/diff-python.sh): a condition (`if`), a size and a count computed with `to_i`, the end of
  a repetition (`repeat-until`) and `valid` with an expression.
seq:
  - id: scale
    type: f4
  - id: gain
    type: f8
  - id: flag
    type: u1
    if: scale > 0.5
  - id: body
    size: (scale * 2.0).to_i
  - id: run
    type: series
  - id: level
    type: f8
    valid:
      expr: _ * 0.5 <= 100.0
  - id: tail
    type: u1
    if: gain + scale > level
types:
  series:
    seq:
      - id: count
        type: f4
      - id: items
        type: u1
        repeat: expr
        repeat-expr: (count + 0.5).to_i
      - id: samples
        type: f4
        repeat: until
        repeat-until: _ >= 2.0 or _ < 0.0
