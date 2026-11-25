# Survey of the Kaitai Struct test formats

The generator was run over all 334 `.ksy` files of `kaitai_struct_tests/formats` by `scripts/survey.sh --prove`, with the import path `formats/` and `formats/ks_path/` (what the tests call `$KS_PATH`) and, for `imports_abs`, a checkout of `kaitai_struct_formats` as `KSF_DIR`.

| Result | Formats |
|---|---|
| generated | 227 |
| rejected by the Ada backend with a clear error | 107 |
| failed before the backend (an import was not found) | 0 |
| crashed (stack trace or internal error) | 0 |

Without `KSF_DIR` the file `common/vlq_base128_le.ksy` is not found and `imports_abs` fails before the backend (1 of the 334); the other numbers do not change.

## Rejected

| Count | Reason | Formats |
|---|---|---|
| 15 | parameter of a type other than integer, boolean or enumeration | cast_to_imported, cast_to_imported2, imports_cast_to_imported, imports_cast_to_imported2, imports_params_def_usertype_imported, params_def_array_usertype_imported, params_def_usertype_imported, params_pass_array_int, params_pass_array_io, params_pass_array_str, params_pass_array_struct, params_pass_array_usertype, params_pass_io, params_pass_struct, params_pass_usertype |
| 6 | cast (`.as<...>`) | cast_nested, cast_to_top, expr_bytes_non_literal, imports_abs, io_local_var, switch_cast |
| 6 | parse instance used in an expression | instance_in_repeat_expr, instance_in_repeat_until, instance_in_sized, position_in_seq, valid_fail_contents_inst, valid_fail_inst |
| 5 | a value of `_parent` or `_root` that is not an integer, a boolean or an enumeration | debug_array_user_current_excluded, nav_parent_vs_value_inst, process_repeat_usertype_dynarg_custom, process_repeat_usertype_dynarg_rotate, process_repeat_usertype_dynarg_xor |
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
| 3 | parse instance with `repeat` | instance_std_array, instance_user_array, valid_fail_repeat_inst |
| 3 | subscript of something that is not bytes or a repetition of integers | index_to_param_eos, index_to_param_expr, index_to_param_until |
| 2 | `process` on a repeated field | process_repeat_bytes, process_repeat_usertype |
| 2 | `valid` on a repeated field that is not a repetition of integers of a fixed size | valid_fail_repeat_contents, valid_fail_repeat_expr |
| 2 | parse instance whose type depends on a value | nav_parent2, nav_parent3 |
| 2 | string concatenation | expr_0, expr_3 |
| 2 | string literal with a character that a string in Shift_JIS cannot hold or that the backend cannot encode in it (the backend encodes ASCII, UTF-8, ISO-8859-1, UTF-16LE and UTF-16BE, and for other encodings only ASCII characters) | expr_str_encodings, valid_eq_str_encodings |
| 2 | the key `parent` on a field of a type that uses `_parent` | nav_parent_false, nav_parent_override |
| 2 | value instance that needs the buffer in a type without slices | str_literals, str_literals2 |
| 1 | `.reverse` of a string | expr_str_ops |
| 1 | `_index` | index_sizes |
| 1 | `_io` in a value instance | expr_io_eof |
| 1 | `_parent` used as a value | nav_parent_recursive |
| 1 | `_root` in a description whose top-level type contains itself | nav_root_recursive |
| 1 | `process` in a field whose type depends on a value | process_coerce_switch |
| 1 | a field whose type depends on a value and can be the type itself | recursive_one |
| 1 | array literal that is not a list of bytes | expr_calc_array_ops |
| 1 | conditional expression that is not an integer or a boolean | expr_io_ternary |
| 1 | encoding name that Kaitai Struct does not know (`ASCII\\x`) | str_encodings_escaping_enc |
| 1 | field whose type depends on a value, used in an expression | switch_integers2 |
| 1 | method `to_s` | str_encodings_escaping_to_s |
| 1 | parse instance of a nested value | expr_2 |
| 1 | string interpolation | expr_fstring_0 |
| 1 | value instance of a user type | type_ternary_2nd_falsy |

## Formats that failed before the backend, and what happened to them

These five formats used to fail before the backend. None of them failed in the front end of the compiler.

- `expr_sizeof_value_0`, `expr_sizeof_value_sized`: the backend asked the type provider for a member called `_sizeof`, which is no valid identifier; the error came from there. The other targets translate `_sizeof` before they look for a member. Both generate now.
- `imports_abs_abs`, `imports_abs_rel`: the description imports `/for_abs_imports/...`, which is a path below `$KS_PATH`. The tests keep these files in `formats/ks_path/`, a directory the survey did not give the compiler as an import path. Both generate with it.
- `imports_abs`: imports `/common/vlq_base128_le`, a file of the repository `kaitai-io/kaitai_struct_formats`, which is not part of the tests. It is found when `KSF_DIR` names a checkout of that repository. The format is then rejected by the backend like any other that uses `vlq_base128_le`: the first construct the backend does not support is a cast (`.as<u8>`) in the type `group`; the type `vlq_base128_le` also has a repeated field that its instance uses.

## Compilation and proof of the generated parsers

Every generated parser (and every imported description that came with it) was compiled with `-gnat2012 -gnata -gnatwa -gnatwe` and the style switches of the repository, and run through `gnatprove --level=1` with the switches of the examples (`--checks-as-errors=on`), by the same script.

- Compiled without a message: **227 of 227**.
- Proved without a message (no unproved check, no warning): **227 of 227**.
- No parser has a message or an unproved check.

The formats that are examples (`examples/`) are proved by `scripts/check.sh prove` as well.

## With `--read-write`

`scripts/survey.sh --read-write --prove --jobs 3` gives the compiler the
option that makes it generate `Write` for every type.

| Result | Formats |
|---|---|
| generated | 216 |
| rejected by the Ada backend with a clear error | 118 |
| failed before the backend | 0 |
| crashed | 0 |

All 216 parsers, with their `Write`, compile without a message (216 of 216) and are
proved without a message (216 of 216; no unproved check, no warning). Of the 227 formats that generate without the option,
11 are rejected with it:

| Count | Reason | Formats |
|---|---|---|
| 5 | a terminator of more than one byte | str_pad_term_utf16, term_strz_utf16_v1, term_strz_utf16_v2, term_strz_utf16_v3, term_strz_utf16_v4 |
| 4 | a field whose type is an integer of different kinds, chosen by a value | non_standard, switch_integers, switch_multi_bool_ops, valid_switch |
| 2 | a value cut from bytes with a size and a terminator or padding | struct_pad_term, struct_pad_term_equal |
