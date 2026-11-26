# error: parse instance `len` is first needed by the field `body`, which has an `if`, where it may not be evaluated at all
#
# An instance is read where an expression first needs it, and its accessor returns the value that Parse kept. Here
# the first use is in the size of a field that is not always there, so the instance may never be read.
meta:
  id: kept_instance_conditional
  endian: le
seq:
  - id: flag
    type: u1
  - id: body
    size: len
    if: flag == 1
instances:
  len:
    pos: 4
    type: u1
