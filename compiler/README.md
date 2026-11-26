# Ada backend for the Kaitai Struct compiler

This directory holds the Ada/SPARK backend of the Kaitai Struct compiler
(Scala). It generates parsers that follow `docs/codegen.md` and use the
runtime library of this repository.

## Layout

`compiler/` is an overlay: its files have the same relative paths as in the
upstream tree and are copied over a checkout of the compiler.

| File | What it is |
|---|---|
| `shared/src/main/scala/io/kaitai/struct/AdaClassCompiler.scala` | the emitter; it walks the `ClassSpec` tree itself and writes `<id>.ads` and `<id>.adb` |
| `shared/src/main/scala/io/kaitai/struct/translators/AdaTranslator.scala` | translation of expressions to Ada, with the conditions under which they are defined |
| `foreign/` | hand-written Ada packages for the tests of Kaitai Struct that use foreign code: the custom processes `my_custom_fx`, `nested.deeply.custom_fx` and `custom_fx_no_args` (with the empty parents `Nested` and `Nested.Deeply`), written to the contract of "Foreign code" in `docs/codegen.md`; proven by `scripts/survey.sh --prove` and a source directory of `scripts/run-kaitai-suite.sh` |
| `upstream.patch` | the edits of existing upstream files: the registry (`LanguageCompilerStatic`), `Main.scala`, the option `--ada-max-depth` (`RuntimeConfig.scala`, `JavaMain.scala`), `MetaSpec.scala` (keeps `meta/title`, which upstream checks and drops), and `project/plugins.sbt` (`sbt-scalajs-crossproject` 1.3.2 instead of 1.0.0, which is no longer found) |

Pinned upstream: `kaitai-io/kaitai_struct_compiler` at commit
`963fd6b3c633e87ed197c5a065f5c8a7d31c1328`.

## Build

```
scripts/build-compiler.sh             # KSC_DIR defaults to ~/.cache/kaitai_struct_compiler
```

The script clones the pinned commit into `$KSC_DIR` (or reuses it), copies
the overlay, applies `upstream.patch` (only once), builds with sbt and prints
the launcher. It downloads sbt 1.12.9 when there is none on the `PATH`, and
passes `-Dsbt.override.build.repos=true` when `~/.sbt/repositories` exists.

```
$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler -t ada --outdir out file.ksy
scripts/generate-examples.sh [--check]   # regenerates and formats examples/*
```

## What is supported and what is rejected

The backend translates a construct with the meaning it has in Kaitai Struct,
or it rejects the description with an error that names the construct and the
path of the attribute:

```
(main): /instances/v:
	error: not supported by the Ada backend: floating-point arithmetic
```

It does not generate an approximation. `compiler/SURVEY.md` lists what
happens to each of the 334 formats of the Kaitai Struct test suite, and
`docs/codegen.md` describes the generated code for everything in the column
"Generated".

### Fields

