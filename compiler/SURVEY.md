# Survey of the Kaitai Struct test formats

The generator was run over all 334 `.ksy` files of `kaitai_struct_tests/formats` (import path set to that directory).

| Result | Formats |
|---|---|
| generated | 177 |
| rejected by the Ada backend with a clear error | 152 |
| failed before the backend (the front end of the compiler rejected the input) | 5 |
| crashed (stack trace or internal error) | 0 |

## Rejected

| Count | Reason | Formats |
|---|---|---|
| 21 | `process` | expr_if_int_ops, process_bytes_pad_term, process_coerce_bytes, process_coerce_switch, process_coerce_usertype1, process_coerce_usertype2, ... |
| 20 | imports | cast_to_imported, cast_to_imported2, enum_import_literals, enum_import_seq, enum_to_i_class_border_1, enum_to_i_class_border_2, ... |
| 12 | `_parent` | debug_array_user_current_excluded, instance_io_user_earlier, nav_parent, nav_parent2, nav_parent3, nav_parent_false, ... |
| 9 | user type with a terminator or padding | repeat_eos_term_struct, repeat_n_term_struct, repeat_until_term_struct, struct_pad_term, struct_pad_term_equal, term_struct, ... |
| 8 | parameter of a type other than integer, boolean or enumeration | params_pass_array_int, params_pass_array_io, params_pass_array_str, params_pass_array_struct, params_pass_array_usertype, params_pass_io, ... |
| 6 | `valid` on a repeated field | valid_fail_repeat_anyof_int, valid_fail_repeat_contents, valid_fail_repeat_eq_int, valid_fail_repeat_expr, valid_fail_repeat_max_int, valid_fail_repeat_min_int |
| 6 | parse instance `X` used in an expression | instance_in_repeat_expr, instance_in_repeat_until, instance_in_sized, position_in_seq, valid_fail_contents_inst, valid_fail_inst |
| 6 | subscript of an array or of bytes | expr_bytes_ops, index_sizes, index_to_param_eos, index_to_param_expr, index_to_param_until, repeat_until_bytes |
| 5 | cast (`.as<...>`) | cast_nested, expr_bytes_non_literal, io_local_var, nav_parent_switch_cast, switch_cast |
| 4 | `.to_s` of an integer | bcd_user_type_be, bcd_user_type_le, enum_to_i, enum_to_i_invalid |
| 4 | `io` other than `_root._io` | instance_io_user, process_repeat_usertype_dynarg_custom, process_repeat_usertype_dynarg_rotate, process_repeat_usertype_dynarg_xor |
| 4 | floating-point arithmetic | expr_ops_parens, float_to_i, floating_points, valid_fail_range_float |
| 4 | opaque type | opaque_external_type, opaque_external_type_02_parent, opaque_with_param, type_ternary_opaque |
| 4 | recursive type | cast_to_top, nav_parent_recursive, nav_root_recursive, recursive_one |
| 3 | integer literal does not fit into 64 bits | valid_long, valid_short, yaml_ints |
| 3 | parse instance with `repeat` | instance_std_array, instance_user_array, valid_fail_repeat_inst |
| 3 | repeated field (only `.size` is supported) | expr_array, repeat_until_calc_array_type, repeat_until_term_bytes |
| 3 | string literal with characters outside printable ASCII | expr_str_encodings, str_literals_latin1, valid_eq_str_encodings |
| 3 | value instance of bytes or string that is not a field | combine_bytes, combine_str, expr_bytes_cmp |
| 2 | `_root` (only `_root._io` is supported) | nav_root, opaque_external_type_02_child |
| 2 | repetition of a field whose type depends on a value | switch_repeat_expr, switch_repeat_expr_invalid |
| 2 | repetition of bit fields | repeat_eos_bits_b1, repeat_eos_bits_b4 |
| 2 | string concatenation | expr_0, expr_3 |
| 2 | switch on VBytes | switch_bytearray, switch_else_only |
| 2 | value instance that needs the buffer in a type without slices | str_literals, str_literals2 |
| 1 | `.reverse` of a string | expr_str_ops |
| 1 | `.to_i` of a string literal | expr_to_i_trailing |
| 1 | `_io` in a value instance | expr_io_eof |
| 1 | array literal that is not a list of bytes | expr_calc_array_ops |
| 1 | comparison of a string with a literal of another kind | valid_fail_range_str |
| 1 | conditional expression that is not an integer or a boolean | expr_io_ternary |
| 1 | enum value does not fit into 64 bits | enum_long_range_u |
| 1 | field whose type depends on a value, used in an expression | switch_integers2 |
| 1 | method `to_s` | str_encodings_escaping_to_s |
| 1 | parse instance of a nested value | expr_2 |
| 1 | string interpolation | expr_fstring_0 |
| 1 | value instance of type CalcUserType(List(foo),None,List(),false) | type_ternary_2nd_falsy |

