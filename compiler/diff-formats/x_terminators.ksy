# terminators, padding and sizes in several combinations
meta:
  id: x_terminators
  endian: le
seq:
  - id: t1
    terminator: 0x2c
    include: true
  - id: t2
    terminator: 0x2c
    consume: false
  - id: sep
    size: 1
  - id: t3
    terminator: 0x3b
    eos-error: false
  - id: t4
    size: 6
    terminator: 0x40
  - id: t5
    size: 6
    pad-right: 0x2b
  - id: t6
    size: 8
    terminator: 0x40
    pad-right: 0x2b
    include: true
  - id: rest
    size-eos: true
