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
  `Next`, `Has_Element`, `Remaining`, `Max_Depth`, `Depth`, `Is_Valid`, `Io`, and the
  names `This`, `Buffer`, `S`, `Order` of parameters),
- `Kaitai`, the name of the package of an imported description, the first name of a package of foreign code (an
  opaque type, a custom `process`; see "Foreign code"), or an identifier of package Standard that the code uses
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
`X_Kind`, `X_As_Y`, `X_Is_Y`, `X_Raw`, `Get_X`, `Parent_X`, `Root_X`, `X_Type`,
`X_Enum`, the literals of an
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

   procedure Parse (This : out T; Buffer : Bytes; S : in out Stream)
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
- `Parse` takes the result, the buffer, the stream and the parameters of the
  type, in that order. It never raises. After it, `Valid (This) = OK (S)`; the reason for
  a failure is `Status (S)`. `Advanced` says that the stream covers the same
  bytes as before, has not moved back, and has still failed if it had failed
  before; nested parsers compose through it.
- `This` is the first parameter of every operation of the visible part that
  has it: `Parse (This : out T; Buffer; S; ...)`, `Write (This; ...)`, the
  accessors (`X (This)`, `X (This, Buffer, Index)`), `Next (This, Buffer,
  Position, Element)`, `Get_X (This, Buffer, Index, Element)`, the
  procedures of instances and of processed fields (`X (This, Buffer, Result,
  Outcome)`). The other parameters keep their order: the buffer before the
  rest, then what the operation takes besides. What is not about the value
  `This` keeps its own object first: `Belongs_To (Position, Buffer)`,
  `Remaining (Position)`, `Has_Element (Position)`, `X_First (This)`, and the
  functions that take no value (`Is_X_Enum (Value)`). The reason is the
  prefixed notation, see "Prefixed notation of the caller" below.
- All functions of the private part are expression functions, which lets
  GNATprove see through them in the code that uses the parser.

### `Parse`

```ada
procedure Parse (This : out T; Buffer : Bytes; S : in out Stream) is
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

The precondition of `Parse` is `Is_Valid (S, Buffer)`. It has a second part,
that no bits are left, where the type starts with bit fields and is entered at
a byte boundary; see Fields.

Nothing in `Parse` returns early. After a failure the remaining reads do
nothing, since a failed stream stays failed, and the values they deliver are
zero or empty.

### Prefixed notation of the caller

`This` comes first so that a caller can write the object before the name of the
operation, as for the objects of a tagged type: `V.Parse (Buffer, S)`,
`V.Valid`, `V.Samples (Buffer, I)`, `V.Next (Buffer, Position, Element)`. For
the types of generated code, which are untagged, this is an extension of GNAT
and not standard Ada. The caller switches it on, in the unit that uses it, with
`pragma Extensions_Allowed (On);` before the context clause, or for the whole
build with the switch `-gnatX`. Generated code itself is plain Ada 2012 and
does not use it; a caller that does not switch the extension on writes
`Parse (V, Buffer, S)` and `Samples (V, Buffer, I)`.

```ada
pragma Extensions_Allowed (On);

with Kaitai.Streams;
with Showcase;

procedure Example (Buffer : Kaitai.Types.Bytes) is
   S        : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
   V        : Showcase.T;
   Position : Showcase.Entries_Cursor;
   Element  : Showcase.Entry_Type.T;
begin
   V.Parse (Buffer, S, 3);                -- Showcase.Parse (V, Buffer, S, 3)
   if V.Valid then                        -- Showcase.Valid (V)
      Position := V.Entries_First;
      while Position.Has_Element loop     -- Showcase.Has_Element (Position)
         V.Next (Buffer, Position, Element);
         exit when not Element.Valid;     -- Showcase.Entry_Type.Valid (Element)
      end loop;
   end if;
end Example;
```

What the notation does and does not do:

- The operation is looked for in the package of the type of the object, that is
  where generated code declares it. `V.Samples (Buffer, I)` finds `Samples`
  of `Showcase`; an operation that the caller declares for the type itself, or
  that another package declares, is not found (GNAT: `no selector "X" for private
  type "T"`). Those are called as before, `X (V)`. So are the operations whose
  object is not their first parameter, `Belongs_To (Position, Buffer)` being the
  cursor's: `Position.Belongs_To (Buffer)` works, `Buffer.Belongs_To (Position)`
  does not.
- The object can be a call of an accessor: `V.Header.Version` is
  `Showcase.Header_Type.Version (Showcase.Header (V))`, since `Version` is in the
  package of the type that `Header` returns.
- The preconditions and postconditions are those of the called operation. GNATprove
  proves a caller that uses the notation as it proves one that does not; `Valid`
  is still required where the contract says so. `tests/src/prefixed_use.adb` is a
  SPARK caller that is proven, `tests/src/prefixed_tests.adb` one that runs on the
  development machine and on the simulated STM32F4.
- `gnatformat` formats such code, and GNATdoc documents the packages that it
  calls as before: the notation is a different spelling of the same call.
- Code that is written for another compiler than GNAT cannot use it.

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
| field of a type | `Foo_Type.Parse (This.X, Buffer, S, Arguments)` | `Foo_Type.T` |
| field of a type with `size` | `Substream (Buffer, S, To_Size (Size), Sub); Foo_Type.Parse (This.X, Buffer, Sub); Join (S, Sub);` | `Foo_Type.T` |
| field with `enum` | as the integer | the integer; see Enumerations |

A size is the value of an expression and goes through `To_Size`. A value
that is negative or that no buffer can have then makes the read fail with
`End_Of_Stream`, without a check in the parser.

A run of bit fields goes on in the byte that the bit fields before it left
open. Reads that are not bit fields align by themselves. Where a type that
starts with bit fields is certainly entered at a byte boundary, its `Parse`
starts with `Align_To_Byte (S)`, which does nothing there but lets the
compiler resolve the constant widths, and has the precondition
`(if Kaitai.Streams.OK (S) then Kaitai.Streams.Bits_Left (S) = 0)`, which
every caller proves.

A type is entered at a byte boundary if each of its uses in the stream of
a type of the same description (a field of the type, or of a case of a
`switch-on`) is not repeated, is not a field of the own type, and either
directly follows a field without condition and repetition that is read as
whole bytes, or is the first field of a type that is entered at a byte
boundary. A field of the own type is parsed again from a stream that was
kept for it, of which nothing is known. A field with `size` or `terminator`
is not a use in the stream: it opens one of its own at a byte boundary, as
does an instance with a position. The top-level type of a description counts
as entered at a byte boundary through its public `Parse`.

A type that starts with bit fields and is not entered at a byte boundary has
neither the precondition nor the `Align_To_Byte`: its bit fields go on where
the stream is, also from one element of a repetition to the next. The
precondition is given to the types that start with bit fields and to those
whose first field is a type that has it, and to no other. A top-level type is
generated the same wherever it is used, so a description that uses the
top-level type of another description, one that has the precondition, where
the stream may be inside a byte is rejected.

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

An enumeration with a value above the largest S64 (up to 2**64-1, and no negative value) has `Is_Kind_Enum`,
`To_Kind_Enum` and `To_Integer` on `U64` instead of `S64`. It is supported on fields and parse instances of unsigned
integers, which hand the integer on as it was read (`Is_Kind_Enum (F4_Value (This))`); a signed field, a value
instance, a parameter and `valid: in-enum` with such an enumeration are rejected.

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
         Point_Type.Parse (Value, Buffer, S);
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

function Samples (This : T; Buffer : Bytes; Index : Length) return U16
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

procedure Next (This : T; Buffer : Bytes; Position : in out Entries_Cursor; Element : out Entry_Type.T);

procedure Get_Entries (This : T; Buffer : Bytes; Index : Length; Element : out Entry_Type.T);
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

`repeat: expr` runs as often as its count says, and the count comes from the
data. Elements that take at least one byte each end the loop when the stream
ends. Elements that may read nothing (a type whose fields all have a size
from an expression, for example) do not, so `Parse` leaves the loop at the
first element that read nothing: every element after it starts in the same
state and reads nothing either. The count stays what the expression says.
`Get_X` stops in the same way, at the first element that read nothing, and
delivers it; so does `Write` at an element that neither read nor wrote
anything. Without this a count of billions in a file of a few bytes would keep
the parser busy for minutes. A loop of the caller over all elements with
`Next` still runs as often as the count says, and the comment of `Next` says so.

A count is the value of an expression and goes through `To_Count`: a
negative value means no element.

#### Bit fields

A repetition of `bN` or `b1` (an enumeration over them too) has a cursor like
the other elements. The element is a `U64` (a `Boolean` for `b1`, the integer
of the enumeration), and the stream of the cursor carries the bit position, so
the next element goes on in the byte that the one before left open. An element
reads at least a bit and fails at the end of the data, so the loop of `repeat:
expr` is bounded by the data and needs no early exit. The `for` loop of
`repeat: eos` and of `repeat: until` has `8 * Remaining + 8` turns (`Length'Last`
where that would pass it, which no stream reaches): `Remaining` bytes and the
7 bits that the byte at the position may still have hold at most `8 * Remaining + 7`
elements, and the turn that finds the end of the data is the last one, as with
elements of a byte, where the bound is `Remaining + 1`. It is the same number for
both, so the bound of `until` does not add one more turn. The cost of `Parse` is
the number of elements, at most 8 times the bytes that are left; of `Next`, a few
instructions; of `Get_X`, the index.

