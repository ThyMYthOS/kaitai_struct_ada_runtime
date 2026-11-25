meta:
  id: subscripts
  endian: le
seq:
  - id: qty
    type: u1
  - id: pick
    type: u1
  - id: items
    type: u2
    repeat: expr
    repeat-expr: qty
  - id: raw
    size: 4
  - id: records
    size: 3
    repeat: until
    repeat-until: _[0] == 0
instances:
  first_item:
    value: items[0]
  chosen_item:
    value: items[pick]
  raw_mid:
    value: raw[1]
  chosen_raw:
    value: raw[pick]
