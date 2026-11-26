# `_index` in the size of an element, as an argument of the type of the elements, and in the condition of repeat-until
meta:
  id: x_rep_index
  endian: le
  encoding: ASCII
seq:
  - id: qty
    type: u1
  - id: sizes
    type: u1
    repeat: expr
    repeat-expr: qty
  - id: bufs
    size: sizes[_index]
    repeat: expr
    repeat-expr: qty
  - id: names
    type: str
    size: sizes[_index]
    repeat: expr
    repeat-expr: qty
  - id: rows
    type: row(_index)
    repeat: expr
    repeat-expr: 3
  - id: steps
    type: cell
    repeat: until
    repeat-until: _.v == 0 or _index >= 3
  - id: cols
    type: row(_index * 2)
    repeat: eos
types:
  cell:
    seq:
      - id: v
        type: u1
  row:
    params:
      - id: n
        type: u4
    seq:
      - id: cells
        size: n