The element of a bit field of N bits (N below 64) has a subtype of its own,
`X_Element`, in the visible part of the package: `Kaitai.Types.U64` range
`0 .. 2**N - 1`. The `Element` of `Next` and `Get_X`, the element that the
procedure of the body reads, the one that `Parse` holds in a loop and the
elements that `Parse` keeps for expressions (`X_First_Element` and the others)
all have it, so the proof knows the bound where the value is used: `nib.first + 1`
and `_ + 1` in a condition ask no overflow question. A bit field of 64 bits and
a `b1` (a `Boolean`) have no such subtype.

#### `_index`

`_index` is a parameter of the procedure of the body that parses one element,
`Parse_X_Element (Buffer, S, [This,] Index, Element)`, of type `Length`. `Parse`
passes the number of the loop, `Next` the number that the cursor holds (the
cursor has a component `Index` then, which `X_First` sets to 0 and `Next` raises
by one), so `Get_X` and a loop of the caller with `Next` parse an element as
`Parse` did. A slice of `This` that the expressions of the element decode
(`sizes[_index]`) must lie in the buffer: the element procedure has it as a
precondition (`Within (This.Sizes, Buffer)`) and `Next` has `Belongs_To (This,
Buffer)` as a precondition.

The rule that an element which read nothing ends the loop (above, in `Parse`,
`Write` and `Get_X`) holds only if every element after it starts in the same
state. With `_index` in the expressions of an element it does not, so these
loops run to the end of the count. What bounds them:

- a count that is a literal, or elements that read at least a byte (or a bit):
  the count, or the data;
- the size of the element is `x[_index]` where `x` is a repetition of integers of
  a fixed size of the same type: the element with the number that `x` has no
  element for makes the stream fail (`Arithmetic_Error`), so at most as many
  elements are parsed as `x` has, and `x` is part of the data;
- otherwise (a count from the data and elements that may read nothing) the
  description is rejected, since nothing bounds the loop: with `00 FF FF FF FF`
  it would run 4294967295 times.

`repeat: until` takes `_index` in its condition as the number of the element
just read, `I - 1`. `_index` in the expressions of a repetition of integers of a
fixed size (a slice, which has no element procedure) is rejected, and so is every
subscript of a repetition of structures, bytes or strings, `x[_index - 1]`
included: such an access would parse the elements before it again for each
element.

#### Values of a whole repetition in expressions

`x.size` is the number of elements. `x.first`, `x.last` and `x[k]` with a constant `k` are an element and have no value
if there is none (the expression is not defined, as a division by zero is not). `x.min` and `x.max` are the least and
largest of integers of a fixed size. A subscript with an index that comes from the data is generated only for integers
of a fixed size, which are a slice; for the others it is rejected, since finding the element would parse those before it
at every use.

- Integers of a fixed size are a slice: `.first`, `.last` and `x[k]` decode one element from the buffer, in constant
  time. `.min` and `.max` call `Kaitai.Decoding.Min_Element` or `Max_Element`, which go over all elements: the cost is
  the number of elements at every evaluation, and an expression that is evaluated for every element of a repetition
  makes the cost grow with the square of the count. Unsigned integers of 8 bytes are rejected for them, since the result
  may not fit the signed 64 bits that expressions compute in.
- Structures, bytes, strings and bit fields: `Parse` keeps the elements that the description uses in the record,
  `X_First_Element` for `.first` and `x[0]`, `X_Last_Element` for `.last` and `X_Element_K` for `x[K]`, so that an
  expression that needs one is a component, in a value instance, in the condition of a `repeat-until` or elsewhere, and
  costs nothing per use. `Parse` copies the element into the component: one copy per element for `.last`, a test of the
  number per element for each of the others and one copy for it. `T` is as much larger as the elements kept, which is a
  slice for bytes and strings and the record of the element for a structure. A structure that contains the type that has
  the repetition cannot be kept (the record would contain itself). The decision to keep and not to parse again follows a
  measurement of models of this code (`bench/src/rep_use`, `last_get` against `last_kept`): to find the last element by
  walking again costs a second walk for every use (about 118 instructions per element on x86-64 and 112 on a Cortex-M4,
  as much as the parse itself), keeping it costs 3 instructions per element (2 on the Cortex-M4), and a use inside a
  loop, such as `repeat-until: _ == records1.last`, would make the walk grow with the square of the count.
- An element kept has `Valid` (and `Belongs_To`) in the `Valid` and `Belongs_To` of the record if the field has at least
  that many elements; the components are set to their defaults at the start of `Parse`, so the ones that are not reached
  are not left undefined.
- A value instance that is only the name of a repeated field (`value: items`) has no accessor of its own: the accessors of
  the field are its accessors, and `x.first` through it is the same as `items.first`. A value instance that is the first
  or last element of a repetition of structures returns the record, with the postcondition that it is valid.
- An element with a number from `x[_index - 1]` stays rejected as before.

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
| `sizeof<t>`, `_sizeof`, `x._sizeof` | the size in bytes, a constant of the compiler; a begun byte counts as a whole one, and a type or value of dynamic size is an error of the compiler, as in the other targets |

An integer above the largest S64, up to 2**64-1, is not an S64 and takes part in no arithmetic. It is accepted as an
operand of a comparison with an unsigned integer field (`u1` .. `u8`, `bN`) or with another literal, and the
comparison is made in `U64`: `This.Uint64 /= Kaitai.Types.U64 (18446744073709551615)`. The field is not converted to
`S64`, so the comparison needs no condition that it fits, and it is true or false for every value of the field, also
`valid` with `eq`, `min`, `max`, `any-of` and `range`. Compared with a signed value or an expression, such a literal is
rejected. A value instance that is such a literal is a function that returns `U64`; it cannot be used in other
expressions.

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

### Floating-point numbers

An expression with a float is computed in `Kaitai.Floats.F64`, a 64-bit float, whatever the operands were read as. An
`f4` is widened to it (`From_F32`), an integer next to a float is converted to it (`From_S64`: the nearest `F64`, and
the one with the even mantissa if two are equally near, which is what Python and Java do), and the result is an `F64`.
An unsigned 64-bit field above 2**63-1 next to a float makes the expression undefined, because `From_S64` takes an
`S64`; the other targets convert it.
The operations are those of `Kaitai.Float_Arithmetic`:

| In the description | In Ada |
|---|---|
| `1.5`, `-2.7` | `1.5`, `-2.7`; a literal that no `F64` holds (`1.0e400`, `1.0e-400`) is an error of the compiler |
| a field `f4`, `f8` | `From_F32 (To_F32 (This.X))`, `To_F64 (This.X)`, defined if `Floats.Is_Finite (This.X)` |
| `a + b`, `a - b`, `a * b` | `Add (A, B)`, `Subtract (A, B)`, `Multiply (A, B)`, defined if `Add_OK (A, B)`, `Subtract_OK (A, B)`, `Multiply_OK (A, B)` |
| `-a` | `-A` |
| the six comparisons | `=`, `/=`, `<`, `<=`, `>`, `>=` on two `F64`; an integer operand is converted first |
| `c ? a : b` | `(if C then A else B)`; if one branch is an integer it is converted |
| `a.to_i` | `Truncate (A)`, defined if `Truncate_OK (A)`: the places after the point are cut off, so the `to_i` of -2.7 is -2 and that of 1.9 is 1 |
| `a / b`, `a % b`, and `<<`, `&` and the like on a float | rejected |

