meta:
  id: foreign
  title: Code that the description does not contain
  endian: be
  ks-opaque-types: true
doc: |
  An opaque type and two custom processes. The type `timestamp` and the
  processes `acme.scramble` and `unwrap` are packages that are written by hand
  (Timestamp, Acme.Scramble and Unwrap, next to this description); the
  generated parser calls them as the section "Foreign code" of
  docs/codegen.md says.
seq:
  - id: key
    type: u1
  - id: stamp
    type: timestamp(100)
  - id: len_text
    type: u1
  - id: text
    size: len_text
    process: acme.scramble(key, true, [0x0f, 0xf0])
  - id: len_frame
    type: u1
  - id: frame
    type: frame
    size: len_frame
    process: unwrap
  - id: stamps
    type: timestamp(key + 1)
    repeat: expr
    repeat-expr: 2
types:
  frame:
    seq:
      - id: a
        type: u2
      - id: b
        type: u1
