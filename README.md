# Kaitai Struct for Ada and SPARK

[Kaitai Struct](https://kaitai.io) describes binary formats in `.ksy` files and
generates parsers from them. This repository makes Ada a target language:

- a **runtime library** in SPARK that generated parsers are built on, and
- a **backend for the Kaitai Struct compiler** that generates such parsers.

The aim is that a parser generated from a `.ksy` description is proven free
of run-time errors for *any* input, so that a malformed or malicious file can
at worst be rejected. GNATprove proves the library and the generated parsers
automatically.

**Status:** usable for a large part of the language, not complete. The
compiler generates parsers for 262 of the 334 formats of the Kaitai Struct
test suite, all of them proven, and rejects the rest with an error that names
the construct; [compiler/SURVEY.md](compiler/SURVEY.md) has the list. Of the
320 tests of that suite 250 pass, one fails because of a documented
difference, two cannot be translated, and 67 are for formats that are
rejected ([compiler/SUITE.md](compiler/SUITE.md)). With the option
`--read-write` the compiler also generates `Write`, which writes a parsed
value again. There are no operations yet that change a value or build one
from nothing. The
[plan](https://github.com/ThyMYthOS/kaitai_struct_ada_runtime/issues/1) (in
German) tracks what is decided, measured and done.

## Properties

- **No heap, no exceptions, no secondary stack.** The library and the
  generated parsers run on a light run-time library on a microcontroller.
- **Zero copy.** A stream is a cursor over a buffer the caller owns. Byte
  arrays and strings are slices of that buffer, and repetitions are parsed
  again when asked for instead of being stored.
- **Failures are values.** A read that cannot be carried out records the
  reason in the stream and delivers zero; the first failure is kept.
- **Proven.** GNATprove proves all run-time checks and the functional
  contracts of the library, and all run-time checks of generated parsers, so
  both can be built with checks left out.
- **Measured.** Design decisions rest on instruction counts on x86-64 and on
  a simulated Cortex-M4; the programs are under `bench/`.

## A generated parser

From

```yaml
meta:
  id: hello_world
seq:
  - id: one
    type: u1
```

the compiler generates a package that is used like this:

```ada
with Hello_World;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

procedure Example (Buffer : Bytes) is
   S : Stream := Open (Buffer);
   R : Hello_World.T;
begin
   Hello_World.Parse (R, Buffer, S);
   if Hello_World.Valid (R) then
      --  Hello_World.One (R) is the byte; reading it from a result that
      --  is not valid would violate a precondition, which GNATprove finds
      null;
   else
      --  Status (S) tells why
      null;
   end if;
end Example;
```

A generated specification documents itself: the package begins with the
call of `Parse` to use, and every declaration has a comment that says what it
delivers and what it requires, with the `doc` texts of the description where
there are any. [docs/codegen.md](docs/codegen.md) describes what generated
code looks like and why. `examples/` holds generated parsers with their
descriptions; `examples/showcase` uses most constructs in one description.

`This`, the value, is the first parameter of every operation of a generated
package that has it, so that the caller may write the object first. GNAT allows
that for untagged types as an extension, which the caller switches on with
`pragma Extensions_Allowed (On);` in the unit (or `-gnatX` for the build):

```ada
pragma Extensions_Allowed (On);
...
   R.Parse (Buffer, S);                 --  Hello_World.Parse (R, Buffer, S)
   if R.Valid then                      --  Hello_World.Valid (R)
      Byte := R.One;                    --  Hello_World.One (R)
```

It is not standard Ada, and it finds only the operations that the package of the
type declares; a caller that does not use it writes `Parse (R, Buffer, S)`.
[docs/codegen.md](docs/codegen.md) says what works and what does not.

## The library

| Package | Content |
|---|---|
| `Kaitai.Types` | integers, `Bytes`, `Slice`, the status of a stream |
| `Kaitai.Streams` | the stream: integers, bit fields, byte arrays, terminated byte arrays, `contents`, substreams, elements of repetitions |
| `Kaitai.Decoding`, `Kaitai.Encoding` | integers from and to bytes at an index |
| `Kaitai.Bits`, `Kaitai.Floats` | bit field arithmetic; floats from their bits |
| `Kaitai.Byte_Arrays` | search, comparison, minimum and maximum, without copying |
| `Kaitai.Strings` | validity and character count for ASCII, UTF-8, UTF-16 and UTF-32, conversion to UTF-8, numbers from and to text |
| `Kaitai.Arithmetic` | integer arithmetic of expressions that cannot overflow |
| `Kaitai.Float_Arithmetic` | floating point arithmetic of expressions that cannot overflow, and `to_i` |
| `Kaitai.Processing`, `Kaitai.Zlib` | `process`: xor, rotation, zlib decompression |
| `Kaitai.Arenas` | hands out parts of an array of the caller |
| `Kaitai.Writers` | the counterpart of the stream for writing |
| `Kaitai.Files` | reads a file into a buffer; in `kaitai_struct_files.gpr`, since it needs a file system |

All of it is in SPARK and proven, except the body of `Kaitai.Files`, which
handles the exceptions of the Ada file packages and is tested instead.

## The compiler backend

`compiler/` is an overlay over the upstream
[Kaitai Struct compiler](https://github.com/kaitai-io/kaitai_struct_compiler)
at a pinned commit.

```sh
scripts/build-compiler.sh             # clones upstream, applies the overlay, builds; prints the launcher
<launcher> -t ada --outdir out format.ksy
<launcher> -t ada --read-write --outdir out format.ksy   # with Write
scripts/generate-examples.sh --check  # the parsers under examples/ are what the compiler generates
scripts/survey.sh --prove             # all formats of the Kaitai Struct tests: generate, compile, prove
scripts/run-kaitai-suite.sh           # the tests of the Kaitai Struct test suite; --round-trip also writes
```

[compiler/README.md](compiler/README.md) lists what is supported and what is
rejected.

## Layout

| Path | Content |
|---|---|
| `src/`, `files/` | the library |
| `compiler/` | the backend for the Kaitai Struct compiler |
| `examples/` | descriptions with the parsers generated from them |
| `docs/codegen.md` | the rules generated code follows |
| `tests/` | tests for the development machine, and a fuzz program for the parsers |
| `tests/target/` | the same tests for a simulated STM32F4 |
| `bench/` | measurements that back design decisions |
| `scripts/` | toolchain installation, checks, simulator, compiler build |
| `kaitai_style.gpr` | coding style shared by all projects |

## Building and checking

The toolchain comes from [Alire](https://alire.ada.dev).
`scripts/install-toolchain.sh` installs pinned versions of everything on
Debian or Ubuntu; it is what the CI uses.

```sh
alr build                 # the library
scripts/check.sh          # everything the first CI job checks
scripts/check.sh prove    # a single step
```

| Step | What it shows |
|---|---|
| `format` | sources are formatted with `gnatformat` |
| `build` | the library builds without warnings in all configurations |
| `test` | the tests pass on the development machine |
| `fuzz` | the parsers survive input changed at random, with checks on and contracts executed |
| `prove` | GNATprove proves all checks of the library and of the parsers under `examples/` |
| `target` | the tests pass on a simulated STM32F4 with a light and an embedded run-time library |
| `bench` | the benchmarks build and agree on their results |
| `doc` | GNATdoc finds a documentation comment for every declaration that a user of the library or of a generated parser sees |

A second CI job builds the compiler and checks that `examples/` is what it
generates.

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

## Limits to know about

- The proof covers run-time errors and termination, not the size of the
  stack. A type that contains itself is parsed recursively up to a fixed
  depth; `docs/codegen.md` says what a level costs. `Kaitai.Zlib` needs about
  2 KiB of stack.
- A light run-time library does not notice a stack overflow.
- Generated parsers do not store repetitions and do not keep references to
  parent values; `docs/codegen.md` lists what differs from other Kaitai
  Struct targets.

## License

MIT, see [LICENSE](LICENSE).
