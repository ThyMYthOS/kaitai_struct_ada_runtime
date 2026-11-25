# Changelog

## Unreleased

- Compiler: `_sizeof` and `x._sizeof` are translated (they are the size in bytes of
  the current type or of a value, a constant). They failed with "invalid ID".

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
