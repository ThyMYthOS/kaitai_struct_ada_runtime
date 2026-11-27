meta:
  id: x_floats
  endian: le
doc: |
  Floating-point expressions for the comparison with the Python target (scripts/diff-python.sh): the
  three arithmetic operations that are supported (the division is rejected, see compiler/rejected/),
  an integer and a float together, unary minus, the comparisons, the conditional, to_i, and
  validation of floats.
seq:
  - id: a
    type: f4
    valid:
      min: -1.0e30
      max: 1.0e30
  - id: b
    type: f8
  - id: c
    type: f4be
  - id: d
    type: f8be
  - id: n
    type: s2
  - id: m
    type: u4
  - id: has_e
    type: u1
  - id: e
    type: f4
    if: has_e != 0
    valid:
      any-of: [0.5, 1.5, 2.5]
  - id: inner
    type: item
instances:
  sum_ab:
    value: a + b
  diff_ab:
    value: a - b
  prod_ab:
    value: a * b
  prod_cd:
    value: c * d
  neg:
    value: -a
  half_b:
    value: b * 0.5
  plus_n:
    value: a + n
  n_minus_c:
    value: n - c
  m_times_b:
    value: m * b
  lt_ab:
    value: a < b
  le_ab:
    value: a <= b
  gt_ab:
    value: a > b
  ge_ab:
    value: a >= b
  eq_cc:
    value: c == c
  ne_cd:
    value: c != d
  lt_n:
    value: a < n
  c_at_least_quarter:
    value: c >= 0.25
  larger:
    value: 'a > b ? a : b'
  float_or_int:
    value: 'n > 0 ? c : 1'
  e_or_zero:
    value: 'has_e != 0 ? e : 0.0'
  to_i_a:
    value: a.to_i
  to_i_d:
    value: d.to_i
  to_i_sum:
    value: (a + b).to_i
  to_i_prod:
    value: prod_ab.to_i
  chain:
    value: (a * 2.0 + b * 0.5 - c) * 1.5
  literals:
    value: 0.1 + 0.2
  literal_to_i:
    value: (-2.7).to_i
  inner_plus_a:
    value: inner.x + a
  inner_x_to_i:
    value: inner.x.to_i
types:
  item:
    seq:
      - id: x
        type: f4
