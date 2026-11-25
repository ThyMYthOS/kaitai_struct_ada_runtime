meta:
  id: showcase
  title: Showcase of the Ada backend
  endian: le
doc: |
  A file of entries, in the manner of many container formats: a magic number,
  a header, a counted list of entries, and records that are read until an
  end marker.

  The comments of the generated code show where each text of this
  description ends up.
doc-ref: https://doc.kaitai.io/user_guide.html Kaitai Struct user guide
params:
  - id: scale
    type: u2
    doc: Factor that turns the number of entries into the total
seq:
  - id: magic
    contents: [0x53, 0x48]
  - id: kind
    type: u1
    enum: kind
    doc: What the entries of the file are
  - id: num_entries
    type: u2
    doc: Number of entries that follow the header
  - id: header
    type: header
  - id: entries
    type: entry(header.flags)
    repeat: expr
    repeat-expr: num_entries
    doc: The entries, each with the flags of the header
  - id: tail_len
    type: u4
    if: kind == kind::big
    doc: Length of the tail; only big files have one
  - id: points
    type: entry::point
    repeat: until
    repeat-until: _.x == 0
    doc: Points up to and including the first one with `x` of 0
  - id: len_log
    type: u1
  - id: log
    type: log
    size: len_log
  - id: samples
    type: u2
    repeat: eos
    doc: Samples that fill the rest of the file
instances:
  total:
    value: num_entries * scale + header.version
    doc: Number of entries, scaled, plus the version of the header
  first_entry:
    pos: 5 + header.len_name
    type: entry(0)
    doc: The entry that follows the name in the header, read without the flags of the header
enums:
  kind:
    1:
      id: small
      doc: A file of few entries
    2:
      id: big
      doc: A file that has a tail
types:
  header:
    doc: Fixed part at the start of the file, with the name of the file
    seq:
      - id: version
        type: u1
        doc: Version of the format
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
    doc: One entry of the file; what follows its code depends on the code
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
        doc: A point in the plane
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
