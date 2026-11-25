# Generated code

How the Kaitai Struct compiler translates a `.ksy` description into Ada that
uses this library. `examples/showcase` shows every rule of this document in
one parser; it is tested and proven in the CI. Where a rule rests on a
measurement, the figure is given.

The generated code is the *zero-copy variant*: it runs on a light run-time
library, uses neither heap nor exceptions, and never copies input. A parsed
value refers to the buffer it was parsed from wherever that saves a copy.

## Names

An identifier of the description becomes an Ada identifier with every word
capitalised: `len_of_1` becomes `Len_Of_1`.

| In the description | In Ada |
|---|---|
| the description `foo` | package `Foo`, in `foo.ads` and `foo.adb` |
| type `bar` | nested package `Bar_Type` |
| enumeration `baz` | type `Baz_Enum` with literals `Baz_<Label>` |
| field or instance `qux` | function or procedure `Qux` |

The suffixes keep a field apart from a type or an enumeration of the same
name, which descriptions have all the time (`header` of type `header`).

A name gets the suffix `_Field` if it is
- a reserved word of Ada,
- used by the generated code itself (`T`, `Parse`, `Valid`, `Belongs_To`,
  `Next`, `Has_Element`, `Remaining`, `Max_Depth`, `Is_Valid`, `Io`, and the
  names `This`, `Buffer`, `S`, `Order` of parameters),
- `Kaitai`, or an identifier of package Standard that the code uses
  (`Boolean`, `True`, `False`, `Natural`, `Positive`, `Integer`, `String`,
  `Character`, `Standard`),
- the name of the enclosing top-level package.

A parameter of a type also avoids the names of the local variables of
`Parse` (`Sub`, `Bit`, `Element`, `Done`, `Value`, …). Only the name of the
accessor and of the component get the suffix; the names derived from it
(`Body_Case`, `Has_Body`, `Body_Count`) are built from the plain name. A
description whose own id is `kaitai` or a reserved word is rejected.

Names that the generated code derives from an identifier keep their form:
`Has_X`, `X_Count`, `X_First`, `X_Cursor`, `X_Value`, `X_Bits`, `X_Case`,
`X_Kind`, `X_As_Y`, `X_Is_Y`, `Get_X`, `X_Type`, `X_Enum`, the literals of an
enumeration. If one of them would equal a name that comes directly from an
identifier of the description in the same declarative region, the name from
the description gets the suffix `_Field`. A parameter `has_trailer` next to a
field `trailer` with a condition becomes `Has_Trailer_Field`, and the function
that tells whether the field exists stays `Has_Trailer`. The compiler collects
the derived names of a type first and renames afterwards.

## Names of the library

Generated code does not rely on `use` clauses for the library: a declaration
of the generated package hides a use-visible name of the same identifier (a
function `Length` hides the type `Kaitai.Types.Length`). A unit has
`with Kaitai.Streams;`, `with Kaitai.Types;` and so on for what it uses, and
writes every entity with its full name: `Kaitai.Types.U8`,
`Kaitai.Streams.Read_U1 (Buffer, S, This.X)`,
`Kaitai.Arithmetic.Add_OK (A, B)`, `Kaitai.Types.Arithmetic_Error`. The
examples of this document leave the prefixes out to stay short.

Operators are not names. Right after its `is`, the library-level package has
a `use type` clause for each type of `Kaitai.Types` whose operators the unit
uses (`S64` for `+` and `=`, `Length` for the arithmetic of indexes,
`Status_Kind`, `Byte_Order`, `U64`). A clause for a type that no operator
needs would be a warning, so the compiler lists only the used ones.

## Shape of a type

Every type of the description becomes a package, the description itself the
library-level one and each nested type a nested package of the package of
its parent, before anything that uses it:

```ada
package Header_Type is
   type T is private;

   function Valid (This : T) return Boolean;
   function Belongs_To (This : T; Buffer : Bytes) return Boolean;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
   with
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Is_Valid (S, Buffer)
       and then Advanced (S'Old, S)
       and then Valid (This) = OK (S)
       and then Belongs_To (This, Buffer);

   function Version (This : T) return U8
   with Pre => Valid (This);
private
   ...
end Header_Type;
```

- `T` is a record without pointers. All its components have defaults. It can
  be copied and needs no clean-up.
- `Valid (This)` tells whether `This` holds the result of a successful
  `Parse`. Every accessor has it as its precondition, so that nothing can be
  read from a result that was never parsed. It is an expression function:
  the validity flag of `This`, and that every nested value held in `This` is
  valid as well.
