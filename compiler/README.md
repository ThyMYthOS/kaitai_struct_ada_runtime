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
| `upstream.patch` | the edits of existing upstream files: the registry (`LanguageCompilerStatic`), `Main.scala`, the option `--ada-max-depth` (`RuntimeConfig.scala`, `JavaMain.scala`), and `project/plugins.sbt` (`sbt-scalajs-crossproject` 1.3.2 instead of 1.0.0, which is no longer found) |

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

## What is supported

Integers `u1`..`u8`, `s1`..`s8` (fixed byte order, byte order decided at run
time, `endian: switch-on`), bit fields `b1`..`b64` with `bit-endian`, floats
as raw bits with the accessor pair, bytes and strings with `size`,
`size-eos`, `terminator` (also several bytes), `pad-right`, `include`,
`consume`, `eos-error`, string encodings, `contents`, `valid` (`eq`, `min`,
`max`, range, `any-of`, `in-enum`, `expr`; also on repetitions of integers of a fixed size), `if`, enumerations, `switch-on`
with structures or with integers, `size`, `size-eos`, `terminator` and
`pad-right` on fields of a type (the value is parsed from the cut bytes),
`repeat: expr/eos/until` (structures and byte/string elements with a cursor,
integers and floats of a fixed size as a slice), value instances (integer,
boolean, enumeration, bytes, string), parse instances with `pos`, `size` and
`io: _root._io`, parameters of integer, boolean or enumeration type, nested
types by path, doc strings as comments.

`_parent` and `_root` (as parameters of `Parse`, for integers, booleans and
enumerations, chains such as `_parent._parent.x` included), `process` (`xor`
with a byte or a bytes key, `rol`, `ror`, `zlib`; the accessor undoes it into
an array of the caller), types that contain themselves (directly or through a
repetition, with `Depth`; `--ada-max-depth N` sets `Max_Depth`, default 8),
imports (a type of another description is `<Package>.T`; all files of a
compilation are written).

Expressions: integer arithmetic in S64 with the guards of `Kaitai.Arithmetic`
(dropped where interval arithmetic shows they hold), comparisons, `and`,
`or`, `not`, `?:`, enumeration labels, fields of nested values, `.size` of
repetitions, `_io.size/pos/eof`, `.length`, `.to_i`, `.min/.max/.first/.last`
of bytes, subscripts of bytes and of repetitions of integers of a fixed size, comparison of bytes and strings with literals, `sizeof`.

## What is rejected

Each of these is a compile error that names the construct and the path of
the attribute: types that contain each other (also through imports; only a
type that contains itself is supported), `_parent` in the top-level type of a
description, `_root` in a type of another description that is used from
elsewhere or in a description whose top-level type contains itself, the
key `parent` on a field whose type uses `_parent`, `_parent`/`_root` values
that are not integers, booleans or enumerations, `process` that is custom, on a string, on a repeated field, on
a switch field or on a parse instance, and an expression or `valid` that
depends on a processed value, opaque types, floating-point arithmetic,
string concatenation, `substring`, `reverse`, `to_s`, array subscripts and
arrays in expressions beyond `.size` and subscripts of repetitions of other elements, `_index`, casts, parameters of other
types, `repeat` on parse instances or on switch fields, `valid` on other repeated
fields, parse instances used in expressions, encodings `UTF-16` without byte
order, `UTF-32` and the like, `valid` on a field whose type is chosen by
`switch-on`, comparisons and `to_i` of strings in UTF-16, comparisons of
strings in different encodings other than ASCII and UTF-8, and `.length` of
strings in Shift_JIS, Big5 or EUC-KR.

A type whose first field is a bit field starts at a byte boundary here,
while in the other targets it goes on in the byte that bit fields before it
left open. Such a type is accepted as a field only where the stream is
certainly at a byte boundary (directly after a field of whole bytes without
condition or repetition); other uses are rejected (see "What differs" in
`docs/codegen.md`).

## Writing

With `--read-write` the compiler also generates `procedure Write` for every
type, as described in the section "Writing" of `docs/codegen.md`. An example
can carry compiler options in a file `options` next to its `.ksy`;
`examples/write_model` and some others have `--read-write` there. Under the
option these are rejected, each with an error that names the construct: a
type that contains itself, a terminator of more than one byte, a terminator
that is included but not consumed, a value cut from bytes with a size and a
terminator or padding, an integer switch whose cases have different types,
`contents` with a condition. `scripts/survey.sh --read-write` repeats the
survey with the option.

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
`Kaitai.Files`, parses with `<Pkg>.Parse (Buffer.all, S, R)` and prints one
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

### Processed fields, imports, recursion, known differences, round trips

- A field with `process` has an accessor that is a procedure. `AdaSG` gives it
  an array on the heap (as large as the input for `xor` and `rol`/`ror`, 256
  times the input plus 4 KiB for `zlib`) and compares `Target (First .. Last)`;
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