## Failed before the backend

- `expr_sizeof_value_0`: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/
- `expr_sizeof_value_sized`: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/
- `imports_abs`: unable to find 'common/vlq_base128_le.ksy' in the import search paths
- `imports_abs_abs`: unable to find 'for_abs_imports/imported_and_abs.ksy' in the import search paths
- `imports_abs_rel`: unable to find 'for_abs_imports/imported_and_rel.ksy' in the import search paths

The three `imports_abs*` formats import `common/vlq_base128_le.ksy`, which is not in the checked-out tests; imports are not supported by the backend anyway.

## Compilation of the generated parsers

All 177 generated parsers were compiled together (`gprbuild -c -k`, `-gnat2012 -gnatwa`, without `-gnatwe`, the
generated files as they come out of the compiler, not formatted).

- 174 of the 177 compiled at once. The other three (`enum_int_range_s`, `enum_long_range_s`, `enum_negative`) made
  GNAT run for many minutes without finishing: a `case` expression with a negative choice over a 64-bit type. The
  generator now writes an `if` expression for enumerations with a negative value; the three compile in under a second
  with the new generator, so 177 of 177 compile. Five formats had a compile error before small fixes
  (an empty `when others =>` branch of a switch without `else`, and a missing `use type` for the order of
  `Byte_Arrays.Compare`); those fixes are in the measured run.
- Warnings: none from the parsers themselves when contracts are compiled (`-gnata`, as in the tests project). Without
  `-gnata` 38 parsers get `formal parameter "Buffer" is not referenced`, because the only use of `Buffer` in a parser
  that reads nothing from the buffer is in its contracts. The other warnings come from the throw-away project
  (duplicate units from formats that define the same top-level name, a file name).

## Proof of a sample

32 of the generated parsers (every fifth of those that are not examples) were run through
`gnatprove --level=1`: `bits_byte_aligned_eof_be`, `bits_signed_res_b32_be`, `bits_unaligned_b32_be`,
`bytes_eos_pad_term`, `bytes_pad_term_zero_size`, `debug_array_user_eof_exception`, `default_endian_expr_exception`,
`docstrings_docref`, `enum_fancy`, `enum_long_range_s`, `eof_exception_bits_le`, `eof_exception_u4`, `expr_enum`,
`expr_io_pos_bits`, `if_instances`, `js_signed_right_shift`, `nested_type_param`, `optional_id`, `position_to_end`,
`repeat_eos_term_bytes`, `repeat_n_strz_double`, `repeat_until_sized`, `str_eos_pad_term`, `str_pad_term_equal`,
`switch_manual_enum`, `switch_manual_int_size_else`, `term_bytes2`, `term_strz4`, `term_u1_val`,
`valid_fail_anyof_int`, `valid_fail_in_enum`, `valid_not_parsed_if`.

Result: **all 32 are fully proved** (2326 checks, no unproved check). The first run showed ten flow warnings in
four of them (an element variable that a loop over strings set but never read, and the dead code of a field with
`if: false`); the generator was changed (the invariant of such a loop mentions the element; a condition that is a
literal produces no `if`), and the four formats were generated and proved again: all proved (1527 checks), no
warning. The 20 examples under `examples/` are proved by `scripts/check.sh prove`.

The survey was measured with the generator as of its last full run; the later changes only touch enumerations with
negative values, literal conditions and loops over strings, and the formats they touch were generated, compiled and
proved again as described.
