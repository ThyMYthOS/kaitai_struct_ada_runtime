# The Ada parsers against the Python parsers

Result of `scripts/diff-python.sh` (see `compiler/README.md`, "Comparing the
Ada parsers with the Python parsers") with its defaults (200 changes of each
data file, fixed seed) on the 334 formats of `kaitai_struct_tests` at commit
`4108136c807f8df88df843de6571f1a7bf29c74e` and the 14 formats of
`compiler/diff-formats`, with the backend and library of this commit and the
Python runtime `kaitai_struct_python_runtime` at commit
`54076c90b5c81348c0d4d005d769247d0497a007`. The Ada programs were built with
run-time checks and with the contracts of the library and of the parsers
executed. No program raised an exception and no contract failed. The script
took about 17 minutes (`--jobs 3`). The test data are synthetic (files of the
Kaitai test suite and changes of them); they hold no personal data.

| | |
|---|---|
| formats | 348 |
| compared | 260 (246 of the suite, 14 of our own) |
| skipped | 88 (73 rejected by the Ada backend, as in `SUITE.md`; 14 without a data file; 1 with an opaque type) |
| failed to build | 0 |
| inputs | 52260 |
| parsed by Ada / by Python | 32295 / 32303 |
| leaves compared in inputs with the same dump | 196459 |

| Class | Inputs |
|---|---|
| same dump | 32248 |
| both fail (`FAILED` on both sides) | 19897 |
| dump over the limit (8 MB; both gave up at the same line) | 26 |
| Python timeout or out of memory (not compared) | 17 |
| known difference | 72 |
| values differ | 0 |
| only Ada fails | 0 |
| only Python fails | 0 |
| Ada exception | 0 |
| no result | 0 |
| total | 52260 |

There is no difference that nothing explains: no input of the classes
`values differ`, `only Ada fails`, `only Python fails`, `Ada exception` and
`no result`. The exit status of the script is 0.

The columns of the table per format (`Ada ok`, `Python ok`, leaves of the seed
and of all inputs) are in the `results.md` of a run. The 14 formats without a
data file are the tests that the suite has no input for (`cast_to_imported`,
`cast_to_imported2`, `enum_to_i_class_border_2`, `imports_circular_b`,
`opaque_external_type_02_child`, `opaque_external_type_02_parent`,
`opaque_with_param`, `params_def`, `params_def_array_usertype_imported`,
`params_def_enum_imported`, `params_def_usertype_imported`, `str_literals`,
`switch_cast`, `to_string_custom`); five of them are rejected by the backend as
well (`cast_to_imported2`, `enum_to_i_class_border_2`, `imports_circular_b`,
`str_literals`, `switch_cast`), which is why 73 and not 78 rejected formats are
counted above. The one format with an opaque type that the survey generates and that has a
data file, `opaque_external_type`, is skipped: its dump program would have to
walk the members of `hello_world`, which are not known to it.

The three formats with a custom `process` (`process_custom`,
`process_custom_no_args`, `process_term_struct`) are compared, with the Python
classes of `spec/python/extra` of the tests repository: of their 603 inputs Ada
parses 383, and the dumps are the same on all of them.

A format whose inputs all fail on both sides tests only what comes before the
failure: of the 260 formats nine have no input that Ada parses
(`eos_exception_bytes`, `eos_exception_sized`, `eos_exception_u4`, whose data
are made to fail at any length, `valid_fail_contents`, `valid_fail_contents_inst`, `valid_fail_eq_bytes`,
`valid_fail_eq_str`, `valid_fail_inst`, and `expr_to_i_trailing`, whose instance raises an error
for every input and whose data file is empty), and eight have fewer than ten
(`default_endian_expr_exception`, `valid_fail_anyof_int`,
`valid_fail_range_bytes`, `valid_fail_range_int`, `valid_fail_range_str`,
`valid_fail_repeat_contents`, `valid_fail_repeat_eq_int`, `zlib_with_header_78`). For these the comparison
says little beyond "both fail on the same inputs": the 200 changes did not
find the few bytes that make the data valid. `yaml_ints` has no field and an
empty data file; its 201 inputs are all the same empty file, and it compares
only the four constants of its instances.

## Known differences

Listed in the script, each with its reason; counted, not hidden. The script
has five entries.

