meta:
  id: bits_first_type
seq:
  # the first field of the top-level type is a type that starts with bits
  - id: head
    type: header
  - id: tail
    type: u1
types:
  header:
    seq:
      - id: flags
        type: flags_type
      - id: level
        type: b4
      - id: size
        type: u1
  flags_type:
    seq:
      - id: ready
        type: b1
      - id: mode
        type: b3
