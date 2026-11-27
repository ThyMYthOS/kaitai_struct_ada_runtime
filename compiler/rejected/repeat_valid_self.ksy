# error: `valid` of the repeated field `nibbles` that uses the field itself (its size or one of its elements)
#
# The other targets check each element when the field holds the elements up to it, so `nibbles.size` is 1 at the
# first element and 4 at the last. Here the count of a repetition with `repeat-expr` is known before the first
# element is read.
meta:
  id: repeat_valid_self
seq:
  - id: nibbles
    type: b4
    repeat: expr
    repeat-expr: 4
    valid:
      expr: _ < nibbles.size
