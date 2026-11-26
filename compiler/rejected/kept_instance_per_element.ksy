# error: parse instance `len` is first needed by an expression of the field `items` that is evaluated for each element of a repetition
#
# The size is evaluated once per element, so for no element at all the instance is never read.
meta:
  id: kept_instance_per_element
  endian: le
seq:
  - id: count
    type: u1
  - id: items
    size: len
    repeat: expr
    repeat-expr: count
instances:
  len:
    pos: 4
    type: u1
