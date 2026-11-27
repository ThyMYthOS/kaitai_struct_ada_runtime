# error: bit field `b` of little-endian bit order where bits of a big-endian read may be left
#
# `b4be` leaves four bits of the byte. The runtimes of the other targets keep the value of the bits that are left and
# let `b4le` take them (the low four bits of the byte); `Kaitai.Streams` takes the bits as the order of the new read sees
# the byte, which are the four that `a` has consumed. The two differ, and no meaning is chosen for the Ada parser: a
# change of the bit order inside a byte is rejected, the order can change only at a byte boundary.
meta:
  id: bit_order_in_seq
seq:
  - id: a
    type: b4be
  - id: b
    type: b4le
