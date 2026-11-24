--  Types shared by the library and by generated code.

with System.Storage_Elements;

package Kaitai.Types
  with Pure, SPARK_Mode
is

   --  The integer types of the Kaitai Struct language.  They are declared
   --  here rather than taken from package Interfaces, so that a use clause
   --  for this package is all that code needs to compute with them.

   type U8 is mod 2**8 with Size => 8;
   type U16 is mod 2**16 with Size => 16;
   type U32 is mod 2**32 with Size => 32;
   type U64 is mod 2**64 with Size => 64;

   type S8 is range -2**7 .. 2**7 - 1 with Size => 8;
   type S16 is range -2**15 .. 2**15 - 1 with Size => 16;
   type S32 is range -2**31 .. 2**31 - 1 with Size => 32;
   type S64 is range -2**63 .. 2**63 - 1 with Size => 64;

   --  Shift_Left, Shift_Right, Shift_Right_Arithmetic, Rotate_Left and
   --  Rotate_Right for the unsigned types.  Standard Ada has them only for
   --  the types of package Interfaces; this pragma is specific to GNAT.
   pragma Provide_Shift_Operators (U8);
   pragma Provide_Shift_Operators (U16);
   pragma Provide_Shift_Operators (U32);
   pragma Provide_Shift_Operators (U64);

   subtype Byte is U8;

   --  A number of bytes.  It is as wide as an address of the target, because
   --  a buffer cannot be larger than the address space and a wider type
   --  costs half as many instructions again on a 32-bit microcontroller.
   type Length is range 0 .. System.Storage_Elements.Storage_Offset'Last;

   --  Position of a byte in a buffer.  The largest value of Length is left
   --  out, so that the position after the last byte of any buffer and the
   --  length of any buffer are values of Length.
   subtype Index is Length range 1 .. Length'Last - 1;

   type Bytes is array (Index range <>) of Byte;

   --  A length taken from parsed data.  A value that no buffer can have is
   --  mapped to the largest Length, which no stream can deliver either, so
   --  that asking a stream for that many bytes fails as it should.
   function To_Length (Value : U64) return Length
   is (if Value >= U64 (Length'Last) then Length'Last else Length (Value))
   with Inline;

   --  A length that is the value of an expression.  A negative value is
   --  mapped like one that is too large, so that the read fails.  This has
   --  a name of its own because a literal would fit both it and To_Length.
   function To_Size (Value : S64) return Length
   is (if Value < 0 or else U64 (Value) >= U64 (Length'Last) then Length'Last else Length (Value))
   with Inline;

   --  A number of repetitions that is the value of an expression.  A
   --  negative value means none, as in the other targets, where the loop
   --  simply does not run.
   function To_Count (Value : S64) return Length
   is (if Value <= 0 then 0 elsif U64 (Value) >= U64 (Length'Last) then Length'Last else Length (Value))
   with Inline;

   --  The bytes First .. Last of a buffer; empty if Last = First - 1.  A
   --  slice refers to data without copying it and is only meaningful
   --  together with the buffer it was taken from.
   type Slice is record
      First : Length := 1;
      Last  : Length := 0;
   end record
   with Predicate => Slice.First >= 1 and then Slice.Last >= Slice.First - 1;

   function Size (Item : Slice) return Length
   is (Item.Last - Item.First + 1);

   function Is_Empty (Item : Slice) return Boolean
   is (Item.Last < Item.First);

   --  True if all bytes of Item exist in Buffer
   function Within (Item : Slice; Buffer : Bytes) return Boolean
   is (Is_Empty (Item) or else (Item.First >= Buffer'First and then Item.Last <= Buffer'Last));

   type Byte_Order is (Little_Endian, Big_Endian);

   --  Why parsing stopped.  The first failure is kept; see Kaitai.Streams.
   type Status_Kind is
     (Success,
      End_Of_Stream,            --  more bytes requested than the stream has
      Undecided_Endianness,     --  the byte order was needed before it was known
      Validation_Not_Equal,     --  a value differs from the one required
      Validation_Less_Than,     --  a value is below the allowed minimum
      Validation_Greater_Than,  --  a value is above the allowed maximum
      Validation_Not_Any_Of,    --  a value is not among the allowed ones
      Validation_Not_In_Enum,   --  a value is not a member of its enumeration
      Validation_Expr,          --  a validation expression is false
      Unknown_Encoding,         --  a string uses an encoding that is not supported
      Illegal_Sequence,         --  bytes are not valid in the encoding of a string
      Arithmetic_Error,         --  overflow or division by zero in an expression
      Limit_Exceeded,           --  more repetitions or deeper nesting than allowed
      Capacity_Exceeded);       --  storage provided by the caller is too small

end Kaitai.Types;
