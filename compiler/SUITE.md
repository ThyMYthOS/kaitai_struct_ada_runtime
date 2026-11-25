# The Kaitai Struct test suite against the Ada backend

Result of `scripts/run-kaitai-suite.sh` (see `compiler/README.md`, "Running
the Kaitai Struct test suite") on the 320 tests of `kaitai_struct_tests` at
commit `4108136c807f8df88df843de6571f1a7bf29c74e`, with the backend and the
runtime library of this commit. The test programs were built with
`-gnat2012 -gnata -gnatwa` and with the contracts of the library executed;
no program raised an exception, so no precondition or postcondition of a
generated parser was violated by any of these tests. The build log has no
warnings.

First run (before the backend learned `process`, `_parent`/`_root`, recursion,
imports and the fixes below): 167 passed, 8 failed, 145 not generated, 175
parsers. This run: 208 parsers, 207 test programs.

| Result | Tests |
|---|---|
| passed | 206 |
| failed | 0 |
| error | 0 |
| known difference | 1 |
| build failed | 0 |
| not generated | 112 |
| not translated | 1 |
| total | 320 |


The seven tests that failed in the first run for four reasons (`sizeof` of a
type, rounding of integer division, padding equal to the terminator,
`_io.eof` with unread bits) all pass now: `expr_sizeof_type_0`,
`expr_sizeof_type_1`, `expr_int_div`, `bytes_pad_term_equal`,
`str_pad_term_equal`, `str_eos_pad_term_equal`, `expr_io_eof_bits`.

`known difference` is the list `KNOWN_DIFFERENCES` of the script: a test that
fails for a documented reason. It is reported but does not make the script
fail. The exit status of this run is 0.

## What is not green

| Test | Class | Verdict |
|---|---|---|
| `nav_root_recursive` | not generated | rejected since this suite showed that it was translated wrongly |
| `debug_array_user_eof_exception` | known difference | documented difference (assumption of the test) |
| `nested_types_import` | not translated | AdaSG limit, by design |

### `_root` in a recursive top-level type (`nav_root_recursive`)

```yaml
seq:
  - {id: value, type: u1}
  - {id: next, type: nav_root_recursive, if: value == 0xff}
instances:
  root_value:
    value: _root.value
```

`next.root_value` is expected to be `0xff`, the value of the root
(kaitai_struct issue 1089, which the test is about). In the top-level type
the backend takes `_root.x` as the field `x` of the value itself. That is
wrong for a value that the top-level type parsed as a field of its own type:
the nested value would need the field of the outermost value, which it does
not know. An earlier state of the backend generated this format, and this
suite showed the wrong value (the `value` of the nested record instead of that
of the root). The backend now rejects `_root` in a description whose
top-level type contains itself.

### Partial results after a failed parse (`debug_array_user_eof_exception`)

The test is for `ks-debug` visualisers: the input is too short for
`array_of_cats[2].chirp`, and everything parsed before the error is expected to
be readable. The Ada parsers have no partial results: after a failed `Parse`,
`Valid (R)` is false and no accessor may be called (`docs/codegen.md`, "Shape
of a type"). All eight asserts are `FAIL ... (not defined)`; the parse itself
reports `END_OF_STREAM`, the expected error. A documented difference, listed in
`KNOWN_DIFFERENCES`.

### `nested_types_import` (not translated)

The test asserts that `_parent` and `_root` of types of an imported
description are `null`. Parsed values of the Ada backend have no `_parent` or
`_root` members at all, so there is nothing to compare with `null`; `AdaSG`
reports the reason and generates no program, so the five ordinary asserts of
the test are not run either (a limit of `AdaSG`, which does not translate
tests partially).

### passed

bits_byte_aligned, bits_byte_aligned_eof_be, bits_byte_aligned_eof_le, bits_enum, bits_seq_endian_combo, bits_shift_by_b32_le, bits_shift_by_b64_le, bits_signed_res_b32_be, bits_signed_res_b32_le, bits_signed_shift_b32_le, bits_signed_shift_b64_le, bits_simple, bits_simple_le, bits_unaligned_b32_be, bits_unaligned_b32_le, bits_unaligned_b64_be, bits_unaligned_b64_le, buffered_struct, bytes_eos_pad_term, bytes_pad_term, bytes_pad_term_empty, bytes_pad_term_equal, bytes_pad_term_roundtrip, bytes_pad_term_zero_size, combine_bool, combine_enum, debug_0, debug_array_user, debug_enum_name, debug_switch_user, default_big_endian, default_bit_endian_mod, default_endian_expr_exception, default_endian_expr_inherited, default_endian_expr_is_be, default_endian_expr_is_le, default_endian_mod, docstrings, docstrings_docref, docstrings_docref_multi, enum_0, enum_1, enum_deep, enum_deep_literals, enum_fancy, enum_if, enum_import_literals, enum_import_seq, enum_int_range_s, enum_int_range_u, enum_invalid, enum_long_range_s, enum_negative, enum_of_value_inst, eof_exception_bits_be, eof_exception_bits_be2, eof_exception_bits_le, eof_exception_bits_le2, eof_exception_bytes, eof_exception_sized, eof_exception_switch_user, eof_exception_u4, eos_exception_bytes, eos_exception_sized, eos_exception_u4, expr_1, expr_bits, expr_enum, expr_if_int_eq, expr_int_div, expr_io_eof_bits, expr_io_pos, expr_io_pos_bits, expr_mod, expr_sizeof_type_0, expr_sizeof_type_1, fixed_contents, fixed_struct, hello_world, if_instances, if_struct, if_values, imports0, imports_abs_abs, imports_abs_rel, imports_params_def_enum_imported, imports_rel_1, instance_std, integers, integers_double_overflow, integers_min_max, js_signed_right_shift, meta_tags, meta_xref, multiple_use, name_clash_import_vs_inst, nav_parent, nav_parent_false2, nav_parent_switch, nav_root, nested_same_name, nested_same_name2, nested_type_param, nested_types, nested_types2, nested_types3, non_standard, optional_id, params_call, params_call_extra_parens, params_enum, params_pass_bool, position_abs, position_to_end, process_bytes_pad_term, process_rotate, process_struct_pad_term, process_to_user, process_xor4_const, process_xor4_value, process_xor_const, process_xor_value, repeat_eos_bytes, repeat_eos_bytes_pad, repeat_eos_bytes_pad_term, repeat_eos_struct, repeat_eos_term_bytes, repeat_eos_term_struct, repeat_eos_u4, repeat_n_bytes, repeat_n_bytes_pad, repeat_n_bytes_pad_term, repeat_n_struct, repeat_n_strz, repeat_n_strz_double, repeat_n_term_bytes, repeat_n_term_struct, repeat_until_bytes_pad, repeat_until_bytes_pad_term, repeat_until_complex, repeat_until_s4, repeat_until_sized, str_encodings, str_encodings_default, str_encodings_escaping_enc, str_encodings_utf16, str_eos, str_eos_pad_term, str_eos_pad_term_empty, str_eos_pad_term_equal, str_pad_term, str_pad_term_empty, str_pad_term_equal, str_pad_term_roundtrip, str_pad_term_utf16, str_pad_term_zero_size, struct_pad_term, struct_pad_term_equal, switch_integers, switch_manual_enum, switch_manual_enum_invalid, switch_manual_enum_invalid_else, switch_manual_int, switch_manual_int_else, switch_manual_int_size, switch_manual_int_size_else, switch_manual_int_size_eos, switch_manual_str, switch_manual_str_else, switch_multi_bool_ops, term_bytes, term_bytes2, term_bytes3, term_bytes4, term_struct, term_struct2, term_struct3, term_struct4, term_strz, term_strz2, term_strz3, term_strz4, term_strz_utf16_v1, term_strz_utf16_v2, term_strz_utf16_v3, term_strz_utf16_v4, term_u1_val, ts_packet_header, type_int_unary_op, user_type, valid_fail_anyof_int, valid_fail_contents, valid_fail_eq_bytes, valid_fail_eq_int, valid_fail_eq_str, valid_fail_expr, valid_fail_in_enum, valid_fail_max_int, valid_fail_min_int, valid_fail_range_bytes, valid_fail_range_int, valid_not_parsed_if, valid_optional_id, valid_switch, zlib_surrounded, zlib_with_header_78

### not generated: why the backend rejects the format

| Count | Reason | Tests |
|---|---|---|
| 11 | parameter of a type other than integer, boolean or enumeration | imports_cast_to_imported, imports_cast_to_imported2, imports_params_def_usertype_imported, params_pass_array_int, params_pass_array_io, params_pass_array_str, params_pass_array_struct, params_pass_array_usertype, params_pass_io, params_pass_struct, params_pass_usertype |
| 7 | subscript of an array or of bytes | expr_bytes_ops, expr_if_int_ops, index_sizes, index_to_param_eos, index_to_param_expr, index_to_param_until, repeat_until_bytes |
| 6 | `_parent` ... | debug_array_user_current_excluded, nav_parent_recursive, nav_parent_vs_value_inst, process_repeat_usertype_dynarg_custom, process_repeat_usertype_dynarg_rotate, process_repeat_usertype_dynarg_xor |
| 6 | parse instance used in an expression | instance_in_repeat_expr, instance_in_repeat_until, instance_in_sized, position_in_seq, valid_fail_contents_inst, valid_fail_inst |
| 6 | `valid` on a repeated field | valid_fail_repeat_anyof_int, valid_fail_repeat_contents, valid_fail_repeat_eq_int, valid_fail_repeat_expr, valid_fail_repeat_max_int, valid_fail_repeat_min_int |
| 4 | `.to_s` of an integer | bcd_user_type_be, bcd_user_type_le, enum_to_i, enum_to_i_invalid |
| 4 | cast (`.as<...>`) | cast_nested, cast_to_top, expr_bytes_non_literal, io_local_var |
| 4 | floating-point arithmetic | expr_ops_parens, float_to_i, floating_points, valid_fail_range_float |
| 4 | field with process used in an expression | process_coerce_bytes, process_coerce_usertype1, process_coerce_usertype2, type_ternary |
| 3 | value instance of bytes or string that is not a field | combine_bytes, combine_str, expr_bytes_cmp |
| 3 | string literal with characters outside printable ASCII | expr_str_encodings, str_literals_latin1, valid_eq_str_encodings |
| 3 | parse instance with `repeat` | instance_std_array, instance_user_array, valid_fail_repeat_inst |
| 3 | custom `process` | process_custom, process_custom_no_args, process_term_struct |
| 3 | integer literal that does not fit into 64 bits does not fit into 64 bits | valid_long, valid_short, yaml_ints |
| 2 | string concatenation | expr_0, expr_3 |
| 2 | parse instance whose type depends on a value | nav_parent2, nav_parent3 |
| 2 | opaque type | opaque_external_type, type_ternary_opaque |
| 2 | `process` on a repeated field | process_repeat_bytes, process_repeat_usertype |
| 2 | repeated field `records1` (only `.size` is supported) | repeat_until_term_bytes, repeat_until_term_struct |
| 2 | switch on VBytes | switch_bytearray, switch_else_only |
| 2 | repetition of a field whose type depends on a value | switch_repeat_expr, switch_repeat_expr_invalid |
| 1 | enum value 18446744073709551615 does not fit into 64 bits | enum_long_range_u |
| 1 | types enum_to_i_class_border_1 and enum_to_i_class_border_2 contain each other (only a type that contains itse | enum_to_i_class_border_1 |
| 1 | parse instance `char5` of a nested value | expr_2 |
| 1 | repeated field `afloat` (only `.size` is supported) | expr_array |
| 1 | array literal that is not a list of bytes | expr_calc_array_ops |
| 1 | string interpolation | expr_fstring_0 |
| 1 | `_io` ... | expr_io_eof |
| 1 | conditional expression that is not an integer or a boolean | expr_io_ternary |
| 1 | expr_sizeof_value_0: /: error: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/ | expr_sizeof_value_0 |
| 1 | expr_sizeof_value_sized: /: error: invalid ID: '_sizeof', expected /^[a-z][a-z0-9_]*$/ | expr_sizeof_value_sized |
| 1 | `.reverse` of a string | expr_str_ops |
| 1 | `.to_i` of a string literal | expr_to_i_trailing |
| 1 | : /meta/imports/0: error: unable to find 'common/vlq_base128_le.ksy' in import search paths,  | imports_abs |
| 1 | types imports_circular_b and imports_circular_a contain each other (only a type that contains itself is suppor | imports_circular_a |
| 1 | repeated field `hws` (only `.size` is supported) | imports_params_def_array_usertype_imported |
| 1 | `_root.strings._io`: no such member in type instance_io_user | instance_io_user |
| 1 | `_parent.sized_b._io`: no such member in the type that has the field | instance_io_user_earlier |
| 2 | the key `parent` on a field of a type that uses `_parent` | nav_parent_false, nav_parent_override |
| 1 | `_parent._parent`: no such member in the type that has the field | nav_parent_switch_cast |
| 1 | `_root` in a description whose top-level type contains itself | nav_root_recursive |
| 1 | `process` in a field whose type depends on a value | process_coerce_switch |
| 1 | a field whose type depends on a value and can be the type itself | recursive_one |
| 1 | repetition of BitsType1(BigBitEndian) | repeat_eos_bits_b1 |
| 1 | repetition of BitsType(4,BigBitEndian) | repeat_eos_bits_b4 |
| 1 | repeated field `records` (only `.size` is supported) | repeat_until_calc_array_type |
| 1 | method `to_s` | str_encodings_escaping_to_s |
| 1 | value instance that needs the buffer in a type without slices | str_literals2 |
| 1 | field whose type depends on a value, used in an expression | switch_integers2 |
| 1 | value instance of type CalcUserType(List(foo),None,List(),false) | type_ternary_2nd_falsy |
| 1 | comparison of VStr(ASCII) with VStrLit(P) | valid_fail_range_str |


## Notes on the generator

- `AdaSG` takes names and rules from `AdaClassCompiler` (`memberName`,
  `memberBase`, `presenceName`, `isStored`, `base`, `hasBelongs`,
  `fullPackageOf`, `switchVariants`, `switchIntType`, `valueInstanceUsesBuffer`,
  `valueInstanceHasGuard`, `encodingName`) and `AdaTranslator` (`aggregate`,
  `hasProcess`, literals of expected values); it keeps no copy of them any more.
- Processed fields: the accessor is a procedure; the program allocates the target
  array on the heap (the size of the input, plus 1; for `zlib` 256 times the input
  plus 4 KiB), compares `Target (First .. Last)` or reads `Result`, and frees
  the array. Values inside a processed type refer to that array (`Work.all`),
  not to the input.
- Imports: the program has a `with` for each package that it uses; types of an
  imported description are `Foo.T` and `Foo.X_Type`.
- Types that contain themselves: a top-level type that does is parsed with
  `<Pkg>.Max_Depth`; a field of that type is read with its procedure and
  checked with `Valid`.
- Not covered because no test needs it: asserts with `exception` for the access
  to a value (`AdaSG` reports such a test as `not translated`), parameters of
  the top-level type (a `.kst` has no way to give them; `ADA_SG_TOP_ARGS` is an
  escape for experiments).
- `--round-trip` (see `compiler/README.md`) is only tried with
  `examples/write_model`, where it prints `round trip: same`; the compiler option
  `--read-write` was not available to try it on the suite.

## Round trip

`scripts/run-kaitai-suite.sh --round-trip` generates the parsers with
`--read-write`, and each test program writes the parsed value again with
`Write` into an array of 2 x input + 16 bytes. C is the number of bytes `Parse`
consumed (a begun byte counts as whole), N the number that `Write` produced:

- `round trip: same`: N = C and the bytes are the first C bytes of the input.
  The test is `passed`.
- otherwise the output (N bytes) is parsed again, the value is written again,
  and the second output must equal the first byte for byte; the asserts of
  the test must also hold for the value parsed from the output. Then it is
  `canonical`: `Write` does not give the input back, but something that means
  the same. It is not a failure and has a class of its own.
- otherwise `round trip: differs at <offset> (wrote N of C)`, or `not written
  (<status>)`: `failed`.

Totals of the run:

| Result | Tests |
|---|---|
| passed (`round trip: same`) | 172 |
| canonical | 23 |
| failed | 0 |
| error | 0 |
| build failed | 0 |
| known difference | 1 |
| not generated | 123 |
| not translated | 1 |
| total | 320 |

`--read-write` rejects 11 more formats than the plain run: `non_standard`,
`switch_integers`, `switch_multi_bool_ops`, `valid_switch` (an integer of
different kinds chosen by a value), `str_pad_term_utf16`, `term_strz_utf16_v1`
to `v4` (a terminator of more than one byte), `struct_pad_term`,
`struct_pad_term_equal` (a value cut from bytes with a size and a terminator
or padding).

### The 23 canonical tests, by cause

All causes are listed in "Writing" of `docs/codegen.md`. In every one of
these tests `Write` produced as many bytes as `Parse` consumed.

| Cause | Tests |
|---|---|
| bits that no field reads are written as zero | `bits_byte_aligned`, `bits_enum`, `bits_seq_endian_combo`, `combine_bool`, `expr_bits`, `params_pass_bool` |
| padding, and what follows a terminator in a field with a size, is written with the padding byte | `bytes_pad_term`, `bytes_pad_term_empty`, `bytes_pad_term_equal`, `bytes_eos_pad_term`, `str_pad_term`, `str_pad_term_empty`, `str_pad_term_equal`, `str_eos_pad_term`, `str_eos_pad_term_empty`, `str_eos_pad_term_equal`, `process_bytes_pad_term`, `process_struct_pad_term`, `repeat_eos_bytes_pad_term`, `repeat_n_bytes_pad_term`, `repeat_until_bytes_pad_term` |
| the unused rest of a substream is written as zeros | `buffered_struct` |
| a type that has only instances with `pos` is not written, so its substream is zeros | `str_encodings_escaping_enc` |

### What the first round trip found

The first version of the generated `Write` was proved and passed the tests of
the examples, and this run still found four defects in it: 12 tests failed.
In each of them a parse of the output read a value other than the one that
was written, or the output did not fit. They are fixed, and the rule that they
broke is now the first rule of "Writing": parsing what `Write` produced gives
the same value.

1. A terminator was written although the value had none (`term_bytes4`,
   `term_struct4`, `term_strz4`). A type in a `size: 3` field whose only
   field has `terminator: 0x7c, eos-error: false` reads `foo` from
   `foo|bar|baz@` without a terminator; `Write` wrote `foo|` into the 3 byte
   substream. Now a terminator that may be missing is written only if the
   writer has room.
2. A processed field with `size` and `pad-right` or `terminator`
   (`process_bytes_pad_term`, `process_struct_pad_term`) was written as the
   cut bytes, not with its size, so every later field moved. Now it is padded
   like any bytes.
3. `terminator: 0x40, pad-right: 0x2b, size: 20` (`bytes_pad_term`,
   `bytes_pad_term_roundtrip`, `str_pad_term`, `str_pad_term_roundtrip`): the
   value `str+++3bar+++` was written with padding but without the terminator,
   so the output parsed to `str+++3bar`. Now the terminator is written before
   the padding.
4. `size-eos: true, pad-right: 0x40` in a type inside a `size: 20` field
   (`bytes_eos_pad_term`, `str_eos_pad_term`, `str_eos_pad_term_empty`): the
   value `str1` was followed by zero bytes instead of the padding byte, so the
   output parsed to `str1` and 16 NULs. Now the field pads to the end of its
   window.

The comparison replays the asserts of the test on the value parsed from the
output; defects that these asserts do not see would not show here.