An expression is defined only if its result is finite. A result that would be infinity, as in `1e200 * 1e200`, makes
the expression undefined, as an integer that does not fit makes one undefined: the function `Has_X` of a value
instance is false, and `Parse` fails with `Arithmetic_Error` where it needs the value. A field that is infinity or
not-a-number is read and kept (the accessor `X_Bits` gives its bits), but an expression that uses it is undefined,
because `X` has the precondition `Is_Finite`; that is why every use of a float field adds `Is_Finite (This.X)` to the
condition. Underflow is not an error: a result too small for a normal number is a denormal number or zero. There is
no division, and so no division by zero: the quotient of two floats is finite only under a condition that GNATprove
does not prove at level 1 with a margin that a loaded machine can rely on (a first version of it was proven only when the machine was idle), so `/` of floats is rejected with a message that says so.

The compiler asks `Add_OK`, `Multiply_OK` and `Truncate_OK` only where the sizes that it knows do not answer. It tracks
an upper bound of the magnitude of every part of an expression: a literal is its own bound, an `f4` is at most
3.4028234663852886E+38, an integer at most 2**63, an `f8` is only known to be finite, and the bound of a sum or a product
follows from those of its operands. A sum is not asked about if both operands are at most 2**1022 in magnitude, a product if
one operand is at most 1 or both are at most 2**200, a `to_i` if the number is below 2**63. So `celsius + 273.15` and
`(celsius + 0.5) * fraction - 2.0` with `f4` fields ask nothing but `Is_Finite`, while
`gain * gain` with an `f8` field asks `Multiply_OK`:

```ada
function Has_Blend (This : T) return Boolean
is (Kaitai.Floats.Is_Finite (This.Celsius) and then Kaitai.Floats.Is_Finite (This.Fraction));

function Has_Gain_Squared (This : T) return Boolean
is (Kaitai.Floats.Is_Finite (This.Gain)
    and then Kaitai.Float_Arithmetic.Multiply_OK (Kaitai.Floats.To_F64 (This.Gain), Kaitai.Floats.To_F64 (This.Gain)));
```

(This is `examples/float_reading`.) The prover shows the questions that are left out from the types alone: `From_F32` and
`From_S64` return subtypes with the bounds above, and `Add`, `Multiply` have `L op R` as their postcondition. The
`_OK` functions are stricter than the exact condition for operands of immense magnitude, because the exact conditions
are not proven at level 1; `Kaitai.Float_Arithmetic` says for each where. They accept every operation whose operands are
at most 2**500 (about 3.3E150) in magnitude. An operation that has an operand above that may be refused although its
result is finite, for example `1E160 * 1E150`, or a sum of two numbers of the same sign of which one is above 2**1022
(about 4.5E307).

An expression with more than eight operations on floats (`+`, `-`, `*`, `to_i`; the value instances that it uses
count, they are written into it) is rejected with a message that says so (`compiler/rejected/float_long_chain.ksy`). The
translation of a chain of operations grows with the square of their number, because every question that is asked
repeats the operations below it, and the proof grows with it: at `--level=1`, in one run for each length, a sum of `f4`
fields with 7 operations was proved and one with 11 was not (4 checks), a product of `f4` fields with 15 operations
was proved and one with 23 was not (5 checks), and sums and products of `f8` fields, where every operation is asked
about, were proved up to 23; a chain of 31 `f4` in a condition gives a line that is longer than the compiler of Ada takes (32766
characters). A product of eight `f4` fields was not proved in two runs (3 checks) while products were not asked about
below 2**500; with the limit at 2**200, so that from the third factor on each product is asked about, products of up to
15 operations were.

A `valid` on a float field compares as the other targets do, also for the values that expressions cannot use. A
not-a-number is not at least and not at most anything, so it fails `min` and `max` (`Validation_Less_Than` if `min` or
`range` comes first, else `Validation_Greater_Than`); plus infinity fails `max`, minus infinity fails `min`; `eq` and
`any-of` fail for every infinity and not-a-number. `valid: expr` is an expression like the others: a float that is not
finite makes it undefined, and `Parse` fails with `Arithmetic_Error`. The comparison with the limits is in `F64`, and
it is made by a function of its own (see "Float steps of a procedure" below):

```ada
function Eval_Fraction_Min (This : T) return Boolean is
begin
   return
     (if not Kaitai.Floats.Is_Finite (This.Fraction) then This.Fraction /= 16#7F80_0000#
      else Kaitai.Float_Arithmetic.From_F32 (Kaitai.Floats.To_F32 (This.Fraction)) < 0.0);
end Eval_Fraction_Min;
```

It tells whether the check fails, and `Parse` fails with `Validation_Less_Than` if it does.

A value instance of float type is a function that returns `Kaitai.Floats.F64` (`Has_X` as for integers). The type
of an instance in the description is not looked at: `f4` or `f8`, the result is an `F64`. A float is not an argument
of a type, a parameter, or the value of a nested instance (`child.x` of a float instance); those are rejected. Floats
are written by `--read-write` as before, as their bits; instances are not written.

### Float steps of a procedure

An expression with a float that a procedure evaluates is not written into the procedure. This holds for every place
where a procedure with a stream contract evaluates an expression: `if`, `size`, `repeat-expr`, `repeat-until`, `valid`
(the limits and `expr`), `pos`, `switch-on`, the arguments of a type and the byte order of a calculated endianness,
in `Parse`, in the procedure that parses one element of a cursor, in the procedures of instances with a position and in
`Write`. Each such expression, a "float step", is a subprogram of its own in the body of the package, declared before
`Parse` with `Global => null` and without a postcondition. If the expression is defined only under conditions (the
`Is_Finite` and `_OK` questions above) the subprogram is a procedure that tells whether the expression is defined and
what its value is, and the procedure that evaluates it branches on the two:

```ada
procedure Eval_Label_Size
  (This : T; Eval_Defined : out Boolean; Eval_Result : out Kaitai.Types.S64)
with Global => null;

...
Eval_Label_Size (This, Eval_Defined, Eval_Value);
if Eval_Defined then
   Kaitai.Streams.Read_Bytes (S, Kaitai.Types.To_Size (Eval_Value), This.Label);
else
   Kaitai.Streams.Fail (S, Kaitai.Types.Arithmetic_Error);
end if;
```

(This is `examples/float_steps`.) If the expression has no such condition, as the limits of `valid` on a float field, the
subprogram is a function that returns the value. The three variables are declared once in each procedure and shared by
its steps, which is what the prover takes best. The element of a repetition of a type that `_` stands for is a
parameter `Item`, with the precondition that it is valid, and `_index` is a parameter `Index`.

For `Parse` a call of such a subprogram is a call of a subprogram without a contract, whose results can be anything,
so the bit and float operations of the step are not in the context of the checks that follow, and GNATprove proves the
subprogram of each step by itself, with one to five checks. A float expression that is written into `Parse` is in the
context of every later check, and at `--level=1`, where each prover has a second for a check, the provers reach their
time limit on checks that have nothing to do with floats (`Kaitai.Streams.Is_Valid (S, Buffer)` in the postcondition,
the precondition of the next `Read_...`). Checks that were not proved in each of three runs without the cache, on
descriptions with `if`, `size`, `repeat-expr`, `valid: expr` and `repeat-until` in turn, the float steps written into
`Parse` and as subprograms:

| Float steps in `Parse` | written into `Parse` | subprograms |
|---|---|---|
| 4 | 0, 0, 0 | 0, 0, 0 |
| 4, of other kinds (`repeat-until`, `valid: expr`, `size`, `if`) | 2, 2, 2 | 0, 0, 0 |
| 8 | 6, 6, 7 | 0, 0, 0 |
| 16 | 33, 32, 32 | 4, 2, 2 |

The 16 steps are more than a `Parse` of this kind proves at all: the same description with integers instead of floats
(`u4` for `f4`, `l * 2` for `(l * 2.0).to_i`, every step inline, no floats) has 3, 3, 3 checks that are not proved, so
it is the size of `Parse` that sets the limit there, not the floats. The example `float_steps` has nine steps in one
`Parse` and proves completely in each of three runs.

What a step costs in executed instructions, per `Parse` (x86-64 under Valgrind, `-O2 -gnatn`, checks left out; Cortex-M4
`light-stm32f4`, same switches, in Renode), with the expressions written into `Parse` and as subprograms:

| `Parse` of | x86-64 | Cortex-M4 |
|---|---|---|
| 4 steps of other kinds (see above) | 396, 400 | 1280.1, 1280.1 |
| 8 steps, five kinds in turn | 718, 715 | 4189.1, 4195.1 |
| `float_steps` (9 steps) | 659, 674 | 3684.1, 3695.1 |

