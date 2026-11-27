# error: `scale` has the type FloatMultiType(Width8,None); only integers, booleans and enumerations can be passed
meta:
  id: float_parameter
  endian: le
seq:
  - id: inner
    type: item(2.5)
types:
  item:
    params:
      - id: scale
        type: f8
    seq:
      - id: v
        type: u1
    instances:
      scaled:
        value: v * scale
