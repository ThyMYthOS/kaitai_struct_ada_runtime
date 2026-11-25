meta:
  id: bench_bits_nested
seq:
  - id: a
    type: u1
  - id: b
    type: inner
types:
  inner:
    seq:
      - id: x
        type: b4
      - id: y
        type: b4
      - id: z
        type: b8
