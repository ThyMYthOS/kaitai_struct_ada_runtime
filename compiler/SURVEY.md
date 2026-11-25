# Survey of the Kaitai Struct test formats

The generator was run over all 334 `.ksy` files of `kaitai_struct_tests/formats` by `scripts/survey.sh --prove` (import path set to that directory).

| Result | Formats |
|---|---|
| generated | 213 |
| rejected by the Ada backend with a clear error | 116 |
| failed before the backend (the front end of the compiler rejected the input) | 5 |
| crashed (stack trace or internal error) | 0 |

## Rejected

| Count | Reason | Formats |
|---|---|---|
| 15 | parameter of a type other than integer, boolean or enumeration | cast_to_imported, cast_to_imported2, imports_cast_to_imported, imports_cast_to_imported2, imports_params_def_usertype_imported, params_def_array_usertype_imported, ... |
| 6 | parse instance used in an expression | instance_in_repeat_expr, instance_in_repeat_until, instance_in_sized, position_in_seq, valid_fail_contents_inst, valid_fail_inst |
| 5 | a value of `_parent` or `_root` that is not an integer, a boolean or an enumeration | debug_array_user_current_excluded, nav_parent_vs_value_inst, process_repeat_usertype_dynarg_custom, process_repeat_usertype_dynarg_rotate, process_repeat_usertype_dynarg_xor |
| 5 | cast (`.as<...>`) | cast_nested, cast_to_top, expr_bytes_non_literal, io_local_var, switch_cast |
| 5 | expression that depends on a processed value | expr_if_int_ops, process_coerce_bytes, process_coerce_usertype1, process_coerce_usertype2, type_ternary |
| 5 | repeated field (only `.size` is supported) | expr_array, imports_params_def_array_usertype_imported, repeat_until_calc_array_type, repeat_until_term_bytes, repeat_until_term_struct |
| 4 | `.to_s` of an integer | bcd_user_type_be, bcd_user_type_le, enum_to_i, enum_to_i_invalid |
| 4 | floating-point arithmetic | expr_ops_parens, float_to_i, floating_points, valid_fail_range_float |
| 4 | opaque type | opaque_external_type, opaque_external_type_02_parent, opaque_with_param, type_ternary_opaque |
| 4 | repetition of bit fields or of a field whose type depends on a value | repeat_eos_bits_b1, repeat_eos_bits_b4, switch_repeat_expr, switch_repeat_expr_invalid |
| 4 | types that contain each other | enum_to_i_class_border_1, enum_to_i_class_border_2, imports_circular_a, imports_circular_b |
| 4 | value instance of bytes or string that is not a field | combine_bytes, combine_str, expr_bytes_cmp, expr_bytes_ops |
| 3 | `_parent` or `_root` followed by a member that the type does not have (`_io`) | instance_io_user, instance_io_user_earlier, nav_parent_switch_cast |
| 3 | custom `process` | process_custom, process_custom_no_args, process_term_struct |
| 3 | integer literal does not fit into 64 bits | valid_long, valid_short, yaml_ints |
| 3 | parse instance with `repeat` | instance_std_array, instance_user_array, valid_fail_repeat_inst |
| 3 | string literal with characters outside printable ASCII | expr_str_encodings, str_literals_latin1, valid_eq_str_encodings |
| 3 | subscript of something that is not bytes or a repetition of integers | index_to_param_eos, index_to_param_expr, index_to_param_until |
| 2 | `process` on a repeated field | process_repeat_bytes, process_repeat_usertype |
| 2 | `valid` on a repeated field that is not a repetition of integers of a fixed size | valid_fail_repeat_contents, valid_fail_repeat_expr |
| 2 | parse instance whose type depends on a value | nav_parent2, nav_parent3 |
| 2 | string concatenation | expr_0, expr_3 |
| 2 | switch on VBytes | switch_bytearray, switch_else_only |
| 2 | the key `parent` on a field of a type that uses `_parent` | nav_parent_false, nav_parent_override |
| 2 | value instance that needs the buffer in a type without slices | str_literals, str_literals2 |
| 1 | `.reverse` of a string | expr_str_ops |
| 1 | `.to_i` of a string literal | expr_to_i_trailing |
| 1 | `_index` | index_sizes |
| 1 | `_io` in a value instance | expr_io_eof |
| 1 | `_parent` used as a value | nav_parent_recursive |
| 1 | `_root` in a description whose top-level type contains itself | nav_root_recursive |
| 1 | `valid` on a field whose type depends on a value | valid_switch |
| 1 | a type that starts with a bit field, used where the stream may be inside a byte | default_bit_endian_mod |
| 1 | `process` in a field whose type depends on a value | process_coerce_switch |
| 1 | a field whose type depends on a value and can be the type itself | recursive_one |
| 1 | array literal that is not a list of bytes | expr_calc_array_ops |
| 1 | comparison of a string with a literal of another kind | valid_fail_range_str |
| 1 | conditional expression that is not an integer or a boolean | expr_io_ternary |
| 1 | enum value does not fit into 64 bits | enum_long_range_u |
| 1 | field whose type depends on a value, used in an expression | switch_integers2 |
| 1 | method `to_s` | str_encodings_escaping_to_s |
| 1 | parse instance of a nested value | expr_2 |
| 1 | string interpolation | expr_fstring_0 |
| 1 | value instance of a user type | type_ternary_2nd_falsy |

## Failed before the backend

- `expr_sizeof_value_0`: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/
- `expr_sizeof_value_sized`: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/
- `imports_abs`: unable to find 'common/vlq_base128_le.ksy' in import search paths, using: List(.
- `imports_abs_abs`: unable to find 'for_abs_imports/imported_and_abs.ksy' in import search paths, us
- `imports_abs_rel`: unable to find 'for_abs_imports/imported_and_rel.ksy' in import search paths, us

The `imports_abs*` formats import files from directories (`common/`, `for_abs_imports/`) that the checked-out tests do not have.

## Compilation and proof of the generated parsers

Every generated parser (and every imported description that came with it) was compiled with `-gnat2012 -gnata -gnatwa -gnatwe` and the style switches of the repository, and run through `gnatprove --level=1` with the switches of the examples (`--checks-as-errors=on`), by the same script.

- Compiled without a message: **213 of 213**.
- Proved without a message (no unproved check, no warning): **213 of 213**.
- No parser has a message or an unproved check.

The formats that are examples (`examples/`) are proved by `scripts/check.sh prove` as well.

## With `--read-write`

`scripts/survey.sh --read-write --prove --jobs 3` gives the compiler the
option that makes it generate `Write` for every type.

| Result | Formats |
|---|---|
| generated | 203 |
| rejected by the Ada backend with a clear error | 126 |
| failed before the backend | 5 |
| crashed | 0 |

All 203 parsers, with their `Write`, compile without a message and are
proved without a message (no unproved check, no warning). Of the 213 formats that generate without the option,
10 are rejected with it:

| Count | Reason | Formats |
|---|---|---|
| 3 | a field whose type is an integer of different kinds, chosen by a value | non_standard, switch_integers, switch_multi_bool_ops |
| 5 | a terminator of more than one byte | str_pad_term_utf16, term_strz_utf16_v1, term_strz_utf16_v2, term_strz_utf16_v3, term_strz_utf16_v4 |
| 2 | a value cut from bytes with a size and a terminator or padding | struct_pad_term, struct_pad_term_equal |
