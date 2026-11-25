# The Kaitai Struct test suite against the Ada backend

Result of `scripts/run-kaitai-suite.sh` (see `compiler/README.md`, "Running
the Kaitai Struct test suite") on the 320 tests of `kaitai_struct_tests` at
commit `4108136c807f8df88df843de6571f1a7bf29c74e`, with the backend and the
runtime library of this commit. The test programs were built with
`-gnat2012 -gnata -gnatwa` and with the contracts of the library executed;
no program raised an exception, so no precondition or postcondition of a
generated parser was violated by any of these tests.

| Result | Tests |
|---|---|
| passed | 167 |
| failed | 8 |
| error | 0 |
| build failed | 0 |
| not generated | 145 |
| not translated | 0 |
| total | 320 |


`not translated` is empty: `AdaSG` expresses the asserts of all 175 tests
whose parser is generated. The 145 `not generated` tests are formats that the
backend rejects with a message (table below) or that the front end of the
compiler cannot load: 3 `imports_abs*` need `formats/ks_path/common/`, which is
a submodule of the tests repository that the checkout does not have, and 2
`expr_sizeof_value*` use the identifier `_sizeof`, which the compiler version
rejects.

## The 8 tests that failed

| Test | Verdict |
|---|---|
| `expr_sizeof_type_0`, `expr_sizeof_type_1` | backend bug |
| `expr_int_div` | backend: documented deviation from Kaitai semantics |
| `bytes_pad_term_equal`, `str_pad_term_equal`, `str_eos_pad_term_equal` | backend bug (probably) |
| `expr_io_eof_bits` | backend or runtime bug (probably) |
| `debug_array_user_eof_exception` | assumption of the test, documented difference |

None is a bug of `AdaSG`: the programs build, every other assert of these
tests is `ok`, and the failing assert is the one named below.

### `sizeof<type>` of a user type is in bits (`expr_sizeof_type_0`, `expr_sizeof_type_1`)

Smallest reproduction (`expr_sizeof_type_0`):

```yaml
types:
  block:
    seq: [{id: a, type: u1}, {id: b, type: u4}, {id: c, size: 2}]
instances:
  sizeof_block:
    value: sizeof<block>
```

Expected `1 + 4 + 2 = 7`, the generated `Sizeof_Block (R)` returns 56 (measured).
`AdaTranslator.sizeOf` takes `seqSize` of the user type, which is
`FixedSized(bits)`, as a number of bytes; the built-in types are right.
`sizeof_subblock` of `expr_sizeof_type_1` has the same cause (not measured).

### Integer division rounds towards zero (`expr_int_div`)

`value: -9837 / 13` is expected to be -757 and `int_s / 13` with
`int_s = -52947` to be -4073: the language is specified to floor
(kaitai_struct issue 746). The backend divides as C does; `docs/codegen.md`
lists "Integer division drops the fraction, as in C" among the differences.
Since the suite checks it, this is a deviation from the language, not only
from other targets. `a % b` follows the language (`expr_mod` passes), so
`Divide` and `Modulo` disagree about the sign. The positive cases pass. The
actual values were not printed; they follow from the documented behaviour.

### `pad-right` and `terminator` with `include: true` and the same byte (`bytes_pad_term_equal`, `str_pad_term_equal`, `str_eos_pad_term_equal`)

Smallest reproduction (`s4` of the three):

```yaml
seq:
  - id: s4
    size: 20
    terminator: 0x2e
    include: true
    pad-right: 0x2e
```

on the 20 bytes `str4baz@............`. Expected `str4baz@.` (the
terminator is included); the assert fails. The generated code does
`Strip_Right (Buffer, X, 46)` first and then `Terminate_At (Buffer, X, 46,
True)`, so the padding strip removes the terminator that should have been
included, and nothing is left to terminate at. The actual value was not
printed; the cause is read from the generated code. `s1` to `s3` of the same
files pass, so the order is right whenever terminator and padding differ. The
order that the expected values need: terminate first (keeping the terminator
if `include`), then strip the padding.

### `_io.eof` with unread bits (`expr_io_eof_bits`)

```yaml
meta: {id: expr_io_eof_bits, bit-endian: be}
seq:
  - {id: foo, type: b20}
  - {id: bar, type: b4, if: not _io.eof}
```

After `foo`, 4 bits of the third byte are unread, so `_io.eof` is false in the
reference implementations and `bar` is 0xf. In the Ada parser `Has_Bar` is
False (measured: `FAIL 2: bar (not defined)`). The cause is probably
`Is_EOF (S) is (Remaining (S) = 0)` in `src/kaitai-streams.ads`, which does
not look at the bits left over in the last byte (read, not confirmed by a
change). `expr_io_pos_bits` passes, so `Pos` is right.

### Partial results after a failed parse (`debug_array_user_eof_exception`)

The test is for `ks-debug` visualisers: the input is too short for
`array_of_cats[2].chirp`, and everything parsed before the error is expected
to be readable (`one_cat.meow`, `array_of_cats[1].chirp`, ...). The Ada
parsers have no partial results: after a failed `Parse`, `Valid (R)` is false
and no accessor may be called (`docs/codegen.md`, "Shape of a type"). All
eight asserts are therefore `FAIL ... (not defined)`, and the parse itself
reports `END_OF_STREAM`, the expected error. This is an assumption of the
test, not a defect.

### passed

bits_byte_aligned, bits_byte_aligned_eof_be, bits_byte_aligned_eof_le, bits_enum, bits_seq_endian_combo, bits_shift_by_b32_le, bits_shift_by_b64_le, bits_signed_res_b32_be, bits_signed_res_b32_le, bits_signed_shift_b32_le, bits_signed_shift_b64_le, bits_simple, bits_simple_le, bits_unaligned_b32_be, bits_unaligned_b32_le, bits_unaligned_b64_be, bits_unaligned_b64_le, buffered_struct, bytes_eos_pad_term, bytes_pad_term, bytes_pad_term_empty, bytes_pad_term_roundtrip, bytes_pad_term_zero_size, combine_bool, combine_enum, debug_0, debug_array_user, debug_enum_name, debug_switch_user, default_big_endian, default_bit_endian_mod, default_endian_expr_exception, default_endian_expr_inherited, default_endian_expr_is_be, default_endian_expr_is_le, default_endian_mod, docstrings, docstrings_docref, docstrings_docref_multi, enum_0, enum_1, enum_deep, enum_deep_literals, enum_fancy, enum_if, enum_int_range_s, enum_int_range_u, enum_invalid, enum_long_range_s, enum_negative, enum_of_value_inst, eof_exception_bits_be, eof_exception_bits_be2, eof_exception_bits_le, eof_exception_bits_le2, eof_exception_bytes, eof_exception_sized, eof_exception_switch_user, eof_exception_u4, eos_exception_bytes, eos_exception_sized, eos_exception_u4, expr_1, expr_bits, expr_enum, expr_if_int_eq, expr_io_pos, expr_io_pos_bits, expr_mod, fixed_contents, fixed_struct, hello_world, if_instances, if_struct, if_values, instance_std, integers, integers_double_overflow, integers_min_max, js_signed_right_shift, meta_tags, meta_xref, multiple_use, nav_parent_false2, nested_type_param, nested_types, nested_types2, nested_types3, non_standard, optional_id, params_call, params_call_extra_parens, params_enum, params_pass_bool, position_abs, position_to_end, repeat_eos_bytes, repeat_eos_bytes_pad, repeat_eos_bytes_pad_term, repeat_eos_struct, repeat_eos_term_bytes, repeat_eos_u4, repeat_n_bytes, repeat_n_bytes_pad, repeat_n_bytes_pad_term, repeat_n_struct, repeat_n_strz, repeat_n_strz_double, repeat_n_term_bytes, repeat_until_bytes_pad, repeat_until_bytes_pad_term, repeat_until_complex, repeat_until_s4, repeat_until_sized, str_encodings, str_encodings_default, str_encodings_escaping_enc, str_encodings_utf16, str_eos, str_eos_pad_term, str_eos_pad_term_empty, str_pad_term, str_pad_term_empty, str_pad_term_roundtrip, str_pad_term_utf16, str_pad_term_zero_size, switch_integers, switch_manual_enum, switch_manual_enum_invalid, switch_manual_enum_invalid_else, switch_manual_int, switch_manual_int_else, switch_manual_int_size, switch_manual_int_size_else, switch_manual_str, switch_manual_str_else, switch_multi_bool_ops, term_bytes, term_bytes2, term_bytes3, term_bytes4, term_strz, term_strz2, term_strz3, term_strz4, term_strz_utf16_v1, term_strz_utf16_v2, term_strz_utf16_v3, term_strz_utf16_v4, term_u1_val, ts_packet_header, type_int_unary_op, user_type, valid_fail_anyof_int, valid_fail_contents, valid_fail_eq_bytes, valid_fail_eq_int, valid_fail_eq_str, valid_fail_expr, valid_fail_in_enum, valid_fail_max_int, valid_fail_min_int, valid_fail_range_bytes, valid_fail_range_int, valid_not_parsed_if, valid_optional_id, valid_switch

### not generated: why the backend rejects the format

| Count | Reason | Tests |
|---|---|---|
| 21 | `process` | expr_if_int_ops, process_bytes_pad_term, process_coerce_bytes, process_coerce_switch, process_coerce_usertype1, process_coerce_usertype2, process_custom, process_custom_no_args, process_repeat_bytes, process_repeat_usertype, process_rotate, process_struct_pad_term, process_term_struct, process_to_user, process_xor4_const, process_xor4_value, process_xor_const, process_xor_value, type_ternary, zlib_surrounded, zlib_with_header_78 |
| 15 | imports | enum_import_literals, enum_import_seq, enum_to_i_class_border_1, imports0, imports_abs_abs, imports_abs_rel, imports_cast_to_imported, imports_cast_to_imported2, imports_circular_a, imports_params_def_array_usertype_imported, imports_params_def_enum_imported, imports_params_def_usertype_imported, imports_rel_1, name_clash_import_vs_inst, nested_types_import |
| 12 | `_parent` | debug_array_user_current_excluded, instance_io_user_earlier, nav_parent, nav_parent2, nav_parent3, nav_parent_false, nav_parent_override, nav_parent_switch, nav_parent_vs_value_inst, nested_same_name, nested_same_name2, switch_manual_int_size_eos |
| 9 | user type with a terminator or padding | repeat_eos_term_struct, repeat_n_term_struct, repeat_until_term_struct, struct_pad_term, struct_pad_term_equal, term_struct, term_struct2, term_struct3, term_struct4 |
| 8 | parameter of a type other than integer, boolean or enumeration | params_pass_array_int, params_pass_array_io, params_pass_array_str, params_pass_array_struct, params_pass_array_usertype, params_pass_io, params_pass_struct, params_pass_usertype |
| 6 | subscript of an array or of bytes | expr_bytes_ops, index_sizes, index_to_param_eos, index_to_param_expr, index_to_param_until, repeat_until_bytes |
| 6 | parse instance used in an expression | instance_in_repeat_expr, instance_in_repeat_until, instance_in_sized, position_in_seq, valid_fail_contents_inst, valid_fail_inst |
| 6 | `valid` on a repeated field | valid_fail_repeat_anyof_int, valid_fail_repeat_contents, valid_fail_repeat_eq_int, valid_fail_repeat_expr, valid_fail_repeat_max_int, valid_fail_repeat_min_int |
| 4 | `.to_s` of an integer | bcd_user_type_be, bcd_user_type_le, enum_to_i, enum_to_i_invalid |
| 4 | cast (`.as<...>`) | cast_nested, expr_bytes_non_literal, io_local_var, nav_parent_switch_cast |
| 4 | floating-point arithmetic | expr_ops_parens, float_to_i, floating_points, valid_fail_range_float |
| 4 | `io` other than `_root._io` | instance_io_user, process_repeat_usertype_dynarg_custom, process_repeat_usertype_dynarg_rotate, process_repeat_usertype_dynarg_xor |
| 3 | value instance of bytes or string that is not a field | combine_bytes, combine_str, expr_bytes_cmp |
| 3 | string literal with characters outside printable ASCII | expr_str_encodings, str_literals_latin1, valid_eq_str_encodings |
| 3 | parse instance with `repeat` | instance_std_array, instance_user_array, valid_fail_repeat_inst |
| 3 | integer literal that does not fit into 64 bits does not fit into 64 bits | valid_long, valid_short, yaml_ints |
| 2 | string concatenation | expr_0, expr_3 |
| 2 | opaque type | opaque_external_type, type_ternary_opaque |
| 2 | switch on VBytes | switch_bytearray, switch_else_only |
| 2 | repetition of a field whose type depends on a value | switch_repeat_expr, switch_repeat_expr_invalid |
| 1 | recursive type cast_to_top | cast_to_top |
| 1 | enum value 18446744073709551615 does not fit into 64 bits | enum_long_range_u |
| 1 | parse instance `char5` of a nested value | expr_2 |
| 1 | repeated field `afloat` (only `.size` is supported) | expr_array |
| 1 | array literal that is not a list of bytes | expr_calc_array_ops |
| 1 | string interpolation | expr_fstring_0 |
| 1 | `_io` in a value instance | expr_io_eof |
| 1 | conditional expression that is not an integer or a boolean | expr_io_ternary |
| 1 | expr_sizeof_value_0: /: error: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/ | expr_sizeof_value_0 |
| 1 | expr_sizeof_value_sized: /: error: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/ | expr_sizeof_value_sized |
| 1 | `.reverse` of a string | expr_str_ops |
| 1 | `.to_i` of a string literal | expr_to_i_trailing |
| 1 | : /meta/imports/0: error: unable to find 'common/vlq_base128_le.ksy' in import search paths,  | imports_abs |
| 1 | recursive type nav_parent_recursive | nav_parent_recursive |
| 1 | `_root` | nav_root |
| 1 | recursive type nav_root_recursive | nav_root_recursive |
| 1 | recursive type recursive_one | recursive_one |
| 1 | repetition of BitsType1(BigBitEndian) | repeat_eos_bits_b1 |
| 1 | repetition of BitsType(4,BigBitEndian) | repeat_eos_bits_b4 |
| 1 | repeated field `records` (only `.size` is supported) | repeat_until_calc_array_type |
| 1 | repeated field `records1` (only `.size` is supported) | repeat_until_term_bytes |
| 1 | method `to_s` | str_encodings_escaping_to_s |
| 1 | value instance that needs the buffer in a type without slices | str_literals2 |
| 1 | field whose type depends on a value, used in an expression | switch_integers2 |
| 1 | value instance of type CalcUserType(List(foo),None,List(),false) | type_ternary_2nd_falsy |
| 1 | comparison of VStr(ASCII) with VStrLit(P) | valid_fail_range_str |


## Notes on the generator

- `AdaSG` takes every name from `AdaClassCompiler` (`memberName`,
  `memberBase`, `presenceName`, `isStored`, `valueInstanceUsesBuffer`,
  `valueInstanceHasGuard`, `encodingName`) and uses `AdaTranslator` for the
  literals of expected values. It copies two rules of the class compiler
  because they are private: the names of the variants of a switch
  (`X_Is_<Type>`, with `_2` for a second case of a type of the same name) and
  the component type of a switch of integers (the widest of the cases). If the
  compiler changes either, `AdaSG` has to follow; the first run after such a
  change shows it as `build failed`.
- Enumerations are compared by literal (`Is_X_Enum (V) and then To_X_Enum (V)
  = X_Label`) when the value is of the enumeration named in the assert.
- Not covered because no test needs it: asserts with `exception` for the
  access to a value (`AdaSG` reports such a test as `not translated`),
  parameters of the top-level type (no value to pass), recursive top-level
  types (`Depth`).
