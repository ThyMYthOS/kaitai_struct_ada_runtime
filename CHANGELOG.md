# Changelog

## Unreleased

- Compiler: the element of a repetition of bit fields of N bits (N below 64) has a subtype of its own, `X_Element`, a
  `U64` range `0 .. 2**N - 1`, in the visible part. `Next`, `Get_X`, the element procedure and the kept elements
  (`X_First_Element` and the others) have it. Before, the bound was lost where the element left the procedure that
  read it, and an expression such as `nib.first + 1` or `_ + 1` could not be proven. The examples `repeat_bits` and
  `repeat_bits_use` changed with it (`Element : out X_Element`; a caller that passes a `U64` still compiles).

- Compiler: the loop of `repeat: until` over bit fields has `8 * Remaining + 8` turns, as `repeat: eos` has, and not
  one more. The `+ 1` after `Length'Last` could overflow, and GNATprove did not prove it (it is not a time limit). Eight
  per byte is enough: at most `8 * Remaining + 7` elements and the turn that finds the end of the data. Example
  `repeat_bits_use`.

- Compiler: floating-point expressions. Float literals, `f4` and `f8` fields (also under `if`, in a nested value and in
  `valid`), `+`, `-` and `*` between floats and with an integer, unary minus, the six comparisons, `?:`, `to_i`
  (truncation toward zero) and value instances of float type are generated, computed in `Kaitai.Floats.F64` with
  `Kaitai.Float_Arithmetic`. An expression whose result would be infinity, or that uses an infinity or a
  not-a-number, is not defined (`Has_X` is false, `Parse` fails with `Arithmetic_Error`); the questions `Add_OK`,
  `Multiply_OK` and `Truncate_OK` are asked only where the bounds that the translator tracks do not answer them. `valid`
  on a float compares as the other targets do, also for infinity and not-a-number. `f4` is computed in 64 bits, as
  Python does, not in 32 bits as Java and C++ do for `f4` with an integer. Division of floats and `%` are rejected.
  New formats generated: `floating_points`, `float_to_i`, `valid_fail_range_float`. Example `float_reading`; the
  comparison with Python has `compiler/diff-formats/x_floats` and `x_floats_seq` and a known difference for
  expressions with infinity. See `docs/codegen.md`, "Floating-point numbers".

- Compiler: `.first`, `.last` and `x[k]` with a constant `k` of a repetition in expressions, and `.min` and `.max` of
  integers of a fixed size. For integers of a fixed size (a slice) they decode from the buffer; `.min` and `.max` walk
  all elements at every evaluation (`Kaitai.Decoding.Min_Element`, `Max_Element`, new). For the other repetitions
  `Parse` keeps the elements that the description uses (`X_First_Element`, `X_Last_Element`, `X_Element_K`) in `T`: one
  copy per element for `.last`, a test per element for each of the others, and the size of an element in `T` per kept
  element. A value instance that is a repeated field under another name has no accessor of its own, and a value
  instance that is such an element returns it. New formats generated: `repeat_until_calc_array_type`,
  `repeat_until_term_bytes`, `repeat_until_term_struct`. Example `repeat_elements`, differential descriptions
  `x_rep_elements`, `x_rep_self` (a repeat-until that uses its own field) and `x_floats_rep` (floats of kept elements).

- Compiler: `valid` and `contents` on a repetition of bytes, strings or bit fields are checked on each element in
  `Parse`. Example `repeat_valid`.

- Compiler: repetitions of bit fields (`b1`, `bN`, and enumerations over them) with a cursor, and `_index` in the
  expressions of the elements of a cursor (`size: sizes[_index]`, `type: row(_index)`, the condition of `repeat-until`);
  the element procedure takes the number, the cursor keeps it. The early exit at an element that read nothing
  does not apply to such elements; a count from the data with elements that may read nothing is rejected unless the
  size is `x[_index]` of a repetition of integers. `Next` has `Belongs_To (This, Buffer)` as a precondition where the
  elements decode a slice of `This`. Examples `repeat_bits` and `repeat_index`.
