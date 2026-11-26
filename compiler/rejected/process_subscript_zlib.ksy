# error: subscript of field `packed` with `process: zlib`, which needs an array for the processed bytes
#
# The byte `i` of bytes that were processed with `xor` or `rol` is computed on the spot, from the byte in the input.
# With `zlib` every byte depends on those before it, and the processed bytes need an array that a parser does not
# have.
meta:
  id: process_subscript_zlib
  endian: le
seq:
  - id: packed
    size: 4
    process: zlib
instances:
  first:
    value: packed[0]
