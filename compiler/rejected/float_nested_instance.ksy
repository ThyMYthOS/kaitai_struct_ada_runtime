# error: instance `scaled` of a nested value that is not an integer, a boolean or an enumeration
meta:
  id: float_nested_instance
  endian: le
seq:
  - id: inner
    type: item
instances:
  twice:
    value: inner.scaled
types:
  item:
    seq:
      - id: x
        type: f8
    instances:
      scaled:
        value: x * 2.0
