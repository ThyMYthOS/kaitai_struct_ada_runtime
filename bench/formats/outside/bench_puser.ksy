meta:
  id: bench_puser
  endian: le
seq:
  - id: hdr
    type: header
  - id: count
    type: u1
  - id: items
    type: item(hdr)
    repeat: expr
    repeat-expr: count
types:
  header:
    seq:
      - id: width
        type: u2
      - id: height
        type: u2
  item:
    params:
      - id: hdr
        type: header
    seq:
      - id: x
        type: u1
      - id: y
        type: u1
      - id: pad
        size: hdr.height
    instances:
      inside:
        value: x < hdr.width and y < hdr.height