- Compiler: a parse instance (`pos`, with or without `size` or `io`) that an expression of the `seq` needs
  (`repeat-expr`, `repeat-until`, `size`, `if`, `valid`, `switch-on`, an argument of a type, a value instance, another
  such instance) is parsed once by `Parse`, where it is first needed, and kept in `T`, as the other targets do, and its
  accessor is a function that returns the value (for a user type with the postcondition that it is valid). A failure in
  the instance fails `Parse`. `_io.pos` and `_io.eof` in its expressions are the position at the first use. A value
  instance that uses one is an expression function again. An instance that no expression of the `seq` needs stays a
  procedure that parses at every call, and `_io.pos` in it stays rejected. Rejected with a message: an instance that
  may not be evaluated at all when it is first needed (under an `if` of the field, per element, in a case of a
  `switch-on`), that needs a field read later, with `if`, `repeat`, `process`, a float or another `io`, and with
  `--read-write` a type whose `seq` needs one (instances are not written). New formats generated:
  `instance_in_repeat_expr`, `instance_in_repeat_until`, `position_in_seq`, `valid_fail_contents_inst`,
  `valid_fail_inst`. See `docs/codegen.md`, "An instance that an expression of the `seq` needs", and
  `examples/instance_kept`.
- Compiler: an expression may use one byte, `x[i]`, of bytes with `process: xor`, `rol` or `ror`: it is computed from the
  byte of the input in constant time without an array (`Kaitai.Processing.Xor_Byte`, `Xor_Many_Byte`, `Rotate_Byte`).
  `expr_if_int_ops` is generated. `zlib`, a custom process and every other use of a processed value stay rejected
  (`process_coerce_*` and `type_ternary` choose between a processed and an unprocessed value, which needs an array).
- Compiler: a comparison whose result the ranges of its operands decide (`u1 >= 0`) is a constant, as for literals, so
  that an `if` on it does not make a condition that is always true in the generated code.
- Compiler: BREAKING. In generated code `This` is now the first parameter of every
  operation of the visible part that has it. This breaks every positional call of
  generated code of 0.2.0: `Parse (Buffer, S, [arguments,] V)` becomes
  `Parse (V, Buffer, S[, arguments])`, `Write (Buffer, V, Target, W)` becomes
  `Write (V, Buffer, Target, W)`, `Samples (Buffer, V, I)` becomes
  `Samples (V, Buffer, I)`, `Next (Buffer, V, Position, Element)` becomes
  `Next (V, Buffer, Position, Element)`, `Get_X (Buffer, V, I, Element)` becomes
  `Get_X (V, Buffer, I, Element)`, and the same for `X_Bits`, `Has_X`, value
  instances, parse instances, processed fields (`X (V, Buffer, Target, Last,
  Outcome)`, `X (V, Buffer, Storage, Result, Outcome)`) and a field of the type
  itself. The other parameters keep their order. Operations whose object is a
  cursor (`Belongs_To (Position, Buffer)`, `Remaining`, `Has_Element`) and
  functions without `This` are unchanged. A caller adapts by moving the argument
  that is the value (for `Parse` the last one, the result) to the front; a call
  that was missed does not compile, since the value and the buffer have different
  types. The parameters, the contracts and the
  code of the operations are the same, and the generated unit changes in no other
  way (the call at the top of a package and the `@param` lines show the new
  order). The reason is the prefixed notation `V.Parse (Buffer, S)`,
  `V.Samples (Buffer, I)`, which GNAT offers for untagged types as an extension
  that the caller switches on (`pragma Extensions_Allowed (On);` or `-gnatX`); it
  is described in `docs/codegen.md` and tried in `tests/src/prefixed_tests.adb`
  and, proven, in `tests/src/prefixed_use.adb`. Generated code stays plain
  Ada 2012. Foreign code follows: the contract of an opaque type is
  `Parse (This : out T; Buffer; S; [arguments])`, so a package written for 0.2.0
  needs its `Parse` changed. `Decode` of a custom process is unchanged. The
  generated parsers of `bench/generated` and `examples/` are regenerated; the
  hand-written parsers of `bench/src` that imitate generated code were written
  before the change and keep their order.
