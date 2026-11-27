meta:
  id: repeat_elements
  endian: le
seq:
  - id: num_nums
    type: u1
  - id: nums
    type: u2
    repeat: expr
    repeat-expr: num_nums
  - id: recs
    type: rec
    repeat: until
    repeat-until: _.tag == 0
  - id: words
    type: strz
    encoding: ASCII
    repeat: expr
    repeat-expr: 2
  - id: more
    type: u1
    repeat: until
    repeat-until: _ == words.first.length + recs.last.tag
  - id: signed
    type: s2be
    repeat: expr
    repeat-expr: 2
instances:
  min_num:
    value: nums.min
  max_num:
    value: nums.max
  min_signed:
    value: signed.min
  max_signed:
    value: signed.max
  last_signed:
    value: signed.last
  first_num:
    value: nums.first
  last_num:
    value: nums.last
  second_num:
    value: nums[1]
  first_rec:
    value: recs.first
  rec_alias:
    value: recs
  last_tag:
    value: recs.last.tag
  w_last_len:
    value: words.last.length
  second_word_len:
    value: words[1].length
types:
  rec:
    seq:
      - id: tag
        type: u1
      - id: val
        type: u1
