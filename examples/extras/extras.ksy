meta:
  id: extras
  endian: be
seq:
  - id: key
    type: u1
  - id: len_secret
    type: u1
  - id: secret
    size: len_secret
    process: xor(key)
  - id: len_packed
    type: u1
  - id: packed
    type: inner
    size: len_packed
    process: rol(3)
  - id: items
    type: item
    repeat: expr
    repeat-expr: 2
  - id: tree
    type: node
types:
  inner:
    seq:
      - id: a
        type: u2
      - id: b
        type: u1
  item:
    seq:
      - id: value
        size: _parent.len_secret
      - id: extra
        type: u1
        if: _root.key > 1
  node:
    seq:
      - id: tag
        type: u1
      - id: num_children
        type: u1
      - id: children
        type: node
        repeat: expr
        repeat-expr: num_children
      - id: weight
        type: u1
        if: _root.key != 0