| Construct | Generated | Rejected |
|---|---|---|
| Integers | `u1` .. `u8`, `s1` .. `s8`; fixed byte order, byte order decided at run time, `endian: switch-on` | – |
| Bit fields | `b1` .. `b64` with `bit-endian`; a type that starts with bit fields goes on in the byte that the bit fields before it left open, as in the other targets (see "Fields" in `docs/codegen.md`) | the top-level type of another description that starts with bit fields, used where the stream may be inside a byte |
| Floats | `f4`, `f8` as their bits, with a second accessor for the value if it is finite | any expression with a float, also a comparison ("floating-point arithmetic") |
| Bytes and strings | `size`, `size-eos`, `terminator` (also of several bytes), `pad-right`, `include`, `consume`, `eos-error`, `contents` | – |
| String encodings | `ASCII`, `UTF-8`, `UTF-16LE`, `UTF-16BE`, which are checked when a string is parsed; the other encodings that Kaitai Struct knows (`ISO-8859-1`, `Shift_JIS`, `IBM437`, ...), whose strings are delivered as their bytes without a check | `UTF-16` without a byte order, `UTF-32`, `UTF-32LE`, `UTF-32BE`; a name that Kaitai Struct does not know |
| `valid` | `eq`, `min`, `max`, range, `any-of`, `in-enum`, `expr`; on a repetition of integers of a fixed size; on a field whose type is chosen by `switch-on`, if all cases are integers and there is a `_` case | on other repeated fields; on other fields with `switch-on`, and `in-enum` on any of them |
| `if` | yes | – |
| Enumerations | on integers; with values up to 2**64-1 on unsigned fields | values above 2**63-1 on signed fields or together with negative values |
| User types | nested types by path; `size`, `size-eos`, `terminator` and `pad-right` on a field of a type (the value is parsed from the bytes that are cut out); imports (a type of another description is `<Package>.T`; all files of a compilation are written); opaque types (`ks-opaque-types`): `Parse` of a package that is written by hand and keeps a contract (see "Foreign code" in `docs/codegen.md`), with integer and boolean arguments, as a field, a case of a `switch-on`, a repetition, or a parse instance, with `size`, `terminator` and `process` | types that contain each other, also through imports; an opaque type whose name has `::`, whose name is not usable for a package, or with an argument that is not an integer or a boolean; an opaque type under `--read-write`; a member of an opaque value in an expression (the front end of the compiler does not allow it either) |
| Types that contain themselves | directly or through a repetition, with the parameter `Depth` (`--ada-max-depth N` sets `Max_Depth`, default 8) | a field whose type depends on a value and can be the type itself; `valid` on a field of its own type |
| `switch-on` | on integers, enumerations, strings or bytes; cases that are structures, integers or byte arrays; a switch that has only the `_` case | – |
| `repeat` | `expr`, `eos`, `until`; structures, bytes and strings with a cursor, integers and floats of a fixed size as a slice | on a field with `switch-on`; on a parse instance; `_index` |
| `process` | `xor` with a byte or with a key of bytes, `rol`, `ror`, `zlib`, and a custom process (`my_custom_fx(7, true, [0x20])`, `nested.deeply.custom_fx`, `custom_fx_no_args`: `Decode` of a package that is written by hand, with integer, boolean and bytes arguments); the accessor undoes it into an array of the caller | on a string, a repeated field, a field with `switch-on` or a parse instance; an expression or a `valid` that depends on a processed value; a custom process with an argument that is a string, an enumeration or uses `_io`, or whose name is not usable for a package |
| Parameters | integer, boolean, enumeration (parameters of `Parse`); any other type, where the type uses only an integer, a boolean, an enumeration, or the length or size of the value (`hdr.width`, `key.length`): the caller computes that and passes it | a value of any other type that the type uses as a whole (bytes, a user type, an array, a stream, `struct`), or that is cast |
| `_parent`, `_root` | for values that are integers, booleans or enumerations, chains such as `_parent._parent.x` or `_parent.hdr.width` included, the length of a string and the size of a repetition or of a stream (`_parent._io.size`), a cast of such a value (`_parent.as<foo>.x`), and an expression of such values with a string in it (`_parent.s1 == "foo"`); they become parameters of `Parse` | other values (a string, bytes, a user type as a whole); `_parent._io` other than `.size`; `_parent` in the top-level type; `_root` in a type of another description that is used from elsewhere, or in a description whose top-level type contains itself; `parent: false` on a field whose type uses `_parent`; the key `parent` on a field whose type calculates its byte order from `_parent` |
| Instances | with a value: integer, boolean, enumeration, and bytes or a string that is a field (`value: name`); with a position: `pos`, `size`, `io: _root._io`, a procedure that parses at every call; an instance with a position that an expression of the `seq` needs (a count, a size, an end condition, an `if`, a `valid`, a `switch-on`, an argument, a value instance, another such instance) is parsed once by `Parse`, where it is first needed, and kept: its accessor is a function (see "An instance that an expression of the `seq` needs" in `docs/codegen.md`) | a value of bytes or a string that is not a field (a literal, a concatenation); an instance with a position that is used in an expression and has `repeat`, `process`, `if`, a float type, a type that depends on a value or an `io` other than `_root._io`; an instance with a position that only a value instance or an instance that the `seq` does not need uses; one that is first needed where it may not be evaluated at all (an expression of a field with `if`, of each element of a repetition, of a case of a `switch-on`) or that needs a field that is read later, or by a `valid` with `_io.pos`; with `--read-write`, a type whose `seq` needs one |
| `doc`, `doc-ref`, `meta/title` | in the documentation comments of the generated specification, next to the comments that the compiler writes for what it generates (see "Documentation" in `docs/codegen.md`) | – |

