# switches with sizes, with and without else, on enums and on integers
meta:
  id: x_switch_size
  endian: le
seq:
  - id: records
    type: record
    repeat: eos
enums:
  kind:
    1: num
    2: pair
    3: text
types:
  record:
    seq:
      - id: kind
        type: u1
        enum: kind
      - id: len
        type: u1
      - id: body
        size: len
        type:
          switch-on: kind
          cases:
            kind::num: num
            kind::pair: pair
      - id: other
        type:
          switch-on: len
          cases:
            0: u1
            1: u2
            2: u4
  num:
    seq:
      - id: value
        type: u2
  pair:
    seq:
      - id: x
        type: s1
      - id: y
        type: s1