- `Belongs_To (This, Buffer)` tells that everything in `This` that refers to
  the buffer lies within `Buffer`. `Parse` establishes it for the buffer it
  read from. A type gets this function only if it or a value nested in it
  holds a slice or a stream.
- `Parse` takes the buffer, the stream, the parameters of the type and the
  result. It never raises. After it, `Valid (This) = OK (S)`; the reason for
  a failure is `Status (S)`. `Advanced` says that the stream covers the same
  bytes as before, has not moved back, and has still failed if it had failed
  before; nested parsers compose through it.
- All functions of the private part are expression functions, which lets
  GNATprove see through them in the code that uses the parser.

### `Parse`

```ada
procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
begin
   Read_U1 (Buffer, S, This.Version);
   Read_U1 (Buffer, S, This.Flags);
   This.Is_Valid := OK (S);
end Parse;
```

`Parse` reads through its stream parameter. A copy of the stream in a local
variable, which the compiler can keep in registers, pays off only where one
procedure reads many fields in a loop of its own; a parser that is called
once per value pays more for the copy than it saves. Measured with run-time
checks left out, for a type of four fields: 61 instructions per value when
reading through the parameter and 70 through a local copy on x86-64, 63 and
82 on a Cortex-M4. It is the same for one to eight fields.

Every component of `This` is assigned on every path. Where that is not so by
itself, because a field has a condition or `This` is handed on as a whole
before `Parse` is done, `Parse` starts with `This := (others => <>);`. It
does not do so otherwise, as GNATprove would report an assignment without
effect.

Nothing in `Parse` returns early. After a failure the remaining reads do
nothing, since a failed stream stays failed, and the values they deliver are
zero or empty.

## Fields

| In the description | In `Parse` | Component |
|---|---|---|
| `u1` … `u8`, `s1` … `s8` with fixed byte order | `Read_U4le (Buffer, S, This.X)` and the like | `U8` … `U64`, `S8` … `S64` |
| the same with byte order decided at run time | `Read_U4 (Buffer, S, Order, This.X)` | as above |
| `f4`, `f8` | read as `u4`, `u8` | `U32`, `U64`; accessors `X_Bits`, and `X` with the precondition `Is_Finite` |
| `b1` | `Read_Bits_Int_Be (Buffer, S, 1, Bit); This.X := Bit /= 0;` | `Boolean` |
| `bN` | `Read_Bits_Int_Be (Buffer, S, N, This.X)` or `…_Le` | `U64` |
| bytes with `size` | `Read_Bytes (S, To_Size (Size), This.X)` | `Slice` |
| bytes with `size-eos` | `Read_Bytes_Full (S, This.X)` | `Slice` |
| bytes or string with `terminator` | `Read_Bytes_Term (Buffer, S, Term, Include, Consume, EOS_Error, This.X)` | `Slice` |
| `pad-right`, `terminator` on bytes with a size | `This.X := Strip_Right (Buffer, This.X, Pad)`, `Terminate_At (…)` after the read | `Slice` |
| string | as bytes, then `if not Strings.Is_Valid (Buffer, This.X, UTF_8) then Fail (S, Illegal_Sequence); end if;` | `Slice` |
| `contents` | `Read_Contents (Buffer, S, Expected)` | none; `Expected` is a constant of the body |
| field of a type | `Foo_Type.Parse (Buffer, S, Arguments, This.X)` | `Foo_Type.T` |
| field of a type with `size` | `Substream (Buffer, S, To_Size (Size), Sub); Foo_Type.Parse (Buffer, Sub, This.X); Join (S, Sub);` | `Foo_Type.T` |
| field with `enum` | as the integer | the integer; see Enumerations |

A size is the value of an expression and goes through `To_Size`. A value
that is negative or that no buffer can have then makes the read fail with
`End_Of_Stream`, without a check in the parser.

A run of bit fields starts at a byte boundary. Reads that are not bit fields
align by themselves. Where a run of bit fields is the first thing a `Parse`
reads, it starts with `Align_To_Byte (S)`, which lets the compiler resolve
the constant widths.

A string is a slice like a byte array; only its encoding is checked.

### Conditions

A field with `if` has a second component `Has_X` and a function of that
name, which is the precondition of the accessor:

```ada
if Bit_And (S64 (This.Flags), 1) /= 0 then
   This.Has_Extra := True;
   Read_U1 (Buffer, S, This.Extra);
end if;
```

