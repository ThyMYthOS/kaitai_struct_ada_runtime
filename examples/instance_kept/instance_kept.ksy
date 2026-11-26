meta:
  id: instance_kept
  endian: le
seq:
  - id: records
    type: record
    repeat: expr
    repeat-expr: header.count
  - id: body
    size: len_body
  - id: numbers
    type: s2
    repeat: until
    repeat-until: _ == limit
instances:
  header:
    pos: _io.size - 5
    type: header_type
  len_body:
    value: header.body_len * 2
  limit:
    pos: _io.pos + 2
    type: s2
types:
  record:
    seq:
      - id: key
        type: u1
  header_type:
    seq:
      - id: count
        type: u4
      - id: body_len
        type: u1
