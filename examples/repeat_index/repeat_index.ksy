# Elements that know their number: `_index` in the size of an element, and
# as an argument of the type of the elements.  The sizes are in a repetition
# of integers, so the elements that can be parsed are as many as the data
# have sizes for, however large the count is.
meta:
  id: repeat_index
  endian: le
seq:
  - id: qty
    type: u4
  - id: sizes
    type: u1
    repeat: expr
    repeat-expr: qty
  - id: bufs
    size: sizes[_index]
    repeat: expr
    repeat-expr: qty
  - id: rows
    type: row(_index)
    repeat: eos
types:
  row:
    params:
      - id: n
        type: u4
    seq:
      - id: cells
        size: n
