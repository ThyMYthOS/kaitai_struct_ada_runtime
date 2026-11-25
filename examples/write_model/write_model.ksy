meta:
  id: write_model
  endian: le
params:
  - id: scale
    type: u2
seq:
  - id: magic
    contents: [0x53, 0x48]
  - id: kind
    type: u1
    enum: kind
  - id: num_entries
    type: u2
  - id: header
    type: header
  - id: entries
    type: entry(header.flags)
    repeat: expr
    repeat-expr: num_entries
  - id: tail_len
    type: u4
    if: kind == kind::big
  - id: points
    type: entry::point
    repeat: until
    repeat-until: _.x == 0
  - id: len_log
    type: u1
  - id: log
    type: log
    size: len_log
  - id: samples
    type: u2
    repeat: eos
instances:
  total:
    value: num_entries * scale + header.version
  first_entry:
    pos: 5 + header.len_name
    type: entry(0)
enums:
  kind:
    1: small
    2: big
types:
  header:
    seq:
      - id: version
        type: u1
      - id: flags
        type: u1
      - id: len_name
        type: u1
      - id: name
        type: str
        size: len_name - 3
        encoding: ASCII
  log:
    seq:
      - id: records
        type: entry::point
        repeat: eos
  entry:
    params:
      - id: flags
        type: u1
    seq:
      - id: code
        type: u1
      - id: body
        type:
          switch-on: code
          cases:
            1: point
            2: text
      - id: extra
        type: u1
        if: flags & 1 != 0
    types:
      point:
        seq:
          - id: x
            type: s2
          - id: y
            type: s2
      text:
        seq:
          - id: value
            type: strz
            encoding: ASCII
