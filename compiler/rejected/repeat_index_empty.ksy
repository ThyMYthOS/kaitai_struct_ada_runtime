# error: whose count comes from the data, whose elements may read nothing, and whose parse depends on `_index`
#
# An element that reads nothing ends the loop of Parse if every element after it starts in the same state and reads
# nothing too, which is what keeps a count of billions in a file of a few bytes cheap.  An element that knows its
# number does not start in the same state as the one before it, so the loop cannot stop there, and nothing in the data
# bounds a count that is the value of a field: with the data 00 FF FF FF FF the loop would run 4294967295 times.
# A count that is a literal, elements of at least a byte, or a size that is a subscript `x[_index]` of a repetition
# of integers (the elements are then as many as `x` has, which the data bound) are accepted.
meta:
  id: repeat_index_empty
  endian: le
seq:
  - id: qty
    type: u4
  - id: rows
    type: row(_index)
    repeat: expr
    repeat-expr: qty
types:
  row:
    params:
      - id: n
        type: u4
    seq:
      - id: cells
        size: n