The compiler inlines the subprograms (they are not in the executable). Two shapes that were measured and not taken: two
functions, one for the condition and one for the value, which evaluate the condition twice (`float_steps` with three steps more: 811 instructions written into `Parse`, 915 with the functions, and 4040.1 and 4603.1 on
the Cortex-M4); and a function
that returns a record of both, which is returned in memory (the four steps of other kinds: 396 and 530, 1280.1 and 2266.0). A variable for each
step instead of the three shared ones was not taken either: `float_steps` with three steps more was not proved
with it in three runs, and was with the three shared variables in two of three.

The names are `Eval_`, the field and the kind of the step (`If`, `Size`, `Count`, `Until`, `Min`, `Max`, `Valid`,
`Pos`, `On`, `Order`, `Arg`), numbered if there are several; the description cannot have a field whose name begins with
`Eval_` (it becomes `Eval_X_Field`). They are in the body and not in the interface. An expression that is the same in
`Parse` and in `Write` has one subprogram.

An expression stays where it is if it uses the buffer (an element of a repetition of floats, `samples[0]`), the stream
(`_io.pos`) or a variable of the procedure other than `_` and `_index` of the loop that is being parsed, and so does
the expression of a value instance (`Has_X`, `X`), which is an expression function.

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
procedure First_Entry (This : T; Buffer : Bytes; Result : out Entry_Type.T; Outcome : out Status_Kind)
with
  Pre  => Valid (This) and then Belongs_To (This, Buffer),
  Post => Entry_Type.Valid (Result) = (Outcome = Success) and then Entry_Type.Belongs_To (Result, Buffer);