- Compiler: opaque types (`meta: ks-opaque-types: true` and a `type:` that no
  description defines) and custom `process` (`my_custom_fx(7, true, [0x20])`,
  `nested.deeply.custom_fx`) are generated. Both call a package that is written by
  hand: `Foo_Bar.Parse` for the opaque type `foo_bar`, `My_Custom_Fx.Decode` for the
  process `my_custom_fx`. A contract, "Foreign code" in `docs/codegen.md`, says
  what the specification of such a package has to provide, and the generated code
  is proven against it; the body of the package need not be in SPARK. The
  contract gives the arguments of the description as `S64` and `Boolean` (and
  bytes for a process), and passes nothing else. An opaque type is rejected under
  `--read-write`; a custom process is written as the bytes of the input, like the
  other processes. `examples/foreign` is a description with an opaque type and two
  custom processes and the packages written for it, proven, tested and fuzzed;
  `compiler/foreign/` has the packages of the custom processes of the tests of
  Kaitai Struct, which `scripts/run-kaitai-suite.sh` and `scripts/survey.sh` use.
  Six more formats of the test suite are generated (`opaque_external_type`,
  `opaque_external_type_02_parent`, `opaque_with_param`, `process_custom`,
  `process_custom_no_args`, `process_term_struct`; `type_ternary_opaque` is still
  rejected, for the reason of `type_ternary`). A switch whose case is the
  top-level type of another description, or an opaque type, names the variant
  `X_Is_Foo_T` and its component `Foo_T`; before, the component had the name of
  the package and the unit did not compile.
- Library: `Kaitai.Float_Arithmetic`, the arithmetic of expressions with floats, in
  `F64`. Every operation has a function that tells whether its result is finite
  (`Add_OK`, `Subtract_OK`, `Multiply_OK`) and one that computes it, as
  `Kaitai.Arithmetic` has for integers, and `Truncate_OK` and `Truncate` are the
  `to_i`. `From_F32` and `From_S64` convert f4 and integer operands. The functions
  that ask are stricter than the exact condition only where an operand is above
  2**500 (3.3E150) in magnitude, which the specification states exactly, because
  that is what GNATprove proves at level 1 with a margin. Division is not in it:
  its condition did not prove with a margin. The backend does not use the package
  yet.
- Benchmarks: `float_bench` measures what asking costs for each operation, on the host
  (`icount.sh`) and on the simulated STM32F4 (`target/run.sh`).
- Compiler: a type can get a value from outside that is not an integer, boolean or
  enumeration, where it uses only an integer, a boolean, an enumeration or a length of it.
  A parameter of a user type (`hdr.width`), of a string (`key.length`) or of an array with a
  constant index, a chain through user-typed values of `_parent` and `_root`
  (`_parent.hdr.width`), `.size` of a repetition or of a stream (`_parent._io.size`), and an
  expression of such values with a string in it (`_parent.s1 == "foo"`) become parameters of
  `Parse` that the parser of the caller computes, as `_parent.x` did. Only descriptions that
  were rejected before are affected; the code of every description that was generated before
  is the same. `examples/outside` shows this; `docs/codegen.md` has the rules.
- Library: every declaration of a visible part has a documentation comment of its
  own, directly before it, also the integer types, the record components and the
  enumeration literals. Comments that stood before a group of declarations
  documented none of them for a tool.
- Compiler: a generated specification has a comment before every declaration of its
  visible part: what `T`, `Valid`, `Belongs_To`, `Parse` and the accessors are and
  require, what `Parse` does when the data are not accepted, which fields it does not
  keep or not read, how to go through a repetition, what `Target`, `Storage`,
  `Outcome` and `Last` mean, and what `Write` guarantees. The package begins with
  the call of `Parse` to use. Every parameter of a procedure has an `@param` line
  and every enumeration literal an `@enum` line. `meta/title`, `doc` and `doc-ref`
  of the description are carried over, also `doc` of the values of an enumeration.
  Only comments change; the generated code is the same. `docs/codegen.md` has a
  section "Documentation", and the description of `examples/showcase` has `doc`
  texts that show where each ends up.
