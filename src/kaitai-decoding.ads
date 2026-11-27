--  Decoding of integers at a given position of a buffer.
--
--  These functions do not check whether the bytes exist; that is their
--  precondition.  Kaitai.Streams offers the same decoding with the check
--  built in.  Use the functions here after one check for a whole block of
--  fixed size, which saves the check per field.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Decoding
  with Pure, SPARK_Mode
is

   --  True if Buffer has Count bytes starting at From
   function Has (Buffer : Bytes; From : Length; Count : Length) return Boolean
   is (Count = 0 or else (From >= Buffer'First and then From <= Buffer'Last and then Buffer'Last - From >= Count - 1));

   --  The functions from U8_At to U64_BE deliver the unsigned integer of 1, 2, 4
   --  or 8 bytes that starts at position From of Buffer.  LE means that the
   --  least significant byte comes first, BE that it comes last.  Their
   --  precondition is that all the bytes exist.

   --  The byte at From (u1)
   function U8_At (Buffer : Bytes; From : Index) return U8
   is (Buffer (From))
   with Inline, Pre => Has (Buffer, From, 1);

   --  The integer of 2 bytes, least significant first at From (u2le)
   function U16_LE (Buffer : Bytes; From : Index) return U16
   is (U16 (Buffer (From)) or Shift_Left (U16 (Buffer (From + 1)), 8))
   with Inline, Pre => Has (Buffer, From, 2);

   --  The integer of 2 bytes, most significant first at From (u2be)
   function U16_BE (Buffer : Bytes; From : Index) return U16
   is (Shift_Left (U16 (Buffer (From)), 8) or U16 (Buffer (From + 1)))
   with Inline, Pre => Has (Buffer, From, 2);

   --  The integer of 4 bytes, least significant first at From (u4le)
   function U32_LE (Buffer : Bytes; From : Index) return U32
   is (U32 (Buffer (From))
       or Shift_Left (U32 (Buffer (From + 1)), 8)
       or Shift_Left (U32 (Buffer (From + 2)), 16)
       or Shift_Left (U32 (Buffer (From + 3)), 24))
   with Inline, Pre => Has (Buffer, From, 4);

   --  The integer of 4 bytes, most significant first at From (u4be)
   function U32_BE (Buffer : Bytes; From : Index) return U32
   is (Shift_Left (U32 (Buffer (From)), 24)
       or Shift_Left (U32 (Buffer (From + 1)), 16)
       or Shift_Left (U32 (Buffer (From + 2)), 8)
       or U32 (Buffer (From + 3)))
   with Inline, Pre => Has (Buffer, From, 4);

   --  The integer of 8 bytes, least significant first at From (u8le)
   function U64_LE (Buffer : Bytes; From : Index) return U64
   is (U64 (U32_LE (Buffer, From)) or Shift_Left (U64 (U32_LE (Buffer, From + 4)), 32))
   with Inline, Pre => Has (Buffer, From, 8);

   --  The integer of 8 bytes, most significant first at From (u8be)
   function U64_BE (Buffer : Bytes; From : Index) return U64
   is (Shift_Left (U64 (U32_BE (Buffer, From)), 32) or U64 (U32_BE (Buffer, From + 4)))
   with Inline, Pre => Has (Buffer, From, 8);

   --  Reinterpretation of an unsigned value as a signed one in two's
   --  complement

   --  The signed integer with the same 8 bits as Value
   function To_S8 (Value : U8) return S8
   is (if Value < 2**7 then S8 (Value) else S8 (Integer (Value) - 2**8))
   with Inline;

   --  The signed integer with the same 16 bits as Value
   function To_S16 (Value : U16) return S16
   is (if Value < 2**15 then S16 (Value) else S16 (S32 (Value) - 2**16))
   with Inline;

   --  The signed integer with the same 32 bits as Value
   function To_S32 (Value : U32) return S32
   is (if Value < 2**31 then S32 (Value) else S32 (S64 (Value) - 2**32))
   with Inline;

   --  The signed integer with the same 64 bits as Value
   function To_S64 (Value : U64) return S64
   is (if Value < 2**63 then S64 (Value) else S64 (Value - 2**63) + S64'First)
   with Inline;

   --  Integers in a block of elements of one size, as they lie in a repetition of Kaitai Struct

   --  True if Items holds at least one whole element of Width bytes in Buffer, Width is 1, 2, 4 or 8, and the elements
   --  can be delivered as S64: Signed is set, or they have fewer than 8 bytes
   function Elements_OK (Buffer : Bytes; Items : Slice; Width : Length; Signed : Boolean) return Boolean
   is (Within (Items, Buffer)
       and then (Width = 1 or else Width = 2 or else Width = 4 or else Width = 8)
       and then Size (Items) >= Width
       and then Size (Items) mod Width = 0
       and then (Signed or else Width < 8));

   --  The integer of Width bytes at From, with the byte order Order, as an S64: two's complement if Signed, else
   --  unsigned
   function Element (Buffer : Bytes; From : Index; Width : Length; Signed : Boolean; Order : Byte_Order) return S64
   is (if Width = 1
       then (if Signed then S64 (To_S8 (U8_At (Buffer, From))) else S64 (U8_At (Buffer, From)))
       elsif Width = 2
       then
         (if Signed
          then S64 (To_S16 (if Order = Little_Endian then U16_LE (Buffer, From) else U16_BE (Buffer, From)))
          else S64 (if Order = Little_Endian then U16_LE (Buffer, From) else U16_BE (Buffer, From)))
       elsif Width = 4
       then
         (if Signed
          then S64 (To_S32 (if Order = Little_Endian then U32_LE (Buffer, From) else U32_BE (Buffer, From)))
          else S64 (if Order = Little_Endian then U32_LE (Buffer, From) else U32_BE (Buffer, From)))
       else To_S64 (if Order = Little_Endian then U64_LE (Buffer, From) else U64_BE (Buffer, From)))
   with
     Pre =>
       (Width = 1 or else Width = 2 or else Width = 4 or else Width = 8)
       and then Has (Buffer, From, Width)
       and then (Signed or else Width < 8);

   --  The smallest of the elements of Width bytes in Items
   function Min_Element (Buffer : Bytes; Items : Slice; Width : Length; Signed : Boolean; Order : Byte_Order) return S64
   with
     Pre  => Elements_OK (Buffer, Items, Width, Signed),
     Post =>
       (for all J in 0 .. Size (Items) / Width - 1 =>
          Min_Element'Result <= Element (Buffer, Items.First + J * Width, Width, Signed, Order))
       and then (for some J in 0 .. Size (Items) / Width - 1 =>
                   Min_Element'Result = Element (Buffer, Items.First + J * Width, Width, Signed, Order));

   --  The largest of the elements of Width bytes in Items
   function Max_Element (Buffer : Bytes; Items : Slice; Width : Length; Signed : Boolean; Order : Byte_Order) return S64
   with
     Pre  => Elements_OK (Buffer, Items, Width, Signed),
     Post =>
       (for all J in 0 .. Size (Items) / Width - 1 =>
          Max_Element'Result >= Element (Buffer, Items.First + J * Width, Width, Signed, Order))
       and then (for some J in 0 .. Size (Items) / Width - 1 =>
                   Max_Element'Result = Element (Buffer, Items.First + J * Width, Width, Signed, Order));

end Kaitai.Decoding;