### Expressions

| Construct | Generated | Rejected |
|---|---|---|
| Integer arithmetic | `+ - * / %`, shifts, bit operations, in `Kaitai.Types.S64`. An operation that would overflow or divide by zero makes the expression undefined (see "Expressions" in `docs/codegen.md`); the check is left out where the compiler can show that it holds | – |
| Integers above 2**63-1 (up to 2**64-1) | as an operand of a comparison with an unsigned field or with another literal (`x >= 9223372036854775808`), in `valid` on an unsigned field, and as the whole value of an instance; these are computed in `Kaitai.Types.U64` | as an operand of arithmetic (`x + 9223372036854775808`, `18446744073709551615 - 1`); compared with a signed field or with an expression. The message says that the literal is above the largest signed 64-bit integer, that expressions are computed in signed 64 bits, and that such a literal is accepted only as an operand of a comparison with an unsigned field (a literal beyond 64 bits still says "does not fit into 64 bits") |
| A `u8` field in arithmetic | `x + 1` is computed in `S64`; for a value of `x` above 2**63-1 the expression is not defined, which `Has_...` of the instance tells | – |
| Comparisons, `and`, `or`, `not`, `?:` | yes | – |
| Enumerations | labels, comparison, `.to_i` | – |
| Strings | comparison with a literal of any characters (the compiler encodes the literal for ASCII, UTF-8, ISO-8859-1, UTF-16LE and UTF-16BE) and with each other; `<`, `>` for ASCII, UTF-8 and ISO-8859-1; `.length`; `.to_i` (of a literal: computed by the compiler) | `+` (concatenation), `substring`, `reverse`, `to_s` of an integer; a literal with a character that is not ASCII for a string in another encoding (`Shift_JIS`, `IBM437`, ...); comparison of strings in different encodings other than ASCII and UTF-8; `<`, `>` in other encodings; `.length` in `Shift_JIS`, `Big5` or `EUC-KR`; `.to_i` in UTF-16 |
| Bytes | comparison, `.length`, `.first`, `.last`, `.min`, `.max`, subscripts | – |
| Repetitions | `.size`; subscripts of a repetition of integers of a fixed size | `.first`, `.last`, `.min`, `.max` and other uses of an array; subscripts of other repetitions |
| `_io.size`, `_io.pos`, `_io.eof` | in the expressions of fields (`size`, `if`, `repeat-expr`, ...); `_io.size` also in an instance with a position; `_io.pos` and `_io.eof` also in the expressions of an instance with a position that an expression of the `seq` needs (`pos`, `size`, `valid`, ...), where they are the position and the end of the stream at the place of the first use | in a value instance; `_io.pos` and `_io.eof` in an expression of an instance with a position that no expression of the `seq` needs: the Ada accessor evaluates them at the start of the type, the other targets when the instance is first used, so the results would differ without a message |
| Fields of nested values, `sizeof<t>`, `_sizeof`, `x._sizeof` | yes | – |
| Casts (`.as<...>`) | – | all |

## Writing

With `--read-write` the compiler also generates `procedure Write` for every
type, as described in the section "Writing" of `docs/codegen.md`. An example
can carry compiler options in a file `options` next to its `.ksy`;
`examples/write_model` and some others have `--read-write` there. Under the
option these are rejected, each with an error that names the construct: a
type that contains itself, a terminator of more than one byte, a terminator
that is included but not consumed, a value cut from bytes with a size and a
terminator or padding, an integer switch whose cases have different types,
`contents` with a condition, an opaque type (the contract has no `Write`). A
custom `process` is written like the other processes, as the bytes of the
input. `scripts/survey.sh --read-write` repeats the survey with the option.

`compiler/SURVEY.md` lists what happens to the formats of the Kaitai
Struct test suite.

## Running the Kaitai Struct test suite

The official suite (`kaitai-io/kaitai_struct_tests`, pinned at commit
`4108136c807f8df88df843de6571f1a7bf29c74e`) describes every test as a
`formats/<name>.ksy`, a `spec/ks/<name>.kst` (data file and asserts) and a
file in `src/`. Other targets translate the `.kst` files into native test
code with the test translator of that repository. For Ada this is done by
`AdaSG`:

