meta:
  id: float_reading
  endian: le
doc: |
  Floating-point fields and expressions: a reading of a sensor with a gain, a fraction that has to be
  between 0 and 1, and an optional bias. Every expression is computed in 64-bit floats; an expression
  whose result would be infinity, or that uses a float that is infinity or not-a-number, has no value.
seq:
  - id: celsius
    type: f4
  - id: gain
    type: f8
  - id: count
    type: u2
  - id: fraction
    type: f4be
    valid:
      min: 0.0
      max: 1.0
  - id: has_bias
    type: u1
  - id: bias
    type: f8be
    if: has_bias != 0
instances:
  kelvin:
    value: celsius + 273.15
  whole_kelvin:
    value: kelvin.to_i
  freezing:
    value: celsius <= 0.0
  negated:
    value: -celsius
  scaled:
    value: gain * count
  blend:
    value: (celsius + 0.5) * fraction - 2.0
  biased:
    value: 'has_bias != 0 ? gain + bias : gain'
  capped:
    value: 'fraction > 0.5 ? 1 : fraction'
  gain_squared:
    value: gain * gain
  gain_squared_whole:
    value: gain_squared.to_i