### Enumerations

```ada
type Kind_Enum is (Kind_Small, Kind_Big);

function Is_Kind_Enum (Value : S64) return Boolean
is (Value in 1 | 2);

function To_Kind_Enum (Value : S64) return Kind_Enum
with Pre => Is_Kind_Enum (Value);

function To_Integer (Value : Kind_Enum) return S64;
```

A field with an enumeration keeps the integer that was read, because a value
that the enumeration does not name is not an error. It has two accessors:
`Kind_Value` for the integer and `Kind` for the literal, with
`Is_Kind_Enum (S64 (Kind_Value (This)))` as precondition. Expressions compare
the integers.

### Types that depend on a value

A field whose type is chosen by `switch-on` becomes a record with variants:

```ada
type Body_Kind is (Body_Is_Point, Body_Is_Text, Body_Is_None);

function Body_Case (This : T) return Body_Kind
with Pre => Valid (This);

function Body_As_Point (This : T) return Point_Type.T
with Pre => Valid (This) and then Body_Case (This) = Body_Is_Point, Post => Point_Type.Valid (Body_As_Point'Result);
```

`Body_Is_None` stands for a value that no case covers. `Parse` reads each
case into a local value and assigns the record as a whole:

```ada
case This.Code is
   when 1 =>
      declare
         Value : Point_Type.T;
      begin
         Point_Type.Parse (Buffer, S, Value);
         This.Body_F := (Kind => Body_Is_Point, Point => Value);
      end;
   ...
   when others =>
      This.Body_F := (Kind => Body_Is_None);
end case;
```

Cases that are all integers share one component of the widest type instead.

## Repetitions

No repetition is stored element by element, since that would need memory
that grows with the input. What is stored is where the elements are.

### Elements of a fixed size

Integers, floats and byte arrays of a constant size stay in the buffer as
one slice. `Read_Elements (S, Count, Element_Size, This.X)` reads them for
`repeat: expr`, `Read_Elements_Full (S, Element_Size, This.X)` for
`repeat: eos`. The accessors decode on demand:

```ada
function Samples_Count (This : T) return Length
with Pre => Valid (This);

function Samples (Buffer : Bytes; This : T; Index : Length) return U16
with Pre => Valid (This) and then Belongs_To (This, Buffer) and then Index < Samples_Count (This);
```

`Valid` includes that the size of the slice is a multiple of the element
size, which is what proves the access to the buffer.

### Other elements

For a repetition of a type, `Parse` walks over the elements once to check
them and to find the end, and keeps the stream as it was before the first
one and the number of elements:

```ada
This.Entries_Io := S;
This.Entries_Count := To_Count (S64 (This.Num_Entries));
for I in 1 .. This.Entries_Count loop
   Parse_Entries_Element (Buffer, S, This, Element);
   exit when not Entry_Type.Valid (Element);
   pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
end loop;
```

`Parse_Entries_Element` is a procedure of the body that parses one element,
with its substream, arguments and whatever else the field asks for. The
accessors parse again:

```ada
type Entries_Cursor is private;

function Entries_Count (This : T) return Length;
function Entries_First (This : T) return Entries_Cursor;
function Remaining (Position : Entries_Cursor) return Length;
function Has_Element (Position : Entries_Cursor) return Boolean;

procedure Next (Buffer : Bytes; This : T; Position : in out Entries_Cursor; Element : out Entry_Type.T);

procedure Get_Entries (Buffer : Bytes; This : T; Index : Length; Element : out Entry_Type.T);
```

`Next` delivers the element at the cursor and moves on; `Remaining` gets
smaller with every call, which is the variant of a loop over the elements.
`Get_Entries` delivers the element with an index and parses those before it
on the way. An element that `Parse` accepted is accepted again as long as
the buffer has not changed. That is not proven, so the caller checks
`Valid (Element)`.

`repeat: eos` and `repeat: until` run as long as the stream has bytes, at
most once per byte that was left when the loop began. This bound is what
makes the loop terminate, and no element can be empty for it to be reached.
If it is reached, the stream fails with `Limit_Exceeded`.

A count is the value of an expression and goes through `To_Count`: a
negative value means no element.

## Expressions

Integer expressions are computed in `S64`. Every operand is converted to it,
and a `u8` that does not fit makes the expression undefined.

