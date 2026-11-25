# The Ada parsers against the Python parsers

Result of `scripts/diff-python.sh` (see `compiler/README.md`, "Comparing the
Ada parsers with the Python parsers") with its defaults (200 changes of each
data file, fixed seed) on the 334 formats of `kaitai_struct_tests` at commit
`4108136c807f8df88df843de6571f1a7bf29c74e` and the 7 formats of
`compiler/diff-formats`, with the backend and library of this commit and the
Python runtime `kaitai_struct_python_runtime` at commit
`54076c90b5c81348c0d4d005d769247d0497a007`. The Ada programs were built with
run-time checks and with the contracts of the library and of the parsers
executed. No program raised an exception and no contract failed. The script
took 27 minutes (`--jobs 3`, a loaded machine). The test data are synthetic
(files of the Kaitai test suite and changes of them); they hold no personal
data.

| | |
|---|---|
| formats | 341 |
| compared | 218 (211 of the suite, 7 of our own) |
| skipped | 123 (109 rejected by the Ada backend, as in `SUITE.md`; 14 without a data file) |
| failed to build | 0 |
| inputs | 43818 |
| parsed by Ada / by Python | 27402 / 27331 |
| leaves compared in inputs with the same dump | 147068 |

| Class | Inputs |
|---|---|
| same dump | 27276 |
| both fail (`FAILED` on both sides) | 16348 |
| dump over the limit (8 MB; both gave up at the same line) | 26 |
| Python timeout or out of memory (not compared) | 14 |
| known difference | 34 |
| values differ | 30 |
| only Ada fails | 8 |
| only Python fails | 79 |
| Ada exception | 0 |
| no result | 3 |

The columns of the table per format (`Ada ok`, `Python ok`, leaves of the seed
and of all inputs) are in the `results.md` of a run. A format whose inputs all
fail on both sides tests only what comes before the failure: of the 218 formats
six have no input that Ada parses (`eos_exception_bytes`, `_sized`, `_u4`,
whose data are made to fail at any length, `valid_fail_contents`,
`valid_fail_eq_bytes`, `valid_fail_eq_str`), and six have fewer than ten
(`default_endian_expr_exception`, `valid_fail_anyof_int`,
`valid_fail_range_bytes`, `valid_fail_range_int`, `valid_fail_repeat_eq_int`,
`zlib_with_header_78`). For these the comparison says little beyond "both fail
on the same inputs": the 200 changes did not find the few bytes that make the
data valid.

## Known differences

Listed in the script, each with its reason; counted, not hidden.

| Id | Inputs | Formats | Reason |
|---|---|---|---|
| `encoding-not-checked` | 17 | `str_encodings`, `str_encodings_default` | Python raises `UnicodeDecodeError` for a string in Shift_JIS, Ada accepts every byte: only ASCII, UTF-8 and UTF-16 are checked (`docs/codegen.md`, Rules of the compiler) |
| `overflow-64` | 17 | `x_expr` (`big`, `shl`) | the Python value of the instance is outside S64, the Ada instance is not defined (`docs/codegen.md`, What differs). Only counted if the Python dump has such an integer at the path |

The rules `depth-or-repetition-limit` (Ada `Limit_Exceeded` where Python
parses) never matched: no input nested a type that contains itself deeper than 8
levels. The documented difference "no partial results" cannot show, since a dump
with any failure is `FAILED` on both sides. "ASCII strings with bytes >= 0x80"
did not show either: both sides reject them.

## Differences that nothing explains

### 1. `rol(n)` / `ror(n)` with a calculated amount of 8 or more (`process_rotate`)

30 inputs. Smallest: 11 bytes of zeros as `buf1`, `buf2`, then `key`, and
`buf3`: `0000000000 0000000000 09 0100000000`.

| | `r.buf3` |
|---|---|
| Ada | `0200000000` |
| Python | `0000000000` |

`buf3` has `process: rol(key)`, and `key` is 9. The Ada parser rotates by
`9 mod 8 = 1` bit: `Kaitai.Processing.Rotate_Left (..., Integer
(Kaitai.Arithmetic.Modulo (S64 (This.Key), 8)), ...)` in `process_rotate.adb`
(the accessor `Buf3`). The Python runtime does `(byte << amount) & 0xFF | (byte
>> (-amount % 8))`, which is a rotation only for amounts below 8 (here the left
part is 0 and the right part 1 >> 7 = 0). I did not check the other runtimes. The Ada
result is the mathematical rotation. Nothing in the description or in
`docs/codegen.md` says which is meant; the amounts of the test (`3`, and a key
below 8 in its data) do not tell. The Python runtime is the reference of this
comparison, so the Ada parser differs from it, and `docs/codegen.md` (What
differs) does not say so. Decision needed: either follow the runtime (amount
not reduced) or document the reduction.

### 2. A string with an encoding that no codec knows (`str_encodings_escaping_enc`)

79 inputs. Smallest of those that make Python reach the string: 8 zero bytes
(four lengths of 0, so four empty strings); the first in the list is 12 bytes
`0000000000000000ab9eac7d`.