| Id | Inputs | Formats | Reason |
|---|---|---|---|
| `rotate-beyond-7` | 30 | `process_rotate` (`r.buf3`) | `rol` and `ror` rotate by the amount modulo 8 in Ada; for an amount of 8 or more the runtimes of the other targets give results that are not rotations and differ from each other (`docs/codegen.md`, What differs). Only if `key` is 8 or more |
| `encoding-not-checked` | 17 | `str_encodings` (6), `str_encodings_default` (11) | Python raises `UnicodeDecodeError` for a string in Shift_JIS, Ada accepts every byte: only ASCII, UTF-8 and UTF-16 are checked (`docs/codegen.md`, Rules of the compiler) |
| `overflow-64` | 17 | `x_expr` (`big` 12, `shl` 5) | the Python value of the instance is outside S64, the Ada instance is not defined (`docs/codegen.md`, What differs). Only counted if the Python dump has such an integer at the path |
| `mod-divisor-not-positive` | 8 | `x_expr` (`rest`) | `%` with a divisor that is not positive is not defined in Ada, as in the Java and C++ runtimes, where `mod` raises an error; the Python target computes a value (`docs/codegen.md`, What differs). Only if the divisor `b` is not positive |
| `depth-or-repetition-limit` | 0 | | Ada `Limit_Exceeded` where Python parses: no input nested a type that contains itself deeper than 8 levels, and none made a repetition end without progress |

The documented difference "no partial results" cannot show, since a dump with
any failure is `FAILED` on both sides. "ASCII strings with bytes >= 0x80" did
not show either: both sides reject them.

## Resource limits that are not differences

17 inputs of `nav_parent` are in the class "Python timeout or out of memory":
3 where Python raises `MemoryError` and 14 where it is stopped by the time
limit (`rc=124`). Smallest: 12 bytes `0200000800000000ff1bffff`. The format reads
`qty_entries` (u4) and `filename_len` (u4), then four bytes, then `entries`
with `repeat: expr` of `qty_entries` elements, each a string of `filename_len`
bytes; with `filename_len` = 0 every element is empty and `qty_entries` can be
2 or 3 thousand million. Python iterates over all of them and keeps a list.
Ada gives `FAILED` (dump too large), since `Parse` leaves the loop at
the first element that read nothing (see "What the first run found", 4). The
count is not compared, so these inputs are not counted as the same. The 26
inputs "over the limit" have a dump of more than 8 MB on both sides.

## What the first run found

The first full run (218 formats, 43818 inputs) had 30 inputs where the values
differ, 8 where only Ada failed, 79 where only Python failed, and 3 without a
result, plus 14 where Python ran out of time or memory. They came from four
causes, which the commit after it addressed:

1. `rol(n)` / `ror(n)` with a calculated amount of 8 or more
   (`process_rotate`, 30 inputs). Ada rotates by the amount modulo 8; the
   Python runtime computes `(byte << amount) & 0xFF | (byte >> (-amount % 8))`,
   which is a rotation only for amounts below 8, and the runtimes of the other
   targets differ from each other there. Now documented in `docs/codegen.md`
   (What differs) and a known difference (`rotate-beyond-7`, 30 inputs, with a
   check that `key` is 8 or more).
2. An encoding name that no codec knows (`str_encodings_escaping_enc`, 79
   inputs where only Python failed, with `LookupError: unknown encoding`). The
   backend took a name that it did not know for an encoding of one byte per
   character, which accepts every byte, so a misspelt name was never noticed.
   The backend rejects such a name now, so the format is not compared any more
   (it is skipped as rejected; `SUITE.md` lists it as `not generated`).
3. `%` with a divisor that is not positive (`x_expr`, our own format, 8
   inputs where only Ada failed). `Kaitai.Arithmetic.Modulo` is defined only
   for a positive divisor; the Python target returns a result for a negative
   divisor, the Java and C++ runtimes raise an error. Documented in
   `docs/codegen.md` (What differs) and a known difference
   (`mod-divisor-not-positive`, 8 inputs, with a check that `b` is not
   positive).
