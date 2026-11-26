meta:
  id: bench_puser_v3
  endian: le
seq:
  - id: hdr
    type: header
  - id: num_items
    type: u1
  - id: items
    type: item
    repeat: expr
    repeat-expr: num_items
types:
  header:
    seq:
      - id: width
        type: u2
      - id: height
        type: u2
  item:
    seq:
      - id: x
        type: u1
      - id: y
        type: u1
      - id: pad
        size: _parent.hdr.height
    instances:
      inside:
        value: x < _parent.hdr.width and y < _parent.hdr.height
