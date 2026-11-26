meta:
  id: rep_prev_self
  endian: le
seq:
  - id: num_links
    type: u4
  - id: links
    type: link
    repeat: expr
    repeat-expr: num_links
types:
  link:
    seq:
      - id: len
        type: u1
      - id: name
        size: len
      - id: extra
        size: _parent.links[_index - 1].len
        if: _index > 0