```

Asking twice parses twice. The caller keeps the result if it needs it again.
`io: _root._io` is a stream over the whole buffer, `Open (Buffer)`.

### An instance that an expression of the `seq` needs

An instance with a position that an expression of the `seq` needs (a `size`, a
`repeat-expr`, a `repeat-until`, an `if`, a `valid`, a `switch-on`, an argument
of a type, a value instance that uses it, another such instance) is not a
procedure. `Parse` reads it once, at the place where an expression first needs
it, and keeps it in `T`, as the other targets do, where the expression is what
triggers the read. Its accessor is a function that returns the kept value:

```ada
function Header (This : T) return Header_Obj_Type.T
with Pre => Valid (This), Post => Header_Obj_Type.Valid (Header'Result);
```

The value is read from a copy of the stream, so that `Parse` stays where it
was, and the copy is joined to the stream afterwards (`Kaitai.Streams.Join`):
if the instance cannot be read, or its `valid` does not hold, the stream fails
with that reason, and `Parse` fails. `Valid (This)` includes the validity of
the kept value, and `Belongs_To` what it refers to.

- `_io.pos` and `_io.eof` in the expressions of such an instance are the
  position and end of the stream at the place of the first use, as in the other
  targets: for `pos: _io.pos + 12` in the `repeat-until` of a field, the
  position after the first element. (In an instance that no expression of the
  `seq` needs they stay rejected, since the accessor would have to guess where
  the stream is when it is first asked.)
- The first use comes before the field is read (in `if`, `size`, `repeat-expr`,
  arguments, `switch-on`), after the first element (`repeat-until`) or after
  the field (`valid`). An instance that the `if` of a field first needs is read
  before the condition is evaluated.
- An instance whose position does not depend on `_io.pos` or `_io.eof` and that
  is first needed by a `repeat-until` or a `valid` is read before the loop, or
  before the check. That differs from the other targets only if two things fail
  in one input, the field and the instance: they report the field, `Parse`
  reports the instance. An instance that does depend on them and is first
  needed by a `repeat-until` is read inside the loop, in the first turn, and
  `T` has a component `Has_X` that tells that it has been read: one test per
  turn.
- The accessor is a function, so every kept instance must be read on every way
  through `Parse`. An instance whose first use is where it may not be
  evaluated (an expression of a field that has an `if`, of each element of a
  repetition, or in some case of a `switch-on`) is rejected with a message that
  says so, unless an earlier use certainly reads it; so is an instance that
  needs a field that is read at the same place or after its first use, one with
  `if`, `repeat`, `process`, a float, or an `io` other than `_root._io`, and one
  whose `valid` or `pos` needs `_io.pos` where it would be taken after the field.
- A value instance that uses a kept instance is an expression function of the
  kept values, and can be used in `Parse`.
- `Write` does not write instances with a position, so a description whose
  `seq` needs one is rejected with `--read-write`: what was written would not
  agree with the count, size or condition that was computed from the instance.

Cost: one read of the instance per `Parse`, and a copy of the stream (a few
words) for it; in the loop a test of `Has_X` per element. Measured with
hand-written models of the generated code (`bench/src/bench_inst_*_d2`): a
header that is needed by a count and an end condition is 54 % (x86-64) and 61 %
(Cortex-M4) cheaper per record than parsing it at every use, and the accessor
costs 0 to 3 instructions instead of 70 to 96. `T` grows by the kept value:
4 to 32 bytes in the models.

## Parameters

The parameters of a type that are integers, booleans or enumerations are
parameters of its `Parse`, after the stream, and are kept in
`T`, where instances and repetitions find them again. Each has an accessor.

A parameter of another type (a string, bytes, a user type, an array, a
stream) is not a parameter of `Parse`. The type gets what it uses of the
value as a value from outside, as described in the next section: a parameter
`hdr` of a user type that the type uses as `hdr.width` becomes the integer
`Hdr_Width`, which the caller computes from the argument it gives for `hdr`.
A parameter that the type uses as a whole value is rejected with an error
that names it, as long as no rule below keeps it.

## Processing

A field with `process` is kept as the bytes that are in the input. The
processing is undone when the field is asked for, into an array of the
caller, since a parser has no memory of its own:

```ada
function Secret_Raw (This : T) return Slice
with Pre => Valid (This);

procedure Secret (This : T; Buffer : Bytes; Target : in out Bytes; Last : out Length; Outcome : out Status_Kind);

procedure Packed
  (This : T; Buffer : Bytes; Storage : in out Bytes; Result : out Inner_Type.T; Outcome : out Status_Kind);
```

`Secret` is for a byte array: the result is `Target (Target'First .. Last)`.
`Packed` is for a field of a type: the bytes are processed into `Storage`
and the value is parsed from there, so that what it refers to lies in
`Storage`. Both report `Capacity_Exceeded` if the array is too small. The
bytes that `Secret_Raw` delivers are those after `terminator` and `pad-right`
were applied, as in the other targets.

| In the description | In the accessor |
|---|---|
| `xor(k)` with an integer | `Processing.Xor_One`; a key outside 0 .. 255 gives `Arithmetic_Error` |
| `xor(k)` with bytes, a field or a literal | `Processing.Xor_Many`, the key taken from `Buffer`; an empty key gives `Arithmetic_Error` |
| `rol(n)` | `Processing.Rotate_Left (…, n)` |
| `ror(n)` | `Processing.Rotate_Left (…, 8 - n)` |
| `zlib` | `Zlib.Inflate`; `Target_Full` is `Capacity_Exceeded`, `Corrupt` is `Illegal_Sequence` |

A value inside processed bytes is therefore parsed only when it is asked
for, and an error in it shows only then. `Parse` cannot use such a value;
the compiler rejects a description in which an expression, a `valid`, a
`switch-on` or another field depends on one. A process of a string, of a
repeated field, of a field whose type depends on a value, and of a parse
instance are rejected.

One thing of a processed value an expression may use: a byte, `x[i]` of bytes
with `xor` or `rol`/`ror`. These work byte by byte, so the byte `i` is computed
from the byte `i` of the input (`Processing.Xor_Byte`, `Xor_Many_Byte`,
`Rotate_Byte`), in a constant number of instructions and without memory.
The index is checked against the size of the bytes and an integer key against
0 .. 255: outside of them the expression is undefined. The amount of a rotation
is taken modulo 8, as the accessor of the field takes it.
A value instance that is such a byte is an ordinary function; where Python
fails at `Parse` because the key is invalid, the instance is undefined here.
`zlib` and a custom process are rejected, as is every other use: the whole
processed value is an array that a parser does not have (`x == y`, `x.size`
of the processed bytes and the like, and the choice between a processed and an
unprocessed field, `c ? plain : processed`, which would be a value that is
the one or the other).

A custom process (`process: my_custom_fx(key, true)`) is undone by code that
is not generated; see "Foreign code". Its accessor has the same form as that
of `zlib`.

`examples/extras` shows this and the next two sections.

## Foreign code

Two constructs of Kaitai Struct call code that the description does not
contain: an opaque type (`meta: ks-opaque-types: true` and a `type:` that no
description defines) and a custom `process`. The compiler generates the
calls. What they call is a package that the user writes by hand, and a
contract says what it must provide. The generated code is proven against the
specification of that package, which therefore has to be in SPARK. Its body
may be in Ada that is not SPARK (`SPARK_Mode => Off`, the heap, exceptions
inside); then GNATprove takes the specification on trust, and the body must
keep it: it terminates, it changes nothing but its parameters, no exception
leaves it, and everything that goes wrong is reported in the way the
specification says. `compiler/foreign/` has the packages for the custom
processes of the tests of Kaitai Struct, `examples/foreign` an opaque type
and two custom processes whose bodies are proven too.

The unit name follows the rule of "Names": every word of the name of the
description is capitalised.

| In the description | Package |
|---|---|
| `type: foo_bar` or `type: foo_bar(1, x)`, not defined | `Foo_Bar`, the package that a description `foo_bar` has |
| `process: my_custom_fx(...)` | `My_Custom_Fx` |
| `process: nested.deeply.custom_fx(...)` | `Nested.Deeply.Custom_Fx`, a child of `Nested.Deeply`, which is a child of `Nested`; both parents have to exist, and may be empty |

A name is rejected, with the path of the attribute, where it is a reserved
word of Ada or a name that the generated code uses (the list under "Names"),
the name of a package of the library (`Types`, `Streams`, ...), or the name of
a description of the compilation, and for an opaque type where it has `::`.
The first name of such a package is also kept from the members of the
description, like the packages of imported descriptions: a field `acme` next
to `process: acme.scramble` is `Acme_Field`. The unit has a `with` clause for
each package.

### Opaque types

A type that no description defines is opaque if `meta: ks-opaque-types: true`
or the compiler option `--opaque-types=true` is given; otherwise the compiler
reports the type as unknown. This is how the tests of Kaitai Struct use
another description, `hello_world`, without importing it. The package of an
opaque type provides at least this:

```ada
with Kaitai.Streams;
with Kaitai.Types;

package Foo_Bar
  with SPARK_Mode, Always_Terminates
is
   --  A value of the type. Its objects are initialised by default, it can be
   --  copied and needs no clean-up: a private type whose full view is a
   --  record with default values.
   type T is private;

   --  True if This is the result of a Parse that succeeded
   function Valid (This : T) return Boolean
   with Global => null;

   --  Parse one value at the position of S. The result comes first, as in every
   --  generated parser. The parameters after S are the
   --  arguments of the description, one for each, in their order: an integer is
   --  a Kaitai.Types.S64, a boolean a Boolean. There are none for a type that is
   --  written without arguments.
   procedure Parse (This : out T; Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Len : Kaitai.Types.S64)
   with
     Global => null,
     Pre    => Kaitai.Streams.Is_Valid (S, Buffer),
     Post   =>
       Kaitai.Streams.Is_Valid (S, Buffer)
       and then Kaitai.Streams.Advanced (S'Old, S)
       and then Valid (This) = Kaitai.Streams.OK (S);

   --  ... whatever the package offers to read a value
private
   type T is record
      Is_Valid : Boolean := False;
      ...
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);
end Foo_Bar;
```

What the generated code does with it:

- A field `hw` of the type has a component `Hw : Hello_World.T`, and the
  accessor `function Hw (This : T) return Hello_World.T` with the
  postcondition `Hello_World.Valid (Hw'Result)`. `Valid` of the type that has
  the field includes `Hello_World.Valid (This.Hw)`. `Parse` calls
  `Hello_World.Parse (This.Hw, Buffer, S[, arguments])` where the field is read,
  or with a substream (`size`, `terminator`, `process`) as for any type. A
  repetition of the type, a case of a `switch-on` and a parse instance work the
  same way. What the postcondition says about the stream is all that the
  generated `Parse` knows afterwards; it proves its own postcondition from it.
  A foreign `Parse` may read nothing at all; a loop over elements ends as it does
  for a generated type that may read nothing. It is also called with a stream
  that has failed, as the generated `Parse` is, and then leaves `This` not
  valid, as the postcondition says; the reading operations of `Kaitai.Streams`
  do nothing on a failed stream, so a body made of them does that by itself.
- The arguments are exactly those of the description. An integer is passed as
  a `Kaitai.Types.S64`, the type in which expressions are computed, and a
  boolean as a `Boolean`. An enumeration, a string, bytes, a type or a stream
  as an argument is rejected. The foreign `Parse` must accept every
  value; a value it cannot use is a failure of the stream (`Fail (S,
  Kaitai.Types.Arithmetic_Error)` and the like), not a precondition. A literal
  also fits a parameter of a narrower type, so that the parser generated from
  `params_def` (`len: u4`) serves for `params_def(5, true)`; an argument that is
  not a literal does not.
- Nothing else is passed: no byte order (`Order`), no `Parent_X`, no
  `Root_X`, no `Depth`. What the foreign type needs from the parent or the
  root is an argument of the type: `type: foo_bar(_parent.len)`.
- `Parse` may be called with the stream in the middle of a byte, behind bit
  fields that the field before left open; the generated parsers of types
  that start with bit fields continue in that byte. The foreign `Parse` has
  no precondition but `Is_Valid (S, Buffer)`, and takes the bits as it finds
  them. A parser that this compiler generated for a type that starts with bit
  fields has `Bits_Left (S) = 0` as a further precondition (see Fields) and so
  does not keep the contract.
- The contract has no `Belongs_To`. The type that holds a foreign value has it
  without the foreign part: `Belongs_To (This, Buffer)` says nothing of
  `This.Hw`, and the compiler cannot know whether the foreign type has such a
  function (a generated parser has it only if it holds a slice, which `hello_world`
  does not). A foreign type that refers to the buffer must be used with the
  buffer it was parsed from, and has to check what it reads. A foreign package
  may declare `Belongs_To`, but a generated unit never uses it.
- A description with an opaque type is rejected under `--read-write`: the
  contract has no `Write`.

A parser that this compiler generated from a description `foo_bar` keeps the
contract without a change if its `Parse` takes the result, the buffer, the
stream and the arguments and nothing else, and has no precondition but `Is_Valid (S, Buffer)`: no
`Order`, `Parent_X`, `Root_X` or `Depth` parameter, no start with bit fields,
and for each parameter of the description either an `s8`, a `bool`, or a
literal at every use. `hello_world` and `opaque_external_type_02_child` do, and
`params_def` for literal arguments; this is how the tests use them (the
tests repository has them as parsers that are simply not imported). Where one
does not, the user generates it under another `id` and writes the package
`Foo_Bar` that has the specification above and calls it, converting the
arguments or aligning the stream first.

### Custom `process`

`process: my_custom_fx(7, true, [0x20, 0x30])` is the call of a procedure
`Decode` in the package `My_Custom_Fx` from the accessor of the field (see
Processing). The package provides this:

```ada
with Kaitai.Types;

package My_Custom_Fx
  with SPARK_Mode, Always_Terminates
is
   use type Kaitai.Types.Length;
   use type Kaitai.Types.Status_Kind;

   --  The decoded bytes of Source, written to Target from Target'First
   procedure Decode
     (Source  : Kaitai.Types.Bytes;
      Key     : Kaitai.Types.S64;
      Flag    : Boolean;
      Mask    : Kaitai.Types.Bytes;
      Target  : in out Kaitai.Types.Bytes;
      Last    : out Kaitai.Types.Length;
      Outcome : out Kaitai.Types.Status_Kind)
   with
     Global => null,
     Pre    => Target'First >= 1,
     Post   =>
       Last >= Target'First - 1
       and then Last - (Target'First - 1) <= Kaitai.Types.Length (Target'Length)
       and then (if Outcome /= Kaitai.Types.Success then Last = Target'First - 1);
end My_Custom_Fx;
```

- `Source` is the bytes of the field as `X_Raw` delivers them (after
  `terminator` and `pad-right`), as a slice of the buffer: its first index is
  not 1, and it may be empty, in which case `Decode` is called all the same,
  since a process may make bytes of none. `Target'First` is at least 1 and
  otherwise any index, and `Target` may be empty.
- The arguments of the process follow `Source` in the order of the
  description, as for an opaque type: an integer is a `Kaitai.Types.S64`, a
  boolean a `Boolean`, and bytes (an array literal or a field of bytes) are a
  `Kaitai.Types.Bytes`. A string, an enumeration or another kind of value is
  rejected, so is an argument that uses `_io`. A process without arguments
  (`process: custom_fx_no_args`) has none, and no parentheses.
- If `Outcome` is `Success`, `Target (Target'First .. Last)` is the result,
  empty if `Last = Target'First - 1`; its length is up to the package, and
  `Last` stays within `Target`. If it is anything else, `Last = Target'First - 1`
  and the content of `Target` is not used. `Decode` reports a result that does
  not fit as `Capacity_Exceeded`, an argument or data that it cannot use with
  the status that fits (`Arithmetic_Error`, `Illegal_Sequence`); an exception
  must not leave it. The accessor of a field of bytes passes `Outcome` on. The
  accessor of a field of a type parses the result if `Outcome` is `Success` and
  reports the status of that parse; otherwise it reports `Outcome` and the value
  is not valid.
- The compiler checks the arguments that are not defined (an overflow in an
  expression): `Decode` is not called then and `Outcome` is `Arithmetic_Error`.
- `Write` does not call the package. It writes the bytes of the input, as
  for `xor` and `zlib` (see Writing), so there is no `Encode` and the
  process need not have an inverse.
- The process of a string, of a repeated field, of a field whose type depends
  on a value and of a parse instance are rejected as for the built-in
  processes, as is a field whose value an expression needs.

`examples/foreign` is a description that uses an opaque type, a custom process with arguments and
one without, for a field of bytes and for a field of a type, with the packages
written for it.

## Types that contain themselves

`Parse` of such a type has a parameter `Depth`, the number of levels of
nesting that are accepted below the value. It comes after the parameters of
the description and the references to the parent and the root. It is passed
on reduced by one, and at zero the stream fails with `Limit_Exceeded`.
`Depth` is what proves that the recursion ends:

```ada
procedure Parse (This : out T; Buffer : Bytes; S : in out Stream; Depth : Natural)
with ..., Subprogram_Variant => (Decreases => Depth, Decreases => 1);
```

The procedure that parses one element has the variant
`(Decreases => This.Depth, Decreases => 0)`, so that the call from `Parse`
to it counts as a step down as well. Where the type is used from outside,
`Depth` is the constant `Max_Depth` of the library-level package, 8 unless
the compiler is told otherwise with `--ada-max-depth N`.

Every level takes room on the stack, and the proof does not cover the size
of the stack. Measured for `examples/extras` on a Cortex-M4 with run-time
checks: 232 bytes per level. A light run-time library gives the main program
4 KiB and does not notice when they are used up; with 32 levels the tests
overwrote other memory on the simulated STM32F4. The default of 8 stays
well within that stack. `-fstack-usage` tells what a level costs for a
given type.

A field of its own type is not held in `T`, which Ada does not allow. Like a
repetition it is parsed again when asked for: `T` keeps the stream as it was
before the field, and a procedure `X (This, Buffer, Result, Outcome)` parses
it, like the accessor of a parse instance. A type that contains itself only
through a repetition needs nothing more, since repetitions are not held
either.

Types that contain each other, a field whose type depends on a value and
can be the type itself, and a `valid` on a field of its own type are
rejected.

## References to the parent and the root

A value has no reference to the value it is part of. Where a type uses
`_parent.x` or `_root.x.y`, the value of that expression becomes a parameter
of its `Parse`, named `Parent_X` or `Root_X_Y`, after the parameters of the
description. It is kept in `T` like those and has no accessor. `_parent.
_parent.x` is `Parent_Parent_X`. Only integers, booleans and enumerations are
passed, so the type gets the largest part of an expression that it needs
and that depends only on values from outside. A chain that ends in such a
value is that value: `_parent.hdr.width`, a member of a parameter of a user type
(`hdr.width`), the length of a string (`_parent.name.length`, `key.length`),
the `size` of a repetition or of a stream (`_parent._io.size`). An expression
with a string, a user type or the like in it that has an integer, a boolean
or an enumeration as its value (`_parent.s1 == "foo"`) is passed as a whole,
computed by the caller, and is named after its first chain (`Parent_S1_Expr`).
Where an expression only calculates with integers (`_parent.x + 1`), the
parts are passed, as before.

The parser of the parent passes the value, computed from its own field, or
value instance with its guards, at every place where it calls the parser: in
`Parse`, in the procedures that parse one element, and in the accessors of
parse instances. A type that needs `_parent._parent.x` and `_root.x` of a
type it uses, gets the parameters `Parent_X` and `Root_X` itself and hands
them on. The top-level type of a description has `_root` as itself: `_root.x`
is its field `x`.

The caller reads the expression as its own: `_parent.x` is its `x`, a parameter
of the callee is the argument that the caller gives. It computes the value
before the call, with its guards, so an expression that is not defined there
(a division by zero, a field with an `if` that does not hold) fails the stream
with `Arithmetic_Error` at the call, also if the callee would not have used it.

A cast of an outside value (`_parent._parent.as<foo>.flag`, `hw_param.as<hello_world>.one` for a
parameter of type `struct`) names the type of the value and nothing else: the
caller reads the value as its own, and its own type decides what the member is.
A cast of a value that is passed as a whole is rejected, as is any other value
of a user type that a type needs as a whole.

The key `parent` on a field gives the value of `_parent` for the type of the
field: the caller reads `_parent.x` of the callee as `E.x`, where `E` is the
expression of the key, written in the caller. `parent: false` gives the type no
parent, so a type that uses `_parent` is rejected on such a field.

A stream from outside is used by its `size`: `arg.size` of a parameter of type
`io`, `first._io.size` (the size that the field `first` was cut with, or the size of
the stream of the caller if it is not cut) and `_root._io.size`. An argument
that chooses between streams is chosen from by the caller
(`(c ? first._io : _root._io).size` is `c ? first._io.size : _root._io.size`), and
an element of a list that is given as an argument is read at compile time
(`[first._io, _root._io][0]`). `.pos` and `.eof` of such a stream, and the stream
as a whole (`io:` of a parse instance), are rejected: the stream of the parent
is at another position when the child is read.

The value is taken when the parser of the parent calls. A reference to a
field that is parsed later than the field with the call, to a parse instance,
or to a type that is not passed by value is rejected by the compiler. So is
`_parent` in the top-level type of a description, which has no parent.
`_root` means the top-level type of the description in which the type is
written; a type of another description that uses `_root` is rejected. So is
`_root.x` in a description whose top-level type contains itself: for the
nested value it would have to be the field of the outermost value, which the
nested value does not know.
The key `parent` is rejected on a field whose type calculates its byte order
from `_parent` (see "Rules of the compiler").

## Documentation

A user can tell from the comments alone how to use `Parse` and everything else
in a specification: the compiler writes a comment for every declaration of the
visible part and carries over `doc`, `doc-ref` and `meta/title` of the
description. Private parts and bodies have no generated comments. `examples/showcase`
shows where each text of its description ends up.

- Where. A comment is a block of lines `--  text` directly before the
  declaration it describes, indented like it and without a blank line between;
  a blank line comes before the block. `gnatdoc --style=leading` reads these
  blocks as the documentation of the entities. The block of the library-level
  package is the first thing after its `is`. GNATdoc looks there before it
  takes a comment at the top of the file; with the block at the top it took
  the comment of the first declaration after the `use type` clauses for that
  of the package. The file itself begins with the line
  `Generated by the Kaitai Struct compiler from x.ksy.  Do not edit.`.
  The block of a nested package stands before its `package` line. A line has
  at most 120 columns with its indentation, which the style checks of the
  tests ask for; an empty line in a block is `--`.
- From the description. `meta/title`, `doc` and `doc-ref` of the top-level type
  are in the block of the library-level package, after the line "Parser for
  `x`: title" and before the call of `Parse` that the block shows. `doc` and
  `doc-ref` of a nested type are in the block of its package; `doc` and
  `doc-ref` of a field, a parameter or an instance are in the comment of the
  accessor that delivers it, after a phrase that says what it is ("Field
  `code`, an unsigned integer of 1 byte"). Where accessors come in a pair
  (`X_Value` and `X` of an enumeration, `X_Bits` and `X` of a float) the text
  is with the one that a caller wants, `X`; for a field that depends on a value
  it is with `X_Case`; of a repetition it is with the accessor of the elements,
  or with `X_Count` if the elements are walked with a cursor. `doc` of a value
  of an enumeration follows its `@enum` line; Kaitai Struct has no `doc` for an
  enumeration as a whole. A text is taken as it is: paragraphs are kept and
  lines are wrapped again, tabs and other control characters become blanks, and
  a word that is longer than a line is cut, so that nothing a description says
  can end the comment or break the source. Each `doc-ref` follows as
  `See <ref>` on a line of its own.
- What is generated. Every other declaration has a text that the compiler
  writes: what `T`, `Valid`, `Belongs_To` and `Parse` are, what `Parse` does
  when the data are not accepted and what it leaves in the stream, which
  fields it does not keep (cursors, a field of the own type) or does not
  read (instances with a position, processed fields), the byte boundary that
  some types need, what each parameter of `Parse` is (the parameters of the
  description, `Order`, `Parent_X`, `Root_X`, `Depth`); what the accessors
  deliver and what their preconditions mean (`Has_X`, `Requires ...`); how a
  field is read from the buffer (the slice that holds it, with its terminator
  and padding, the encoding that was checked); the loop over a cursor; what
  the caller of an instance, a processed field or `Write` has to provide
  (`Target`, `Storage`) and what `Outcome` and `Last` say; and what `Write`
  guarantees. Such a statement is made only for the variants of generated code
  that it is true for: `Belongs_To` is mentioned only where it exists, and
  that bytes behind the value are not an error only for the top-level type.
- Names. A name of the description is in backquotes with its spelling there
  (`num_entries`, `showcase::entry`); a name in Ada is written as it is
  (`Valid`, `Entries_First`).
- Tags. GNATdoc tags are used in two places and nowhere else: `@param Name text`
  for every parameter of every generated procedure of a visible part (`Parse`,
  `Write`, `Next`, `Get_X`, the accessors that are procedures), and
  `@enum Literal text` for every literal of every enumeration type of a visible
  part (the enumerations of the description and the types `X_Kind` of the fields
  that depend on a value). A function describes its parameters in prose and has
  no `@param` and no `@return`.
- Style. Comments are in the style of the library: a phrase has no full
  stop, a comment of several sentences has one after each, with one blank.

With `gnatdoc --warnings --style=leading` on `examples/` no entity, no
enumeration literal and no parameter of a procedure of a visible part is
reported as not documented.

## Rules of the compiler

Where the rules above are silent, the compiler does the following.

- `This := (others => <>);` is the first statement of `Parse` if some
  component may stay unassigned on a path (a field with `if`, a switch
  without `else`, a failed condition of an expression, a repetition whose
  count is guarded) or if `This` is handed on as a whole (the element
  procedure of a repetition takes it). Otherwise there is none; in
  particular a `valid` whose test is guarded (an arithmetic question, the
  conversion of a bit field) does not need it, as all it does is fail the
  stream and every component is assigned as before. A type
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
  and all labels are literals, and an `if` chain for strings and for bytes: `Byte_Arrays.Equal (Buffer, X, (16#49#))` compares
  with a case that is a byte array. A switch that has only the `_` case does not compare anything; the expression is
  still evaluated, and the stream fails with `Arithmetic_Error` where it is not defined.
- A repetition of integers or floats of a fixed size is one slice. `repeat:
  until` reads the elements one by one and takes the slice with `Between`;
  its `Valid` does not state that the size is a multiple of the element
  size. A repetition of anything else is walked with a cursor.
- A value instance with a guard is a pair `Has_X`/`X`. Value instances of
  the same type that an expression uses are inserted into the expression, so
  they can be used in `Parse`. A value instance that needs the buffer (a
  string length, a comparison of bytes) takes `Buffer` after `This`, and its
  precondition adds `Belongs_To (This, Buffer)`. A value instance of an
  enumeration has `X_Value` and `X`.
- A parse instance without `io` reads from `This.Io`; with `io: _root._io`
  from `Open (Buffer)`. `pos` is required. An instance with `if` has `Has_X`.
  The result is an `out` parameter of the type of the value; the postcondition
  says `Within (Result, Buffer)` for a slice. A parse instance that an
  expression of the `seq` needs is read once by `Parse` and kept, and `T` has no
  `Io` for it; see "An instance that an expression of the `seq` needs".
- An expression of a repeated field, `_index`, `_parent._io`, floats, string operations other than comparison with a
  literal or another string, `.length` and `.to_i` are
  supported only as the translator lists in `compiler/README.md`; whatever is
  not supported is a compile error with the path of the attribute.
- The argument of a type is passed without conversion when it is a field of
  the same type as the parameter. Otherwise it is converted, and a value
  outside the range of the parameter makes the stream fail with
  `Arithmetic_Error`.
- A string in `ASCII`, `UTF-8`, `UTF-16LE` or `UTF-16BE` is checked; every
  other encoding that Kaitai Struct knows is `Single_Byte`, which accepts
  everything. A name that it does not know is rejected, so that a misspelt
  encoding is not taken for one that accepts everything. The encodings
  `UTF-16` without byte order, `UTF-32` and the like are rejected.
- Strings are compared (`==`, `!=`, also a `switch-on` and `valid`) with a literal or with each other byte by byte.
  That is the comparison of the characters because the parser has checked that the string is valid in its encoding and
  a string has one encoding. A literal of printable ASCII is compared with `Strings.Equal_Literal`. Any other literal
  is encoded by the compiler into the bytes of the encoding of the string it is compared with, and compared with
  `Byte_Arrays.Equal (Buffer, X, (16#C2#, 16#A3#))`. The compiler encodes ASCII, UTF-8, ISO-8859-1, UTF-16LE and
  UTF-16BE (a character beyond U+FFFF as a surrogate pair); in any other encoding it encodes the ASCII characters and
  rejects a literal with any other character. A character that the encoding cannot hold (an accented letter in an
  ASCII string) is rejected as well, and so is a literal that is not valid text. Two strings are compared if they are
  in the same encoding, or both in ASCII or UTF-8. The ordering `<`, `<=`, `>`, `>=` of strings (also `valid` with `min`
  and `max`) is `Byte_Arrays.Compare (…) = Less` and the like, for strings in ASCII, UTF-8 and ISO-8859-1, where the order of
  the bytes is the order of the code points; for other encodings it is rejected. `to_i` of a string in
  UTF-16 and the comparison of strings in different encodings are rejected, as is `.length` of a string in Shift_JIS,
  Big5 or EUC-KR, whose characters the library cannot count. The `.length` of a literal counts characters, not UTF-16
  units.
- `"text".to_i` and `"text".to_i(base)` of a literal are computed by the compiler: the number, or, where the text is
  not a number in that base (`"9173abc".to_i`), no value, which every target reports as a conversion error. Here the
  expression is never defined, so an instance has `Has_X` that is `False`. A text that the targets read differently
  (white space, an underscore between figures, a prefix `0x`, characters beyond ASCII) and a value beyond 64 bits are
  rejected.
- `valid` on a field whose type is chosen by `switch-on` is checked after the cases, on the value that was read, like
  `valid` on a field of the integer type of the cases: `if S64 (This.B) /= 17217 then Fail (S, Validation_Not_Equal);`. It
  is supported where all cases are integers (the value is held in the component of the widest type) and there is a `_`
  case. It is rejected where a case is not an integer, where no `_` case makes the value exist for every input (in the
  other targets the check there reads a field that was never set), and for `in-enum`.
- A field of a type with `terminator` or `pad-right` (alone or with `size`,
  `size-eos`) reads the bytes as a field of bytes does, cuts them, and
  parses the value from `Open (Buffer, Item)` of the slice, then `Join`. If
  the stream had failed before, the value is the empty one, since the
  substream does not know of the failure.
- A type of another description is `Foo.T` with `Foo.Parse`, where `Foo` is
  the id of that description in the form of the other package names; its
  nested types are `Foo.Bar_Type`, its enumerations `Foo.Baz_Enum`. The
  top-level type has no `_Type` suffix. The unit has `with Foo;` for each
  such package it uses. The compiler writes the files of every description of
  the compilation, the imported ones included. A type that no description
  defines is an opaque type if `ks-opaque-types` is set; see "Foreign code".
- `valid` on a repetition of integers of a fixed size holds for every
  element. After the read, a loop decodes each element again and applies the
  check, which fails the stream like the check of a single field; with
  `repeat: until` each element is checked as it is read. `valid` (and
  `contents`, which is `valid` with `eq`) on a repetition of bytes, strings or
  bit fields is checked on each element in the loop of `Parse` right after
  the element is read, with `_` the element; a check that fails fails the
  stream and ends the loop. It costs one comparison per element. `Next` and
  `Get_X` do not check again. `valid` on repetitions of structures is
  rejected. So is a `valid` that uses its own repeated field (`x.size`, an
  element of `x`): the other targets check an element when the field holds
  only the elements up to it.
- A subscript `x[i]` is defined for bytes and for a repetition of integers
  of a fixed size that is not `repeat: until`. It is defined where `0 <= i`
  and `i` is below the number of elements, which becomes a condition of the
  expression like the others. The element is decoded from `Buffer`, so the
  expression needs the buffer like a string length does. A subscript with a
  literal index of an array literal is the value. `_index` is the number of
  the element in the expressions of the element of a repetition that is parsed
  with a cursor (see "Repetitions").
- `contents` is a constant `X_Expected` of the body, compared by
  `Read_Contents`. `valid` is checked after the read and fails the stream
  with the matching `Validation_*` status.

## What differs from other Kaitai Struct targets

- There are no `_io`, `_parent` and `_root` references in the parsed values.
  What a type needs from its parent or the root is passed to its parser as a
  parameter, and has to be parsed by then. `_root` means the top-level type
  of the description in which the type is written.
- The bytes of a field with `process` are processed when the field is asked
  for, not when it is parsed.
- An opaque type does not get `_io`, `_parent` and `_root`, and a custom
  process is a procedure of a package, not a class that is constructed with the
  arguments: they are arguments of `Decode`. What the foreign code needs from
  the parent is an argument of the type. `Write` does not call an `encode` of a
  custom process; it writes the bytes of the input (see "Foreign code").
- A type that contains itself can be nested only up to a fixed depth.
- A failure is not an exception. It is the status of the stream.
- `contents` fields are checked but not stored.
- Seeking beyond the end of the stream fails at once, not at the next read.
- Repetitions are not arrays. They are walked with a cursor or read by
  index.
- An expression that overflows 64 bits makes the stream fail with
  `Arithmetic_Error`. Integer division rounds down, as the tests of Kaitai
  Struct ask for.
- A float expression is computed in 64 bits. Python does the same, but Java and C++
  compute an `f4` with an integer or with another `f4` in 32 bits (`a() + n()` of an `f4` and an `s2` is a `float`
  addition in their generated code, and only the result is widened), so that such a result can differ from this one in
  the last bits of an `f4`. `f4 + 0.5` is in 64 bits everywhere, because a literal is a `double`.
- An expression with an infinity or a not-a-number, or whose result would be an infinity, is not defined. The other
  targets compute on with such a value and compare it, for example `1e200 * 1e200 > 1.0` is true there. `to_i` of a
  float outside S64 is not defined (Python gives an integer of any size, Java saturates, C++ does not define it).
- An integer next to a float is converted to a float first, also in a comparison, as in Java and C++. Python compares
  an integer and a float exactly, so that `9007199254740993 == 9007199254740992.0` is false there and true here.
- Floats are not divided (`/` of a float is rejected), and `%` of floats is rejected.
- `%` with a divisor that is not positive is not defined, as in the Java and
  C++ runtimes of Kaitai Struct, where `mod` raises an error. The Python
  target computes a value.
- `rol` and `ror` rotate by the amount modulo 8. For an amount of 8 or more
  the runtimes of the other targets give results that are not rotations and
  that differ from each other.
- A type that starts with bit fields goes on in the byte that the bit fields
  before it left open, as in the other targets, but only where the stream is
  not certainly at a byte boundary. Where it is (see Fields), `Parse` starts
  with `Align_To_Byte` and has a precondition that no bits are left, which
  changes nothing for the values and lets the compiler fold the widths.

## Writing

The compiler generates `Write` when it is given `--read-write`; without it
nothing of this section is generated. A parsed value can then be written
again. Every type gets, next to `Parse`,

```ada
procedure Write (This : T; Buffer : Bytes; Target : in out Bytes; W : in out Writer)
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
| integer, float, enumeration | `Write_U4le (Target, W, This.X)` and the like, the integer as it was read; with a byte order decided at run time `Write_U4 (Target, W, This.Order, This.X)` |
| bit field | `Write_Bits_Int_Be (Target, W, N, This.X)`; `b1` writes 1 or 0 |
| bytes or string with a size | `Write_Bytes (Target, W, Buffer (This.X.First .. This.X.Last))` |
| bytes or string with a terminator | `Write_Bytes_Term (…, Term)`; with `pad-right` and a size `Write_Padded` |
| `contents` | `Write_Bytes (Target, W, X_Expected)` |
| field of a type | `Foo_Type.Write (This.X, Buffer, Target, W)`; for a type of another description `Foo.Write` |
| field of a type with `size` | `Subwriter (Target, W, To_Size (Size), Sub); Foo_Type.Write (This.X, Buffer, Target, Sub); Join (W, Sub);` |
| field with `if`, field chosen by `switch-on` | under the same condition (`Has_X`), the variant that is there |
| repetition of a fixed size | the slice, with `Write_Bytes` |
| other repetition | a loop over the cursor that writes each element |
| field with `process` | the bytes as they were in the input |

The loop over a cursor has the invariants `Belongs_To (Position, Buffer)` and
that `W` is valid and has the same window as when the loop began, and the
variant `Decreases => Remaining (Position)`. An element is parsed again with
`Next` to be written.

The rule that `Write` follows: parsing what it wrote gives the same value
again, with the same field values and slices with the same contents. The
output is the input again in the normal case. The differences are these and
no others, all of them follow from what a parsed value keeps: bytes of a
substream that the value inside does not use are written as zeros, bits that
no field reads (a description that skips bits) are written as zero, bytes
that follow a terminator in a field with a size are written as the
terminator byte, padding is written with the padding byte whatever was there,
a terminator that `eos-error: false` allows to be missing is written if the
writer has room for it, and instances with a position are not written (so a
description whose `seq` needs one is rejected with `--read-write`). An
element of a repetition is parsed again to be written; if the buffer is no
longer what was parsed, the writer fails with `Validation_Expr`.

Where the section was silent, the compiler does the following.

- A bit field after a field that is not a bit field starts a new byte, like
  the reader. `Align_To_Byte (W)` is the first statement of `Write` exactly
  where `Parse` starts with `Align_To_Byte (S)`, that is where the type that
  starts with bit fields is entered at a byte boundary; elsewhere its bit
  fields go on in the byte that is open, as they do when parsed.
- Bytes or a string with a size and a terminator or padding: `Write_Padded
  (…, Size, Pad)`, the padding byte being `pad-right` or else the
  terminator. Where `pad-right` is another byte than the terminator, the
  value, then the terminator if the size leaves room for it, then the
  padding, since the padding is stripped before the terminator is looked for
  and would otherwise eat the end of the value. The same holds for a field
  with `process`: its raw bytes are padded and cut like any bytes.
- Bytes with `size-eos`: the bytes, the terminator if there is one that is
  not included and the writer has room for it, then the padding byte up to
  the end of the window of the writer. The window is the substream of the
  field that contains the value; at the end of a target that is larger than
  the output the padding fills the rest of it.
- Bytes with a terminator and no size: with `include: false` and `consume:
  true` the bytes and the terminator; with `eos-error: false` the terminator
  only if the writer has room for it, as the field may have ended at the end
  of the stream; with `include: true` and `consume: true` the bytes; with
  `consume: false` the bytes and no terminator, since the next field reads it
  again. A target without room for a missing terminator is not an error;
  with `eos-error: true` the terminator was there, and a target without room
  for it is `Capacity_Exceeded`.
- A value of a type that is cut from bytes with a terminator and no size is
  written directly, followed by the terminator if it is neither included nor
  left in the stream, and for `eos-error: false` only if there is room. A value of a type with `size-eos` is written directly.
- A field whose type is chosen by `switch-on` writes the variant that is
  there; for a switch of integers the cases must have the same type, since
  the width to write is not kept.
- `contents`, parameters, `Parent_X`, `Root_X` and `Order` are not parsed
  from the input again: `contents` is written from its constant, the others
  are not written. Instances are not written. `valid` is not checked again.
- A size or a condition that the expression of a field needs is computed
  from `This` as in `Parse`; where it is not defined, the writer fails with
  `Arithmetic_Error`.
- The unit of a type that contains itself would need a `Subprogram_Variant`
  for `Write` that the library cannot prove from what `Next` delivers; the
  compiler rejects `--read-write` for such a type. It also rejects a
  terminator of more than one byte, a terminator that is included but not
  consumed, a value cut from bytes with both a size and a terminator or
  padding, `contents` with a condition, a field with a condition whose type
  depends on a value and has no `else`, and expressions that use `_io`.

There are no operations yet that change a parsed value or build one from
nothing. `examples/write_model` is generated with `--read-write`; a file
`options` in the directory of an example holds the options that
`scripts/generate-examples.sh` gives the compiler.

## Building generated code

- Compile with `-gnatn`. The read operations are meant to be inlined; without
  it a parser takes 50 to 70 percent more instructions.
- Once the parsers are proven, build with `KAITAI_STRUCT_CHECKS=proven` and
  with `-gnatp` for the parsers themselves. With run-time checks a parser
  that reads bytes takes two and a half times the instructions, one that
  reads bit fields seven times.
- The parsers are proven by GNATprove at `--level=1` without any annotation
  beyond what the compiler generates.