- `scripts/check.sh doc`, which the CI runs, fails if GNATdoc finds a declaration
  without documentation in a visible part of the library or of the parsers under
  `examples/`, or a parameter of a procedure of the parsers without one.
- `compiler/README.md` says in two tables what the backend generates and what it
  rejects.

- Compiler, fixed: a `valid` of a repeated field that uses the field itself (`valid: expr: _ < x.size` on `x`) was
  generated with the size of the whole field, where the other targets take the number of elements read so far, so a
  parser could accept what they refuse. Such a check is rejected now (`compiler/rejected/repeat_valid_self.ksy`).

## 0.2.0 (2026-11-25)

The compiler backend covers more of the language and is compared with the
Python target of the same compiler. The runtime library is that of 0.1.0.

### Results

- The compiler generates parsers for 227 of the 334 formats of the Kaitai
  Struct test suite (0.1.0: 213) and rejects the others with an error that
  names the construct (`compiler/SURVEY.md`). All 227 parsers are proven free
  of run-time errors. With `--read-write` it generates 216 (203), all proven.
- Of the 320 tests of that suite 221 pass (209) and none fails unexpectedly
  (`compiler/SUITE.md`). Parsing, writing and comparing gives the same bytes
  for 187 tests and a documented canonical form for 23; none fails.
- On 46431 inputs of 231 formats the Ada parsers and the Python parsers give
  the same result or both fail, except for 72 inputs with a documented
  difference (`compiler/DIFF.md`).

### Changes to generated code

Parsers generated by 0.1.0 change in three ways:

- `Parse` of a type that starts with bit fields and is only entered at a byte
  boundary has the precondition that no bits are left in the stream. A stream
  that was just opened fulfils it.
- A repetition with a count whose elements can be empty leaves its loop at the
  first element that read nothing.
- A description with an encoding name that Kaitai Struct does not know is
  rejected.

### Details

- Compiler: `switch-on` of bytes with cases that are byte arrays, and a switch that has
  only the `_` case, are generated (switch_bytearray, switch_else_only).
- Compiler: `_sizeof` and `x._sizeof` are translated (they are the size in bytes of
  the current type or of a value, a constant). They failed with "invalid ID".
- `scripts/survey.sh` and `scripts/run-kaitai-suite.sh` give the compiler the
  import path `formats/ks_path` (`imports_abs_abs` and `imports_abs_rel` generate
  with it) and, if `KSF_DIR` names a checkout of `kaitai_struct_formats`, that
  as well.
- Compiler: `valid` on a field whose type is chosen by `switch-on` is checked when
  all cases are integers and there is a `_` case (valid_switch); it was rejected.
- Compiler: a string is compared with a literal that has characters outside printable
  ASCII by encoding the literal into the bytes of the encoding of the string (ASCII,
  UTF-8, ISO-8859-1, UTF-16LE, UTF-16BE; other encodings: ASCII characters only).
  Comparison of UTF-16 strings with a literal or with each other is no longer rejected
  (str_literals_latin1). expr_str_encodings and valid_eq_str_encodings use SJIS and
  IBM437 and stay rejected.
- Compiler: `"text".to_i` of a literal is computed by the compiler (a text that is no
  number is a conversion error in every target and makes the expression undefined), and
  strings in ASCII, UTF-8 and ISO-8859-1 are ordered (`<`, `>`, `valid` with `min` and
  `max`) with `Byte_Arrays.Compare` (expr_to_i_trailing, valid_fail_range_str).
- Compiler: integers above 2**63-1 (up to 2**64-1) are compared with an unsigned
  field in `U64`, also in `valid`; an instance that is such a literal returns `U64`; an
  enumeration with such values has its functions on `U64` (valid_long, valid_short,
  yaml_ints, enum_long_range_u).