| In the description | In Ada |
|---|---|
| `a + b`, `a - b` | `A + B`, `A - B`, defined if `Add_OK (A, B)`, `Subtract_OK (A, B)` |
| `a * b` | `Multiply (A, B)`, defined if `Multiply_OK (A, B)` |
| `a / b`, `a % b` | `Divide (A, B)`, `Modulo (A, B)`, defined if `Divide_OK (A, B)`, `Modulo_OK (B)` |
| `-a` | `-A`, defined if `Negate_OK (A)` |
| `a & b`, `a \| b`, `a ^ b` | `Bit_And (A, B)`, `Bit_Or (A, B)`, `Bit_Xor (A, B)` |
| `a << b`, `a >> b` | `Bit_Shift_Left (A, B)`, `Bit_Shift_Right (A, B)`, defined if `Shift_OK (B)` |
| comparisons, `and`, `or`, `not` | `=`, `/=`, `<`, …, `and then`, `or else`, `not` |
| `c ? a : b` | `(if C then A else B)` |
| `foo::bar` | the integer of the literal |
| a field of this type | `This.X`, converted |
| a field `x.y` of a nested value | `Foo_Type.Y (This.X)`, defined if `Foo_Type.Valid (This.X)` |
| bytes `==`, `<` | `Byte_Arrays.Equal`, `Byte_Arrays.Compare` |
| `s.length` | `Strings.Character_Count (Buffer, S, Encoding)`; the size of the slice for an encoding of one byte per character |
| `x.size` of a repetition | `X_Count` |
| `_io.size`, `_io.pos`, `_io.eof` | `Size (S)`, `Pos (S)`, `Is_EOF (S)` |

Every expression has a condition under which it is defined, the conjunction
of what the table names for its parts, in the order of evaluation and joined
by `and then`. Where an expression is used in `Parse`, the parser asks first:

```ada
if Subtract_OK (S64 (This.Len_Name), 3) then
   Read_Bytes (S, To_Size (S64 (This.Len_Name) - 3), This.Name);
else
   Fail (S, Arithmetic_Error);
end if;
```

A condition that is always true is left out together with the `if`.

Measured: asking first costs about 20 instructions per record with two
expressions on x86-64, and about 105 on a Cortex-M4 if a product has an
operand wider than 32 bits. Carrying a validity flag along with the value or
passing a flag through procedures costs the same. The compiler drops the
questions that the types answer.

## Instances

An instance with a value is a function. If its expression is not always
defined, a second function tells whether it is, and is the precondition:

```ada
function Has_Total (This : T) return Boolean
with Pre => Valid (This);

function Total (This : T) return S64
with Pre => Valid (This) and then Has_Total (This);
```

The value is computed whenever it is asked for.

An instance with a position is parsed when it is asked for and is not kept
in `This`. For that, `T` keeps the stream as it was when `Parse` began. The
accessor is a procedure, because it reads from the buffer:

```ada
procedure First_Entry (Buffer : Bytes; This : T; Result : out Entry_Type.T; Outcome : out Status_Kind)
with
  Pre  => Valid (This) and then Belongs_To (This, Buffer),
  Post => Entry_Type.Valid (Result) = (Outcome = Success) and then Entry_Type.Belongs_To (Result, Buffer);
```

Asking twice parses twice. The caller keeps the result if it needs it again.
`io: _root._io` is a stream over the whole buffer, `Open (Buffer)`.

## Parameters

The parameters of a type are parameters of its `Parse`, between the stream
and the result, and are kept in `T`, where instances and repetitions find
them again. Each has an accessor.

## Processing

A field with `process` is kept as the bytes that are in the input. The
processing is undone when the field is asked for, into an array of the
caller, since a parser has no memory of its own:

```ada
function Secret_Raw (This : T) return Slice
with Pre => Valid (This);

procedure Secret (Buffer : Bytes; This : T; Target : in out Bytes; Last : out Length; Outcome : out Status_Kind);

procedure Packed
  (Buffer : Bytes; This : T; Storage : in out Bytes; Result : out Inner_Type.T; Outcome : out Status_Kind);
```

`Secret` is for a byte array: the result is `Target (Target'First .. Last)`.
`Packed` is for a field of a type: the bytes are processed into `Storage`
and the value is parsed from there, so that what it refers to lies in
`Storage`. Both report `Capacity_Exceeded` if the array is too small.

A value inside processed bytes is therefore parsed only when it is asked
for, and an error in it shows only then. `Parse` cannot use such a value;
the compiler rejects a description in which a later field depends on one.

