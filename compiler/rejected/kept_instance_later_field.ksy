# error: parse instance `len` is first needed by the field `body`, but it needs the field `at`, which is read at the same place or after
meta:
  id: kept_instance_later_field
  endian: le
seq:
  - id: body
    size: len
  - id: at
    type: u1
instances:
  len:
    pos: at
    type: u1
