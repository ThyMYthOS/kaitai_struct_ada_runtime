meta:
  id: outside
  endian: le
  title: Values from outside that are not numbers
doc: |
  A type gets a string and a value of a user type from its parent, and asks the
  parent about a string. The parser of the child needs only what the type
  uses of them: the length of the string, two integers of the header, and
  whether the string of the parent is "foo". The parent computes these and
  passes them.
seq:
  - id: name
    type: str
    size: 3
    encoding: ASCII
  - id: head
    type: header
  - id: item
    type: item(name, head)
  - id: note
    type: note
types:
  header:
    seq:
      - id: width
        type: u1
      - id: height
        type: u1
  item:
    params:
      - id: key
        type: str
      - id: hdr
        type: header
    seq:
      - id: body
        size: key.length
      - id: pixels
        size: hdr.width * hdr.height
  note:
    seq:
      - id: text
        size: 2
    instances:
      from_foo:
        value: _parent.name == "foo"