- Compiler: a type that starts with bit fields goes on in the byte that the bit fields
  before it left open, as in the other targets, where the stream may be inside a byte.
  Where it is certainly entered at a byte boundary, its `Parse` keeps the leading
  `Align_To_Byte` and has the precondition that no bits are left, which callers prove.
  Descriptions that were rejected for this, such as `default_bit_endian_mod`, are
  generated.
- `scripts/diff-python.sh` compares every generated Ada parser with the Python parser
  that the same compiler generates, on the test data and on changed copies of it
  (`compiler/DIFF.md`). What it found is corrected or documented:
  - Compiler: a repetition with a count leaves its loop at the first element that
    read nothing, in `Parse` and in `Write`. A count of billions in a file of a few
    bytes kept `Parse` busy for minutes when the elements could be empty.
  - Compiler: an encoding name that Kaitai Struct does not know is rejected. It was
    taken for an encoding of one byte per character, which accepts everything
    (str_encodings_escaping_enc is rejected now).
  - `docs/codegen.md` says that `%` with a divisor that is not positive is not defined,
    as in the Java and C++ runtimes, and that `rol` and `ror` take the amount modulo 8.

### Known limits

- Constructs that are rejected: among others parameters that are not
  integers, booleans or enumerations, parse instances used in expressions,
  casts, `to_s`, string concatenation and floating-point arithmetic.
- Bit fields that start inside a byte are read correctly, but with more
  instructions than bit fields of a type that starts at a byte boundary.
- The comparison with the Python parsers covers parsing only, not `Write`.
- There are no operations that change a parsed value or build one from
  nothing.
- The proof does not cover the size of the stack. A light run-time library
  does not notice a stack overflow; the depth of types that contain
  themselves is limited to 8 by default for that reason.
- Only the zero-copy variant of generated code exists. Repetitions are parsed
  again when they are asked for.

## 0.1.0 (2026-11-25)

First release.

### Runtime library

- `Kaitai.Streams`: a cursor over a buffer of the caller that reads integers
  in both byte orders, bit fields, floats as their bits, byte arrays with a
  size, a terminator of one or several bytes or padding, `contents`,
  substreams and the elements of repetitions. A failure is the status of the
  stream, not an exception.
- `Kaitai.Byte_Arrays`, `Kaitai.Strings`, `Kaitai.Arithmetic`,
  `Kaitai.Processing`, `Kaitai.Zlib`, `Kaitai.Arenas`: what expressions,
  strings and `process` of a description need, without heap and without
  copying input.
- `Kaitai.Writers`, `Kaitai.Encoding`: the counterpart of the stream for
  writing.
- `Kaitai.Files` in `kaitai_struct_files.gpr`: reads a file into a buffer.
- All of it is in SPARK and proven at level 1 without assumptions (2210
  checks), except the body of `Kaitai.Files`. It runs on a light run-time
  library; the tests also run on a simulated STM32F4.

### Compiler backend

- `compiler/` is an overlay over the Kaitai Struct compiler at commit
  `963fd6b3` that adds the target `ada`.
- It generates parsers for 213 of the 334 formats of the Kaitai Struct test
  suite and rejects the others with an error that names the construct
  (`compiler/SURVEY.md`). All 213 parsers are proven free of run-time errors.
- Of the 320 tests of that suite 209 pass and none fails unexpectedly
  (`compiler/SUITE.md`).
- With `--read-write` it also generates `Write`, which writes a parsed value
  again, for 203 formats. Parsing what `Write` produced gives the same value.

### Known limits

- Constructs that are rejected: among others parameters that are not
  integers, booleans or enumerations, parse instances used in expressions,
  casts, `to_s`, string concatenation and floating-point arithmetic.
- A type whose first field is a bit field is accepted as a field only where
  the stream is certainly at a byte boundary.
- There are no operations that change a parsed value or build one from
  nothing.
- The proof does not cover the size of the stack. A light run-time library
  does not notice a stack overflow; the depth of types that contain
  themselves is limited to 8 by default for that reason.
- Only the zero-copy variant of generated code exists. Repetitions are parsed
  again when they are asked for.
