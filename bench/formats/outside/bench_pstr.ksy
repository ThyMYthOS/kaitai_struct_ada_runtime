meta:
  id: bench_pstr
  endian: le
  encoding: ascii
seq:
  - id: key
    type: str
    size: 4
  - id: count
    type: u1
  - id: items
    type: item(key)
    repeat: expr
    repeat-expr: count
types:
  item:
    params:
      - id: key
        type: str
    seq:
      - id: body
        type: str
        size: key.length
    instances:
      is_key:
        value: body == key
