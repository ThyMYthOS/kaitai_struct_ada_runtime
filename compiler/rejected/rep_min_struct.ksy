# error: `.min` of the repeated member `items`, whose elements are not integers of a fixed size
#
# `.first`, `.last` and `x[constant]` of a repetition of structures, bytes or strings are kept by Parse, but the least
# or largest of such elements has to compare them (bytes and strings differ between the targets in how they order
# characters beyond the basic plane), and no description of the tests needs it.
meta:
  id: rep_min_struct
seq:
  - id: items
    type: item
    repeat: eos
instances:
  smallest:
    value: items.min
types:
  item:
    seq:
      - id: a
        type: u1