Ada dumps `r.str1.v =` (empty) and the other three, Python gives `FAILED` with
`LookupError: unknown encoding: ASCII\\x` when the instance `v` is read (the
encodings of the format are `ASCII\\x`, `UTF-8\'x`, `SJIS\"x`, `IBM437\nx`;
the test is about escaping them in generated code). In Ada `encodingName`
turns a name that it does not know into `Single_Byte`, which accepts every
byte, so the accessor `V` (`Read_Bytes_Full` and nothing else, see
`str_encodings_escaping_enc.adb`) succeeds. This is the rule "every other
encoding is `Single_Byte`" of `docs/codegen.md`, applied to a name that is not
an encoding at all; Python (and any other target) fails when it decodes. A
misspelled encoding is not diagnosed by the Ada backend at all. Not a case of a
documented difference, since the documentation speaks of encodings that are
real but not checked.

### 3. `%` with a negative divisor (`x_expr`, our own format)

8 inputs. Smallest: `a` = 1, `b` = -1 as `s4`, then 12 zero bytes:
`01000000 ffffffff 0000000000000000 00 000000`.

| | `r.rest` (`a % b`) |
|---|---|
| Ada | `FAILED` (`undefined r.rest`: `Has_Rest` is false) |
| Python | `0` (Python's `%`; `r.quot`, `a / b`, is -1 on both sides) |

`Kaitai.Arithmetic.Modulo` is defined only for a positive divisor
(`Modulo_OK (B)`, `docs/codegen.md`, Expressions: "defined if `Modulo_OK (B)`"),
so every value instance with `a % b` and a divisor that can be zero or
negative fails the whole parse of the dump when it is asked for. Python
returns a result for a negative divisor and raises only for 0. The Ada
restriction is documented in the table of expressions but not as a difference
from the other targets; whether a negative divisor is meant to be undefined is
not said by the description of the language. Zero divisors agree (both fail).
The class is not `overflow-64`: the Python value is small, and the script counts
it as a difference for that reason.

### 4. Billions of empty elements (`nav_parent`; `nav_root` in an earlier run)

3 inputs without result and 14 where Python is slow or out of memory (they are
in the table above as "no result" and "Python timeout or out of memory").
Smallest: 25 bytes `00040080000000000000000000000000000000010000000000`; or
28 bytes `08000080000000000000000000000000000000000000000000000000`.

The format reads `qty_entries` (u4) and `filename_len` (u4), then four bytes,
then `entries` with `repeat: expr` of `qty_entries` elements, each a string of
`filename_len` bytes. With `filename_len` = 0 every element is empty and
`qty_entries` can be 2 or 3 thousand million. Ada: `Parse` of the `index`
type walks over all of them (`Parse` loop over `Entries_Count` in
`nav_parent.adb`; measured: more than 100 s for 3.0e9 elements, 28 bytes of
input); the program is killed by the 20 s limit of the script. Python: the same
number of iterations and a list that fills 3 GB. No difference of behaviour,
but a resource finding: the bound "at most once per byte that was left" of
`docs/codegen.md` (Repetitions) holds for `repeat: eos` and `repeat: until`
only; `repeat: expr` takes its count from the input unchecked, so a few bytes
keep an Ada parser busy for minutes. The 26 inputs "over the limit" are the
same cause: the dump has more than 8 MB on both sides.

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
  for the next input unless it is collected, which made the next inputs fail.

## Planted differences

To see that the comparison finds what it should, a generated Ada parser was
changed by hand in the output directory (`--reuse` builds the changed parser):

| Change | Format | Result |
|---|---|---|
| `Read_U4le` of `uint32` replaced by `Read_U4be` | `fixed_struct` | found with the default 200 inputs (4 of 201 inputs differ: `r.hdr.uint32`); **not found with 100 inputs**: the data of the test hold `ff ff ff ff` there, which is its own mirror image, and the changes of single positions did not happen to reach the field |
| `Chunks_Count := To_Count (S64'Pred (Qty))`, one element too few | `repeat_n_struct` | found: 51 inputs `r.chunks.size = 1` against 2, 3 where Python fails |
| the check `Foo /= 123` left out | `valid_fail_eq_int` | found: 95 inputs where only Python fails (`ValidationNotEqualError`) |
| `Read_Bits_Int_Be (.., 3, Bits_B)` read with 4 bits | `bits_simple` | found: 91 inputs differ at `r.bits_b`, then every later bit field |
| the UTF-8 check of a string left out | `str_eos` | found: only Python fails (`UnicodeDecodeError`) |

The unchanged parsers of the same formats gave no difference.

## Not covered

- Only what the data files of the tests and our seven formats reach through
  changes of bytes. A format whose data fail at once on any change (the six
  above) is hardly tested. A change that has to be right in several places at
  once (a checksum, a length that is also stored elsewhere) is rarely found.
- `contents` fields are not dumped (the Ada parsers do not keep them, only
  check them; a mismatch is a failure on both sides).
- Top-level types with parameters are skipped (none of the compared formats).
- Strings are compared as bytes: Python's string is encoded again with the
  encoding of the field, which is the identity for the encodings that occur.
- A dump is capped at 8 MB.
- `--read-write` mode (the Python parser reads what `Write` produced) is not
  implemented.
- The Python runtime is a development version; a difference in the runtime
  (see 1.) cannot be told from one in the Ada parser except by reading both.
