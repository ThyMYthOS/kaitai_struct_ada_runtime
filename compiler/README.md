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