| File | What it is |
|---|---|
| `tests-overlay/translator/src/main/scala/io/kaitai/struct/testtranslator/specgenerators/AdaSG.scala` | the test spec generator; copied into the tests repository |
| `tests.patch` | the two edits of existing files of the tests repository that register the target `ada` (`Main.scala`, `TestTranslator.scala`) |
| `../scripts/run-kaitai-suite.sh` | does everything below |
| `SUITE.md` | what the script reported on the last run, and why the tests that are not green are not |

```
scripts/build-compiler.sh                      # once; KSC_DIR defaults to ~/.cache/kaitai_struct_compiler
scripts/run-kaitai-suite.sh                    # all tests; KST_DIR defaults to ~/.cache/kaitai_struct_tests
scripts/run-kaitai-suite.sh --out /tmp/suite hello_world valid_fail_eq_int
```

The compiler gets `formats/` and `formats/ks_path/` (what the tests call
`$KS_PATH`) as import paths. `imports_abs` also needs `common/vlq_base128_le.ksy`
from `kaitai-io/kaitai_struct_formats`; `KSF_DIR`, a checkout of that
repository, is added as a further import path by `scripts/run-kaitai-suite.sh`
and `scripts/survey.sh` if it is set. Without it that test does not generate.

`KST_DIR` is cloned (blobless, then only `formats spec/ks src translator` are
checked out) if it is missing. The script copies the overlay and applies the
patch (both can be repeated), publishes the compiler locally with
`sbt compilerJVM/publishLocal` (the translator resolves it as
`io.kaitai:kaitai-struct-compiler:0.12-SNAPSHOT` from `~/.ivy2/local`),
builds the translator, and then, for every test:

1. generates the parser with `-t ada` (import path `formats/`),
2. generates `test_<name>.adb` with `AdaSG`,
3. builds all programs with `gprbuild` through Alire, in one throw-away
   project in the output directory that `with`s `kaitai_struct.gpr` and
   `kaitai_struct_files.gpr` and has one main per test
   (`-gnat2012 -gnata -gnatwa`, contracts of the library on, `-k`),
4. runs each program on its data file.

`DIR/results.md` has a table with the result of each test, `DIR/junit.xml`
one test case per test, `DIR/log/` the logs of every step. The classes are
`passed`, `failed` (an assert does not hold), `error` (the program raised an
exception or crashed: with a correct generator this does not happen),
`build failed`, `not generated` (the backend rejects the format; its message
is the detail) and `not translated` (`AdaSG` cannot express an assert; the
reason is the detail). The exit status is 0 only if nothing failed, errored
or failed to build; `--no-fail` makes it always 0.

### What `AdaSG` generates

A test program reads `src/<data>` (the first argument is the directory that
holds the data files, default `src`) into a buffer on the heap with
`Kaitai.Files`, parses with `<Pkg>.Parse (R, Buffer.all, S)` and prints one
line per assert, `ok <n>` or `FAIL <n>: <expression>`, and `PASSED` or
`FAILED` at the end (exit status 1 for `FAILED`). The accessors of the
generated parser have preconditions, so each assert first checks the
conditions of its access (`Valid`, `Has_X`, `X_Case`, `Index < X_Count`, the
outcome of an instance, ...); an assert whose value does not exist is a
`FAIL` with the note "(not defined)", it never raises. Elements of
repetitions of structures and instances with a position are fetched into
local variables of a `declare` block. A test with `exception` checks that
`Parse` fails and that `Kaitai.Streams.Status (S)` is the status that
corresponds to the expected error (`EndOfStreamError` is `End_Of_Stream`,
`ValidationNotEqualError` is `Validation_Not_Equal`, and so on).

Expected values: integers, booleans, enumerations (by literal when the
actual value is of that enumeration), strings (`Kaitai.Strings.Equal_Literal`
for printable ASCII, otherwise byte-wise in the encoding of the field),
bytes, lists, `null` (the presence function is false) and floats (within
1e-6, relative for large values). The names of the generated code are taken
from the compiler itself (`AdaClassCompiler.memberName` and the like), so the
test generator follows the compiler when it changes how it names things.

