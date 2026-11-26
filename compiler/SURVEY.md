# Survey of the Kaitai Struct test formats

The generator was run over all 334 `.ksy` files of `kaitai_struct_tests/formats` by `scripts/survey.sh --prove`, with the import path `formats/` and `formats/ks_path/` (what the tests call `$KS_PATH`) and, for `imports_abs`, a checkout of `kaitai_struct_formats` as `KSF_DIR`.

| Result | Formats |
|---|---|
| generated | 245 |
| rejected by the Ada backend with a clear error | 89 |
| failed before the backend (an import was not found) | 0 |
| crashed (stack trace or internal error) | 0 |

Without `KSF_DIR` the file `common/vlq_base128_le.ksy` is not found and `imports_abs` fails before the backend (1 of the 334); the other numbers do not change.

## Rejected

| Count | Reason | Formats |
|---|---|---|
| 7 | cast (`.as<...>`) | cast_nested, cast_to_top, expr_bytes_non_literal, imports_abs, io_local_var, params_pass_array_int, switch_cast |
| 6 | parse instance used in an expression | instance_in_repeat_expr, instance_in_repeat_until, instance_in_sized, position_in_seq, valid_fail_contents_inst, valid_fail_inst |
| 6 | expression that depends on a processed value | expr_if_int_ops, process_coerce_bytes, process_coerce_usertype1, process_coerce_usertype2, type_ternary, type_ternary_opaque |
| 4 | repeated field (only `.size` is supported) | expr_array, repeat_until_calc_array_type, repeat_until_term_bytes, repeat_until_term_struct |
| 4 | `.to_s` of an integer | bcd_user_type_be, bcd_user_type_le, enum_to_i, enum_to_i_invalid |
| 4 | floating-point arithmetic | expr_ops_parens, float_to_i, floating_points, valid_fail_range_float |
| 4 | repetition of bit fields or of a field whose type depends on a value | repeat_eos_bits_b1, repeat_eos_bits_b4, switch_repeat_expr, switch_repeat_expr_invalid |
| 4 | types that contain each other | enum_to_i_class_border_1, enum_to_i_class_border_2, imports_circular_a, imports_circular_b |
| 4 | value instance of bytes or string that is not a field | combine_bytes, combine_str, expr_bytes_cmp, expr_bytes_ops |
| 4 | `_io` of a value from outside other than `.size` | instance_io_user, process_repeat_usertype_dynarg_custom, process_repeat_usertype_dynarg_rotate, process_repeat_usertype_dynarg_xor |
| 3 | a value of `_parent` or `_root` that is not an integer, a boolean or an enumeration | index_to_param_eos, index_to_param_expr, index_to_param_until |
| 3 | parse instance with `repeat` | instance_std_array, instance_user_array, valid_fail_repeat_inst |
| 3 | array literal that is not a list of bytes | expr_calc_array_ops, params_pass_array_str, params_pass_array_struct |
| 2 | parameter of a type other than integer, boolean or enumeration | cast_to_imported2, imports_cast_to_imported2 |
| 2 | `process` on a repeated field | process_repeat_bytes, process_repeat_usertype |
| 2 | `valid` on a repeated field that is not a repetition of integers of a fixed size | valid_fail_repeat_contents, valid_fail_repeat_expr |
| 2 | string concatenation | expr_0, expr_3 |
| 2 | value instance that needs the buffer in a type without slices | str_literals, str_literals2 |
| 2 | `_root` used as a value | nav_parent2, nav_parent3 |
| 2 | string literal with a character that a string in Shift_JIS cannot hold or that the Ada backend cannot encode in it (it encodes ASCII, UTF-8, ISO-8859-1, UTF-16LE and UTF-16BE, and for other encodings only ASCII characters) | expr_str_encodings, valid_eq_str_encodings |
| 2 | subscript of a repeated member | imports_params_def_array_usertype_imported, params_pass_array_usertype |
| 1 | `.reverse` of a string | expr_str_ops |
| 1 | `_index` | index_sizes |
| 1 | `_io` in a value instance | expr_io_eof |
| 1 | `_root` in a description whose top-level type contains itself | nav_root_recursive |
| 1 | `process` in a field whose type depends on a value | process_coerce_switch |
| 1 | a field whose type depends on a value and can be the type itself | recursive_one |
| 1 | conditional expression that is not an integer or a boolean | expr_io_ternary |
| 1 | encoding name that Kaitai Struct does not know (`ASCII\\x`) | str_encodings_escaping_enc |
| 1 | field whose type depends on a value, used in an expression | switch_integers2 |
| 1 | method `to_s` | str_encodings_escaping_to_s |
| 1 | parse instance of a nested value | expr_2 |
| 1 | string interpolation | expr_fstring_0 |
| 1 | value instance of a user type | type_ternary_2nd_falsy |
| 1 | `_parent` in the top-level type of a description, which has no parent | nav_parent_recursive |
| 1 | `_parent` member that is parsed after the field that needs it | debug_array_user_current_excluded |
| 1 | `_parent` or `_root` followed by a member that the type does not have or that cannot be passed | instance_io_user_earlier |
| 1 | the key `parent: false` on a field of a type that uses `_parent` | nav_parent_false |

