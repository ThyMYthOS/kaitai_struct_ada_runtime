# A repetition with a count whose elements can be empty.  The count comes
# from the data and can be far larger than the file.
meta:
  id: repeat_n_empty
  endian: le
seq:
  - id: len
    type: u1
  - id: qty
    type: u4
  - id: items
    type: item
    repeat: expr
    repeat-expr: qty
  - id: tail
    type: u1
types:
  item:
    seq:
      - id: content
        size: _parent.len
