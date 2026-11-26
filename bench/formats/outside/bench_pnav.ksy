meta:
  id: bench_pnav
  endian: le
  encoding: ascii
seq:
  - id: s1
    type: str
    terminator: 0x7c
  - id: count
    type: u1
  - id: items
    type: child
    repeat: expr
    repeat-expr: count
types:
  child:
    seq:
      - id: v
        type: u1
      - id: w
        type: u1
        if: _parent.s1 == 'foo'
    instances:
      do_something:
        value: _parent.s1 == 'foo'
