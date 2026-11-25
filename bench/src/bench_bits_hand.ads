--  Hand-written parsers of the four bit field formats of formats/bench_bits_*.ksy, the lower bound for the generated
--  ones: whole-byte reads of the library, then shifts and masks written out by hand.  They begin wherever the stream
--  stands and do not look at bits that a bit field left over.  The big endian bit order of a byte is read as the bytes
--  in big endian order, the little endian bit order as the bytes in little endian order.

with Kaitai.Streams;
with Kaitai.Types; use Kaitai.Types;

package Bench_Bits_Hand is

   --  Four bit fields: b3, b5, b12, b12 (Flat, big endian) and the same in little endian order (Le)
   type Flat_T is record
      Is_Valid : Boolean := False;
      A        : U64 := 0;
      B        : U64 := 0;
      C        : U64 := 0;
      D        : U64 := 0;
   end record;

   --  b4, b4, u1, u2le
   type Mixed_T is record
      Is_Valid : Boolean := False;
      A        : U64 := 0;
      B        : U64 := 0;
      C        : U8 := 0;
      D        : U16 := 0;
   end record;

   --  u1, then the type that holds b4, b4, b8
   type Nested_T is record
      Is_Valid : Boolean := False;
      A        : U8 := 0;
      X        : U64 := 0;
      Y        : U64 := 0;
      Z        : U64 := 0;
   end record;

   procedure Parse_Flat (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Flat_T)
   with No_Inline;

   procedure Parse_Le (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Flat_T)
   with No_Inline;

   procedure Parse_Mixed (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Mixed_T)
   with No_Inline;

   procedure Parse_Nested (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Nested_T)
   with No_Inline;

end Bench_Bits_Hand;