4. A loop over empty elements (`nav_parent`; 3 inputs without a result and 14
   where Python was slow or out of memory). A repetition with a count ran its
   loop once per element also where an element reads nothing, so a file of 25
   bytes with a count of three thousand million kept `Parse` busy for more than
   100 seconds. Fixed: `Parse` leaves the loop at the first element that read
   nothing (the elements after it start in the same state and read nothing
   either), `Write` in the same way; the check is generated only where the
   description allows an element without bytes. The count stays what the
   expression says. No input is without a result now; the 17 inputs that
   remain are Python's (see above).

The commit also made it possible for a value that differs to be a known
difference, and fixed the entry for `Limit_Exceeded` (the shell had expanded
`"$@"` inside it); the entry matched no input in the run above.

The new format `compiler/diff-formats/x_bits_types` has bit fields that go on
across a nested type, the elements of a repetition, the case of a switch and a
conditional field. In this run the Ada and the Python parser agree on all 201
inputs: Ada parses 167 of them, Python the same 167, and 3279 leaves are
compared (20 of them in the seed).

## What the harness found when it was wrong

These are not findings about the backend; they are what the first runs showed
about the harness and were fixed before the run above:

- the Python property of an instance is `name`, not `_m_name`; a field with
  `if` is absent in Python, not `None`; a parser generated with `ks-debug`
  does not read in its constructor;
- the Python runtime 0.11 of PyPI lacks `KaitaiStream.substream`, which the
  generated code needs, so every format with a sized type failed on the Python
  side (the 37 differences of the first run of `switch_manual_int_size`);
- a value instance with `if` is `absent` when `Has_X` is false: the Ada API
  does not tell a false condition from an undefined expression (so for these
  instances a Python exception on an expression with a true condition shows as
  `absent` on the Ada side and a difference);
- a Python process that parses a list of billions of elements keeps its memory
  for the next input unless it is collected, which made the next inputs fail;
- an earlier run of the commit of this one stopped at a defect of the dump
  generator for `yaml_ints`, which has value instances of an integer literal
  above 2**63-1 (type `U64`): the generator converted such a value to `S64`
  to print it and the dump program raised `Constraint_Error` (201 inputs of
  the class "Ada exception"). The parser was not at fault; the generator is
  fixed.

## Planted differences

To see that the comparison finds what it should, a generated Ada parser was
changed by hand in the output directory (`--reuse` builds the changed parser).
This was done on the first run; it was not repeated for the run above:

| Change | Format | Result |
|---|---|---|
| `Read_U4le` of `uint32` replaced by `Read_U4be` | `fixed_struct` | found with the default 200 inputs (4 of 201 inputs differ: `r.hdr.uint32`); **not found with 100 inputs**: the data of the test hold `ff ff ff ff` there, which is its own mirror image, and the changes of single positions did not happen to reach the field |
| `Chunks_Count := To_Count (S64'Pred (Qty))`, one element too few | `repeat_n_struct` | found: 51 inputs `r.chunks.size = 1` against 2, 3 where Python fails |
| the check `Foo /= 123` left out | `valid_fail_eq_int` | found: 95 inputs where only Python fails (`ValidationNotEqualError`) |
| `Read_Bits_Int_Be (.., 3, Bits_B)` read with 4 bits | `bits_simple` | found: 91 inputs differ at `r.bits_b`, then every later bit field |
| the UTF-8 check of a string left out | `str_eos` | found: only Python fails (`UnicodeDecodeError`) |

The unchanged parsers of the same formats gave no difference.

## Not covered

- Only what the data files of the tests and our fourteen formats reach through
  changes of bytes. A format whose data fail at once on any change (the nine
  above) is hardly tested. A change that has to be right in several places at
  once (a checksum, a length that is also stored elsewhere) is rarely found.
- `contents` fields are not dumped (the Ada parsers do not keep them, only
  check them; a mismatch is a failure on both sides).
- Top-level types with parameters are skipped (none of the compared formats).
- A format with an opaque type is skipped (`opaque_external_type`): the members
  of the opaque value are not known to the dump program.
- Strings are compared as bytes: Python's string is encoded again with the
  encoding of the field, which is the identity for the encodings that occur.
- A dump is capped at 8 MB.
- `--read-write` mode (the Python parser reads what `Write` produced) is not
  implemented.
- The Python runtime is a development version; a difference in the runtime
  (see `rotate-beyond-7`) cannot be told from one in the Ada parser except by
  reading both.
