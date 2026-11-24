# Kaitai Struct runtime library for Ada and SPARK

[Kaitai Struct](https://kaitai.io) describes binary formats in `.ksy` files and
generates parsers from them. This library is what such parsers are built on
when the target language is Ada: it provides the stream to read from and the
operations of the Kaitai Struct stream API.

The library is written in SPARK. Its aim is that parsers generated from a
`.ksy` description can be proven free of run-time errors for *any* input, so
that a malformed or malicious file can at worst be rejected.

**Status:** early. The stream reads integers, bit fields, floating point
numbers and byte arrays, and supports substreams; all of it is tested and
proven. Four formats of the Kaitai Struct test suite are translated by hand
under `examples/`. Strings, enumerations, repetitions and the compiler backend
that generates code against the library are still to come. The
[plan](https://github.com/ThyMYthOS/kaitai_struct_ada_runtime/issues/1) (in
German) tracks what is decided, measured and done.

## Properties

- **No heap, no exceptions, no secondary stack.** The core runs on a light
  run-time library on a microcontroller.
- **Zero copy.** A stream is a cursor over a buffer the caller owns; byte
  arrays are returned as slices of that buffer.
- **Failures are values.** A read that cannot be carried out records the
  reason in the stream and delivers zero; the first failure is kept. Check
  once before a decision that depends on what was read, and at the end.
- **Proven.** GNATprove proves all run-time checks and the functional
  contracts of the library, so it can be built with checks left out.

## Example

```ada
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

procedure Parse (Buffer : Bytes) is
   S       : Stream := Open (Buffer);
   Version : U8;
   Size    : U32;
   Payload : Slice;
begin
   Read_U1 (Buffer, S, Version);
   Read_U4le (Buffer, S, Size);
   Read_Bytes (S, To_Length (U64 (Size)), Payload);
   if OK (S) then
      --  Buffer (Payload.First .. Payload.Last) is the payload
      null;
   end if;
end Parse;
```

The parsers under `examples/` show what generated code looks like; they are
proven against the library. [docs/codegen.md](docs/codegen.md) describes the
rules they follow.

## Layout

| Path | Content |
|---|---|
| `src/` | the library: `Kaitai.Streams` and what it builds on |
| `examples/` | formats of the Kaitai Struct test suite, translated by hand |
| `docs/codegen.md` | how generated code uses the library |
| `tests/` | tests for the development machine |
| `tests/target/` | the same tests for a simulated STM32F4 |
| `bench/` | measurements that back design decisions |
| `scripts/` | toolchain installation, checks, simulator |
| `kaitai_style.gpr` | coding style shared by all projects |

## Building and checking

The toolchain comes from [Alire](https://alire.ada.dev).
`scripts/install-toolchain.sh` installs pinned versions of everything on
Debian or Ubuntu; it is what the CI uses.

```sh
alr build                 # the library
scripts/check.sh          # everything the CI checks
scripts/check.sh prove    # a single step: format, build, test, prove, target, bench
```

| Step | What it shows |
|---|---|
| `format` | sources are formatted with `gnatformat` |
| `build` | the library builds without warnings in all configurations |
| `test` | the tests pass on the development machine |
| `prove` | GNATprove proves all checks of the library and of the parsers using it |
| `target` | the tests pass on a simulated STM32F4 with a light and an embedded run-time library |
| `bench` | the benchmarks build and agree on their results |

## Configuration

Scenario variables of `kaitai_struct.gpr`:

| Variable | Values | Meaning |
|---|---|---|
| `KAITAI_STRUCT_CHECKS` | `enabled`, `proven` | `proven` leaves run-time checks out; a parser then needs less than half of the instructions |
| `KAITAI_STRUCT_CONTRACTS` | `off`, `on` | `on` checks contracts at run time, for testing |
| `KAITAI_STRUCT_RESTRICTIONS` | `off`, `on` | `on` compiles under the restrictions of a light run-time library |
| `KAITAI_STRUCT_SUBDIR` | name | keeps builds for different targets apart |

Compile code that uses the library with `-gnatn`. The read operations are
small and meant to be inlined; without it a parser needs 50 to 70 percent
more instructions.

## License

MIT, see [LICENSE](LICENSE).
