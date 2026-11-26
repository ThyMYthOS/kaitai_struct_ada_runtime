# error: parse instance `raw` used in an expression (only an instance that an expression of the `seq` needs can be used, and none does)
#
# `twice` is not used by the sequence, so `raw` is not kept, and it is a procedure that parses at every call.
meta:
  id: kept_instance_unneeded
  endian: le
seq:
  - id: a
    type: u1
instances:
  raw:
    pos: 0
    type: u1
  twice:
    value: raw * 2
