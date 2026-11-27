# error: parse instance `inst` with `repeat`
#
# A repeated parse instance is not generated, so what uses it is rejected with a message that names it, also where
# only `.size` of it is used.
meta:
  id: repeat_instance_size
  endian: be
seq:
  - id: a
    size: 0
    if: inst.size == 0
instances:
  inst:
    pos: 0
    type: u4
    repeat: eos
