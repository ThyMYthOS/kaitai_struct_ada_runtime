# Generated code

How the Kaitai Struct compiler is meant to translate a `.ksy` description into
Ada that uses this library. The compiler backend does not exist yet; the
parsers under `examples/` are translated by hand according to this document
and are tested and proven in the CI. Where a rule rests on a measurement, the
figure is given.

This is the first version. It covers what the library offers so far: integers,
bit fields, byte arrays, terminated byte arrays, `contents`, nested types and
instances with a position. Enumerations, strings, repetitions, `switch-on`,
parameters and `process` are not covered yet.

## Shape of a parser

A type of the description becomes a package, a nested type a nested package.
The package for `hello_world.ksy`:

```ada
package Hello_World
  with SPARK_Mode, Always_Terminates
is
   type T is private;

   function Valid (This : T) return Boolean;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
   with Pre => Is_Valid (S, Buffer), Post => Is_Valid (S, Buffer) and then Valid (This) = OK (S);

   function One (This : T) return U8
   with Pre => Valid (This);
private
   ...
end Hello_World;
```

- `T` is a record without pointers. It can be copied and needs no clean-up.
- `Valid (This)` tells whether `This` holds the result of a successful `Parse`.
  Every accessor has it as its precondition, so that a caller cannot read from
  a result that was never parsed.
- `Parse` takes the buffer, the stream and the result. It never raises. After
  it, `Valid (This) = OK (S)`; the reason for a failure is `Status (S)`.
- Each field has an accessor function named after it.

## The stream inside `Parse`

`Parse` copies the stream into a local variable, reads from that, and copies it
back at the end:

```ada
procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
   L : Stream := S;
begin
   Read_U1 (Buffer, L, This.One);
   This.Is_Valid := OK (L);
   S := L;
end Parse;
```

The compiler keeps a local stream in registers. A stream that is a parameter
it has to keep in memory, because it cannot rule out that the stream and the
buffer overlap. Measured with run-time checks left out, on x86-64 and on a
Cortex-M4 alike: 91 instructions per record of four fields when reading
through the parameter, 60 through a local copy.

`This` is assigned as a whole first (`This := (others => <>);`) only if some
path through `Parse` leaves a component unassigned. Otherwise GNATprove
reports the assignment as unused.

## Fields

| In the description | In `Parse` | Type of the field |
|---|---|---|
| `u1` … `u8`, `s1` … `s8` with fixed byte order | `Read_U4le (Buffer, L, This.X)` and the like | `U8` … `U64`, `S8` … `S64` |
| the same with byte order decided at run time | `Read_U4 (Buffer, L, Order, This.X)` | as above |
| `f4`, `f8` | read as `u4`, `u8`; `Kaitai.Floats.To_F32` after `Is_Finite` | `U32`, `U64` |
| `b1` | `Read_Bits_Int_Be (Buffer, L, 1, Bit); This.X := Bit /= 0;` | `Boolean` |
| `bN` | `Read_Bits_Int_Be (Buffer, L, N, This.X)` or `…_Le` | `U64` |
| bytes with `size` | `Read_Bytes (L, To_Length (U64 (Size)), This.X)` | `Slice` |
| bytes with `size-eos` | `Read_Bytes_Full (L, This.X)` | `Slice` |
| bytes or string with `terminator` | `Read_Bytes_Term (Buffer, L, Term, Include, Consume, EOS_Error, This.X)` | `Slice` |
| `contents` | `Read_Contents (Buffer, L, Expected)` | not stored; `Expected` is a constant of the package |
| field of a nested type | `Nested.Parse (Buffer, L, This.X)` | `Nested.T` |
| field of a nested type with `size` | `Substream (Buffer, L, Size, Sub); Nested.Parse (Buffer, Sub, This.X); Join (L, Sub);` | `Nested.T` |

A length that comes from the data goes through `To_Length`. A value that no
buffer can have then makes the read fail with `End_Of_Stream`, without a check
in the parser. On a 32-bit target this matters: a `u4` need not fit into a
length there.

### Bit fields

A run of bit fields starts at a byte boundary. Reads that are not bit fields
align by themselves, so nothing is needed after one of them. Where a run of
bit fields is the first thing a `Parse` reads, it starts with
`Align_To_Byte (L)`. That costs one store and tells the compiler the state of
the bits, which lets it resolve the constant widths at compile time.

### Byte arrays and strings

A `Slice` refers to bytes of the buffer and is only meaningful together with
it. A type that has slices gets a function

```ada
function Belongs_To (This : T; Buffer : Bytes) return Boolean;
```

which `Parse` establishes for the buffer it read from. With it a caller can
prove that `Buffer (This.X.First .. This.X.Last)` is within bounds.

Strings are slices as well for now; their encoding is not checked yet.

## Instances

An instance with a value is a function. If it has a condition, a second
function tells whether it has a value, and is the precondition of the first:

```ada
function Has_Test_If_B1 (This : T) return Boolean
with Pre => Valid (This);
function Test_If_B1 (This : T) return S64
with Pre => Valid (This) and then Has_Test_If_B1 (This);
```

An instance with a position is parsed when it is asked for and is not kept in
`This`. For that, `T` keeps a copy of the stream as it was when `Parse`
began. The accessor is a procedure, because it reads from the buffer:

```ada
procedure Hdr (Buffer : Bytes; This : T; Result : out Header.T; Outcome : out Status_Kind)
with
  Pre  => Valid (This) and then Belongs_To (This, Buffer),
  Post => Header.Valid (Result) = (Outcome = Success);
```

Asking twice parses twice. The caller keeps the result if it needs it again.

## What differs from other Kaitai Struct targets

- There are no `_io`, `_parent` and `_root` references. What a type needs from
  its parent or from the root is passed to its `Parse` as a parameter.
- A failure is not an exception. It is the status of the stream.
- `contents` fields are checked but not stored.
- Seeking beyond the end of the stream fails at once, not at the next read.

## Building generated code

- Compile with `-gnatn`. The read operations are meant to be inlined; without
  it a parser takes 50 to 70 percent more instructions.
- Once the parsers are proven, build with `KAITAI_STRUCT_CHECKS=proven` and
  with `-gnatp` for the parsers themselves. With run-time checks a parser
  that reads bytes takes two and a half times the instructions, one that
  reads bit fields seven times.
- The hand-translated examples are proven by GNATprove at `--level=1` without
  any annotation beyond the contracts shown here.
