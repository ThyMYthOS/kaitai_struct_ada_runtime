meta:
  id: bits_after_bytes
seq:
  - id: tag
    type: u1
  # entered at a byte boundary, as is the first field of header
  - id: head
    type: header
  - id: tail
    type: u1
types:
  header:
    seq:
      - id: flags
        type: flags_type
      # goes on in the byte that flags leaves open
      - id: level
        type: b4
      - id: size
        type: u1
  flags_type:
    seq:
      - id: ready
        type: b1
      - id: mode
        type: b3
