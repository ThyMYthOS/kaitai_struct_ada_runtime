# error: parse instance `len` used in an expression (it cannot be kept: it has `if`)
#
# A parse instance that the sequence needs is parsed once and kept. With an `if` it would have to be kept together
# with whether it is there, and used where it is not.
meta:
  id: kept_instance_if
  endian: le
seq:
  - id: flag
    type: u1
  - id: body
    size: len
instances:
  len:
    pos: 0
    type: u1
    if: flag == 1
