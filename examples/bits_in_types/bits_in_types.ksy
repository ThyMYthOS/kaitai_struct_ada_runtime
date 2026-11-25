meta:
  id: bits_in_types
seq:
  - id: a
    type: b4
  # a type that starts with a bit field goes on in the byte that is left open
  - id: c
    type: child
  - id: d
    type: u1
types:
  child:
    seq:
      - id: lo
        type: b4