## Formats that failed before the backend, and what happened to them

These five formats used to fail before the backend. None of them failed in the front end of the compiler.

- `expr_sizeof_value_0`, `expr_sizeof_value_sized`: the backend asked the type provider for a member called `_sizeof`, which is no valid identifier; the error came from there. The other targets translate `_sizeof` before they look for a member. Both generate now.
- `imports_abs_abs`, `imports_abs_rel`: the description imports `/for_abs_imports/...`, which is a path below `$KS_PATH`. The tests keep these files in `formats/ks_path/`, a directory the survey did not give the compiler as an import path. Both generate with it.
- `imports_abs`: imports `/common/vlq_base128_le`, a file of the repository `kaitai-io/kaitai_struct_formats`, which is not part of the tests. It is found when `KSF_DIR` names a checkout of that repository. The format is then rejected by the backend like any other that uses `vlq_base128_le`: the first construct the backend does not support is a cast (`.as<u8>`) in the type `group`; the type `vlq_base128_le` also has a repeated field that its instance uses.

## Compilation and proof of the generated parsers

Every generated parser (and every imported description that came with it) was compiled with `-gnat2012 -gnata -gnatwa -gnatwe` and the style switches of the repository, and run through `gnatprove --level=1` with the switches of the examples (`--checks-as-errors=on`), by the same script.

- Compiled without a message: **245 of 245**.
- Proved without a message (no unproved check, no warning): **245 of 245**.
- No parser has a message or an unproved check.

The formats that are examples (`examples/`) are proved by `scripts/check.sh prove` as well.

## With `--read-write`

`scripts/survey.sh --read-write --prove` gives the compiler the
option that makes it generate `Write` for every type.

| Result | Formats |
|---|---|
| generated | 231 |
| rejected by the Ada backend with a clear error | 103 |
| failed before the backend | 0 |
| crashed | 0 |

All 231 parsers, with their `Write`, compile without a message (231 of 231) and are
proved without a message (231 of 231; no unproved check, no warning). Of the 245 formats that generate without the option,
14 are rejected with it:

| Count | Reason | Formats |
|---|---|---|
| 5 | a terminator of more than one byte | str_pad_term_utf16, term_strz_utf16_v1, term_strz_utf16_v2, term_strz_utf16_v3, term_strz_utf16_v4 |
| 4 | a field whose type is an integer of different kinds, chosen by a value | non_standard, switch_integers, switch_multi_bool_ops, valid_switch |
| 3 | an opaque type whose package has no `Write` in the contract | opaque_external_type, opaque_external_type_02_parent, opaque_with_param |
| 2 | a value cut from bytes with a size and a terminator or padding | struct_pad_term, struct_pad_term_equal |

Six formats that are rejected without the option are rejected with another
message: `cast_to_top`,
`nav_parent_recursive`, `nav_root_recursive` and `recursive_one` (the type contains itself, so
`Write` is not generated for it), `type_ternary_opaque` (an opaque type without `Write`) and
`switch_integers2` (an integer of different kinds, chosen by a value).
