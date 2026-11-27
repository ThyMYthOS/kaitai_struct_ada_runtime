meta:
  id: float_steps
  endian: le
doc: |
  A record whose parser takes nine decisions from floating-point numbers: the limits and an expression of
  `valid`, conditions (`if`), a size and a count computed with `to_i`, the end of a repetition
  (`repeat-until`) and a condition that compares two computed values. Every one of them is a step of
  `Parse` that computes with floats; the generated parser keeps the float operations of each step in a
  subprogram of its own, so that the proof of `Parse` does not see them.
seq:
  - id: scale
    type: f4
    valid:
      min: 0.0
      max: 100.0
  - id: gain
    type: f8
    valid:
      expr: _ * scale <= 1000.0
  - id: mode
    type: u1
  - id: boost
    type: u1
    if: scale > 1.0
  - id: label
    size: (scale * 2.0).to_i
  - id: weight_count
    type: f4
  - id: weights
    type: u1
    repeat: expr
    repeat-expr: (weight_count + 0.5).to_i
  - id: samples
    type: f4
    repeat: until
    repeat-until: _ >= 2.0 or _ < 0.0
  - id: trailer
    type: u1
    if: gain * 2.0 > scale + 1.0
  - id: tail
    size: (scale + 10.0).to_i
instances:
  doubled_scale:
    value: scale * 2.0