`examples/extras` shows this and the next two sections.

## Types that contain themselves

`Parse` of such a type has a parameter `Depth`, the number of levels of
nesting that are accepted below the value. It is passed on reduced by one,
and at zero the stream fails with `Limit_Exceeded`. `Depth` is what proves
that the recursion ends:

```ada
procedure Parse (Buffer : Bytes; S : in out Stream; Depth : Natural; This : out T)
with ..., Subprogram_Variant => (Decreases => Depth, Decreases => 1);
```

The procedure that parses one element has the variant
`(Decreases => This.Depth, Decreases => 0)`, so that the call from `Parse`
to it counts as a step down as well. Where the type is used from outside,
`Depth` is the constant `Max_Depth` of the library-level package, 8 unless
the compiler is told otherwise.

Every level takes room on the stack, and the proof does not cover the size
of the stack. Measured for `examples/extras` on a Cortex-M4 with run-time
checks: 232 bytes per level. A light run-time library gives the main program
4 KiB and does not notice when they are used up; with 32 levels the tests
overwrote other memory on the simulated STM32F4. The default of 8 stays
well within that stack. `-fstack-usage` tells what a level costs for a
given type.

A field of its own type is not held in `T`, which Ada does not allow. Like a
repetition it is parsed again when asked for. A type that contains itself
only through a repetition needs nothing more, since repetitions are not held
either.

## References to the parent and the root

A value has no reference to the value it is part of. Where a type uses
`_parent.x` or `_root.x.y`, the value of that expression becomes a parameter
of its `Parse`, named `Parent_X` or `Root_X_Y`, after the parameters of the
description. It is kept in `T` like those. The parser of the parent passes
it; if it does not have it itself, as for `_root`, it gets the same parameter
and hands it on.

The value is taken when the parser of the parent calls. A reference to a
field that is parsed later, which other targets resolve when an instance is
asked for, is rejected by the compiler.

## Rules of the compiler

Where the rules above are silent, the compiler does the following.

- `This := (others => <>);` is the first statement of `Parse` if some
  component may stay unassigned on a path (a field with `if`, a switch
  without `else`, a failed condition of an expression, a repetition whose
  count is guarded) or if `This` is handed on as a whole (the element
  procedure of a repetition takes it). Otherwise there is none. A type
  without fields has `pragma Unmodified (S);` in `Parse` and no statement
  that touches the stream.
- The value of a parameter is assigned to `This` before anything is read.
  Parameters of an integer, boolean or enumeration type are supported; an
  enumeration is kept as the integer, with the pair of accessors.
- Byte order. A type with a fixed default byte order uses the forms with the
  order in the name. A type whose byte order is calculated by `endian:
  switch-on` that mentions `_parent` is given it as a parameter
  `Order : Byte_Order` (after `S`) by its callers, who compute it from the
  expression with `_parent.x` read as the field `x` of their own type. A type
  that inherits a calculated byte order gets `Order` as well and passes its
  own to nested types. A type whose calculation does not mention `_parent`
  computes `Order` itself at the start of `Parse`. A type with `Order` keeps
  it in `T` for its instances and element procedures. No match and no `_`
  case fails with `Undecided_Endianness`.
- A switch whose cases are all integers keeps one component of the widest
  type; without an `else` case it has `Has_X` as well. Otherwise it is a
  record with variants, one per distinct type of a case (a structure, or
  `Bytes`/`Str` for a slice), named `X_Is_<Type>`; `X_Is_None` is the variant
  of a value that no case covers and is always there. The cases of the
  switch are Ada cases when the expression is an integer or an enumeration
  and all labels are literals, and an `if` chain for strings.
- A repetition of integers or floats of a fixed size is one slice. `repeat:
  until` reads the elements one by one and takes the slice with `Between`;
  its `Valid` does not state that the size is a multiple of the element
  size. A repetition of anything else is walked with a cursor.
- A value instance with a guard is a pair `Has_X`/`X`. Value instances of
  the same type that an expression uses are inserted into the expression, so
  they can be used in `Parse`. A value instance that needs the buffer (a
  string length, a comparison of bytes) takes `Buffer` before `This`, and its
  precondition adds `Belongs_To (This, Buffer)`. A value instance of an
  enumeration has `X_Value` and `X`.
- A parse instance without `io` reads from `This.Io`; with `io: _root._io`
  from `Open (Buffer)`. `pos` is required. An instance with `if` has `Has_X`.
  The result is an `out` parameter of the type of the value; the postcondition
  says `Within (Result, Buffer)` for a slice.
