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
| `upstream.patch` | the edits of existing upstream files: the registry (`LanguageCompilerStatic`), `Main.scala`, and `project/plugins.sbt` (`sbt-scalajs-crossproject` 1.3.2 instead of 1.0.0, which is no longer found) |

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
`max`, range, `any-of`, `in-enum`, `expr`), `if`, enumerations, `switch-on`
with structures or with integers, `size` and `size-eos` substreams,
`repeat: expr/eos/until` (structures and byte/string elements with a cursor,
integers and floats of a fixed size as a slice), value instances (integer,
boolean, enumeration, bytes, string), parse instances with `pos`, `size` and
`io: _root._io`, parameters of integer, boolean or enumeration type, nested
types by path, doc strings as comments.

Expressions: integer arithmetic in S64 with the guards of `Kaitai.Arithmetic`
(dropped where interval arithmetic shows they hold), comparisons, `and`,
`or`, `not`, `?:`, enumeration labels, fields of nested values, `.size` of
repetitions, `_io.size/pos/eof`, `.length`, `.to_i`, `.min/.max/.first/.last`
of bytes, comparison of bytes and strings with literals, `sizeof`.

## What is rejected

Each of these is a compile error that names the construct and the path of
the attribute: `_parent` and `_root` (except `_root._io` and `_parent` in the
byte order switch), recursive types, `process`, imports and opaque types,
floating-point arithmetic, string concatenation, `substring`, `reverse`,
`to_s`, array subscripts and arrays in expressions beyond `.size`,
`_index`, parameters of other types, `repeat` on parse instances or on
switch fields, `valid` on repeated fields, encodings `UTF-16` without byte
order, `UTF-32` and the like, and `--read-write`.

`compiler/SURVEY.md` lists what happens to the 334 formats of the Kaitai
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