### Foreign code

The tests with an opaque type (`ks-opaque-types: true`) or a custom `process`
need code that the descriptions do not contain. The other targets keep it in
their tests: another generated parser for an opaque type (`hello_world`,
`params_def`, `opaque_external_type_02_child`), hand-written classes for the
processes. Here the opaque type is the parser that the compiler generates from
that format: the script generates it as well (`OPAQUE_SUPPORT` at the top of
`scripts/run-kaitai-suite.sh` says which format belongs to which test), even
if the run is only of the test, and finds it through the source directories. The
packages of the custom processes are the hand-written ones of `compiler/foreign/`,
which is a source directory of every run. `AdaSG` reads a member of an opaque
value (`hw.one.as<u1>`, where the type of the member is given by the cast) with
the accessor `Hello_World.One`, which the generated parser has.
`type_ternary_opaque` stays `not generated`: its value instance `dif` is of a
type and uses a field with `process`, as in `type_ternary`.

### Processed fields, imports, recursion, known differences, round trips

- A field with `process` has an accessor that is a procedure. `AdaSG` gives it
  an array on the heap (as large as the input for `xor` and `rol`/`ror`, 256
  times the input plus 4 KiB for `zlib` and a custom process) and compares `Target (First .. Last)`;
  for a field of a type the `Result` is read, and everything inside it (strings,
  bytes, repetitions, switches) refers to that array, not to the input.
- Accessors of imported types are written with the package of the other
  description; the program has a `with` for each package it uses.
- A top-level type that contains itself is parsed with
  `<Pkg>.Max_Depth`; a field of that type is read with its procedure.
- A test whose top-level type has parameters is `not translated`, since a
  `.kst` has no way to give them (the environment variable `ADA_SG_TOP_ARGS`,
  for example `3`, supplies them for experiments).
- `KNOWN_DIFFERENCES` at the top of `scripts/run-kaitai-suite.sh` lists tests
  that fail for a documented reason (name and reason). If such a test fails it
  is reported as `known difference` and does not make the script fail; if it
  passes, it is `passed`.
- `--round-trip` calls the compiler with `--read-write` and makes every test
  program write the parsed value with `<Pkg>.Write` into an array of 2 x input
  + 16 bytes. C is what `Parse` consumed, N what `Write` produced. The program
  prints `round trip: same` (N = C and the bytes equal the input), or, if the
  output differs, parses it again, writes that value again and checks that
  the second output equals the first and that the asserts of the test hold
  for the reparsed value: then `round trip: canonical (first difference at
  <offset>, wrote N of C)`. Otherwise `round trip: differs at <offset> (wrote N
  of C)` or `round trip: not written (<status>)`. `same` is the class
  `passed`, `canonical` a class of its own that is not a failure, the others
  `failed`. The causes found are in the section "Round trip" of `SUITE.md`.

## Comparing the Ada parsers with the Python parsers

The suite above checks the asserts of the tests, which are true for the data
file of each test. A parser can still differ from the other targets on any
other input: a `valid` that is not checked, bit fields that are aligned
differently, strings that are compared in another encoding. `scripts/diff-python.sh`
parses many inputs with the Ada parser and with the Python parser that the
same compiler build generates, and compares what both found.

```
scripts/build-compiler.sh                         # once
scripts/diff-python.sh                            # all formats, 200 mutations of each data file
scripts/diff-python.sh --out /tmp/diff --inputs 50 --jobs 4 hello_world str_encodings
```

For every format in `formats/` that has a test with a data file and that the
Ada backend generates, and for the formats of `compiler/diff-formats/` (our own:
`x_<name>.ksy` with its data file `x_<name>.bin`, for what the data of the tests
do not exercise: bit fields in both orders, UTF-16, `valid` on repetitions,
switches with sizes, integer expressions that overflow, terminators and padding,
parse instances; `--formats DIR` names another directory), the script

