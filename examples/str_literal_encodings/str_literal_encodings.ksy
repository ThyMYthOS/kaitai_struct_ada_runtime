meta:
  id: str_literal_encodings
seq:
  - id: latin1
    size: 1
    type: str
    encoding: ISO-8859-1
  - id: utf8
    size: 2
    type: str
    encoding: UTF-8
  - id: utf16le
    size: 4
    type: str
    encoding: UTF-16LE
  - id: utf16be
    size: 4
    type: str
    encoding: UTF-16BE
  - id: ascii
    size: 2
    type: str
    encoding: ASCII
  - id: tagged
    size: 2
    type: str
    encoding: UTF-16LE
    valid: '"a"'
instances:
  latin1_is_pound:
    value: latin1 == "£"
  utf8_is_pound:
    value: utf8 == "£"
  utf16le_is_pound_euro:
    value: utf16le == "£€"
  utf16be_is_grin:
    value: utf16be == "😀"
  ascii_has_newline:
    value: 'ascii == "a\n"'
  utf16be_is_not_grin:
    value: utf16be != "😀"
  grin_length:
    value: '"😀".length'
