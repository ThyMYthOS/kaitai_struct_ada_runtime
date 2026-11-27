# error: with an index that is not a constant: its elements are parsed one by one and not kept
#
# `x[i]` of a repetition of structures with an index that comes from the data would parse the elements before it for
# every use, and the cost of a description would grow with the square of the input (about 2.7 instructions times the
# square of the size in bytes, measured with a repetition of two-byte elements).  Elements of an integer type of a fixed
# size are a slice and are indexed in constant time.
meta:
  id: rep_index_data
seq:
  - id: which
    type: u1
  - id: items
    type: item
    repeat: expr
    repeat-expr: 4
instances:
  chosen:
    value: items[which].a
types:
  item:
    seq:
      - id: a
        type: u1