1. generates the Ada and the Python parser,
2. generates two dump programs from the same `ClassSpec`s with `AdaDiff`
   (`tests-overlay/.../specgenerators/AdaDiff.scala`, which takes its names from
   `AdaClassCompiler` as `AdaSG` does): one in Ada, one in Python. A dump has
   one line `path = value` for every parameter, field, instance (value and
   parse instance), element of a repetition and nested value, in the order of
   the description: integers and enumerations in decimal, booleans 0 or 1,
   floats as the hex of their bits (`nan` for every NaN), bytes and strings as
   the hex of the raw bytes (Python encodes its string again with the
   encoding of the field), `absent` for a member that is not there,
   `path.size = N` for a repetition, `path.case = Name` for the chosen case of
   a switch that is not all integers. Processed fields are dumped decoded. A
   failure anywhere while the whole value is walked, in a parse instance, an
   element, an instance or `Parse`, gives the single line `FAILED` on both
   sides (and a `#why` line, which the comparison ignores). `contents` fields
   are not dumped, as the Ada parsers do not keep them; the parsers check them,
   and a mismatch is a failure.
3. makes the inputs: the data file and `--inputs N` (default 200) changes of it
   with a fixed seed. The first eight are the same for every format (empty,
   zeros, 0xff, one byte less, half, one zero byte more, twice, without the
   first byte). Then every position of the data file is changed on its own, in
   a random order, as far as two thirds of the inputs reach, so that no field is
   missed (a byte order that is wrong in one field shows only if that field is
   changed to something that is not its own mirror image). The rest flip bits,
   overwrite bytes, truncate, extend, duplicate, delete or insert ranges, and
   overwrite with a number or string taken from the description (magic numbers,
   `valid`, case labels, enumeration values), also several of them together. They
   come in batches, and a mutant whose Python dump has a shape that no earlier
   input had (another case of a switch, a member that is there or not, another
   kind of failure) becomes a seed of the later ones. The same files go to both
   programs.
4. builds all Ada dump programs with `gprbuild`, with run-time checks on and
   contracts executed (`-gnata`, `KAITAI_STRUCT_CONTRACTS=on`), one project
   in the output directory,
5. runs both programs on every input (all inputs in one process; a process
   that dies or hangs is run again one input at a time) and compares.

The Python runtime is taken from `kaitai_struct_python_runtime`, cloned to
`$HOME/.cache/kaitai_struct_python_runtime` at a pinned commit
(`KAITAI_PYTHON_RUNTIME` names another checkout), since the code that this
compiler generates uses `KaitaiStream.substream`, which the release 0.11 of
`kaitaistruct` on PyPI does not have.

### Reading the result

`DIR/results.md` has a table of the classes of all inputs, a table per format
(inputs, how many Ada and Python parsed, the leaves of the seed and of all
inputs with the same dump, the classes), the formats that were skipped with the
reason, and every difference with its smallest input. The same is printed as a
summary. Inputs and the dumps of the differences are kept in `DIR/inputs/<format>/`
and `DIR/diffs/<format>/` (`<input>.bin`, `.ada`, `.py`).

| Class | Meaning |
|---|---|
| same dump | both parsed and the dumps are equal |
| both fail | both gave `FAILED` |
| dump over the limit | the dump is larger than 8 MB, both gave up at the same line; not compared further |
| Python timeout or memory | Python did not finish or ran out of memory (3 GiB; a repetition of billions of empty elements), not compared; not a failure of the script |
| known | a difference of `KNOWN_DIFFERENCES` in the script, each with the reason; counted, not hidden |
| values differ | both parsed, a line differs: the first differing line is given |
| only Ada fails / only Python fails | one side gave `FAILED`, the other a dump; the `#why` of the failing side is given |
| Ada exception | the Ada program raised an exception, or a precondition or postcondition failed |
| no result | a program crashed or timed out |

The exit status is 0 only if there is no input of the classes `values differ`,
`only Ada fails`, `only Python fails`, `Ada exception` and `no result`, and no
program failed to build. Inputs with the same cause are one difference in the
list. A format is `skipped` if the backend rejects it, it has no test with a
data file, or no dump can be generated; the reason is in the table.

A comparison that finds nothing says little unless the inputs get far enough:
look at the columns `Ada ok` and `Python ok` (a format where all inputs fail on
both sides tests only the first field) and at the leaves per format.
`--reuse` keeps the generated parsers, dumps and inputs of an earlier run, so
that a generated Ada parser can be changed by hand to see whether the
comparison finds the change.
