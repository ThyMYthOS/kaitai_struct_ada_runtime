# error: `_parent.factor` has the type FloatMultiType(Width8,Some(LittleEndian)); only integers, booleans and enumerations can be passed
meta:
  id: float_outside
  endian: le
seq:
  - id: factor
    type: f8
  - id: inner
    type: item
types:
  item:
    seq:
      - id: v
        type: u1
    instances:
      scaled:
        value: v * _parent.factor
