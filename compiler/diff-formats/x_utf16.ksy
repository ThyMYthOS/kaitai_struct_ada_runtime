# Strings in UTF-16 and UTF-8: terminators, sizes, lengths, comparisons with literals
meta:
  id: x_utf16
  endian: le
seq:
  - id: len_a
    type: u1
  - id: a
    type: str
    size: len_a
    encoding: UTF-16LE
  - id: b
    type: str
    terminator: 0
    encoding: UTF-8
  - id: c
    type: str
    size: 6
    encoding: UTF-16BE
  - id: d
    type: strz
    encoding: UTF-8
instances:
  a_len:
    value: a.length
  c_len:
    value: c.length
  d_len:
    value: d.length
  b_is_x:
    value: b == "x"
  d_is_abc:
    value: d == "abc"