- An expression of a repeated field, `_index`, `_parent`, `_root` other than
  `_root._io`, floats, string operations other than comparison with a
  literal or another string, `.length`, `.to_i`, and array subscripts are
  supported only as the translator lists in `compiler/README.md`; whatever is
  not supported is a compile error with the path of the attribute.
- The argument of a type is passed without conversion when it is a field of
  the same type as the parameter. Otherwise it is converted, and a value
  outside the range of the parameter makes the stream fail with
  `Arithmetic_Error`.
- A string in `ASCII`, `UTF-8`, `UTF-16LE` or `UTF-16BE` is checked; every
  other encoding is `Single_Byte`, which accepts everything. The encodings
  `UTF-16` without byte order, `UTF-32` and the like are rejected.
- `contents` is a constant `X_Expected` of the body, compared by
  `Read_Contents`. `valid` is checked after the read and fails the stream
  with the matching `Validation_*` status.

## What differs from other Kaitai Struct targets

- There are no `_io`, `_parent` and `_root` references in the parsed values.
  What a type needs from its parent or the root is passed to its parser as a
  parameter, and has to be parsed by then.
- The bytes of a field with `process` are processed when the field is asked
  for, not when it is parsed.
- A type that contains itself can be nested only up to a fixed depth.
- A failure is not an exception. It is the status of the stream.
- `contents` fields are checked but not stored.
- Seeking beyond the end of the stream fails at once, not at the next read.
- Repetitions are not arrays. They are walked with a cursor or read by
  index.
- An expression that overflows 64 bits makes the stream fail with
  `Arithmetic_Error`. Integer division rounds down, as the tests of Kaitai
  Struct ask for.

## Writing

A parsed value can be written again. Every type gets, next to `Parse`,

```ada
procedure Write (Buffer : Bytes; This : T; Target : in out Bytes; W : in out Writer)
with
  Pre  => Valid (This) and then Belongs_To (This, Buffer) and then Is_Valid (W, Target),
  Post => Is_Valid (W, Target) and then Same_Window (W'Old, W);
```

`Buffer` is the buffer the value was parsed from; a type that holds nothing
of the buffer has no such parameter. `W` is a writer of `Kaitai.Writers`
over `Target`, which like the stream keeps the first failure; running out of
room is `Capacity_Exceeded`.

`Write` goes through the fields in the order of the description:

| Field | In `Write` |
|---|---|
| integer, float, enumeration | `Write_U4le (Target, W, This.X)` and the like, the integer as it was read |
| bit field | `Write_Bits_Int_Be (Target, W, N, This.X)` |
| bytes or string with a size | `Write_Bytes (Target, W, Buffer (This.X.First .. This.X.Last))` |
| bytes or string with a terminator | `Write_Bytes_Term (…, Term)`; with `pad-right` and a size `Write_Padded` |
| `contents` | `Write_Bytes (Target, W, X_Expected)` |
| field of a type | `Foo_Type.Write (Buffer, This.X, Target, W)` |
| field of a type with `size` | `Subwriter (Target, W, To_Size (Size), Sub); Foo_Type.Write (Buffer, This.X, Target, Sub); Join (W, Sub);` |
| field with `if`, field chosen by `switch-on` | under the same condition, the variant that is there |
| repetition of a fixed size | the slice, with `Write_Bytes` |
| other repetition | a loop over the cursor that writes each element |
| field with `process` | the bytes as they were in the input |

What comes out is the input again, with three exceptions that follow from
what a parsed value keeps: bytes of a substream that the value inside does
not use are written as zeros, padding is written with the padding byte
whatever was there, and instances with a position are not written. An
element of a repetition is parsed again to be written; if the buffer is no
longer what was parsed, the writer fails with `Validation_Expr`.

There are no operations yet that change a parsed value or build one from
nothing. `examples/write_model` is the model for this section, written by
hand; the compiler does not generate `Write` yet.

## Building generated code

- Compile with `-gnatn`. The read operations are meant to be inlined; without
  it a parser takes 50 to 70 percent more instructions.
- Once the parsers are proven, build with `KAITAI_STRUCT_CHECKS=proven` and
  with `-gnatp` for the parsers themselves. With run-time checks a parser
  that reads bytes takes two and a half times the instructions, one that
  reads bit fields seven times.
- The parsers are proven by GNATprove at `--level=1` without any annotation
  beyond what the compiler generates.
