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

   function U8_At (Buffer : Bytes; From : Index) return U8
   is (Buffer (From))
   with Inline, Pre => Has (Buffer, From, 1);

   function U16_LE (Buffer : Bytes; From : Index) return U16
   is (U16 (Buffer (From)) or Shift_Left (U16 (Buffer (From + 1)), 8))
   with Inline, Pre => Has (Buffer, From, 2);

   function U16_BE (Buffer : Bytes; From : Index) return U16
   is (Shift_Left (U16 (Buffer (From)), 8) or U16 (Buffer (From + 1)))
   with Inline, Pre => Has (Buffer, From, 2);

   function U32_LE (Buffer : Bytes; From : Index) return U32
   is (U32 (Buffer (From))
       or Shift_Left (U32 (Buffer (From + 1)), 8)
       or Shift_Left (U32 (Buffer (From + 2)), 16)
       or Shift_Left (U32 (Buffer (From + 3)), 24))
   with Inline, Pre => Has (Buffer, From, 4);

   function U32_BE (Buffer : Bytes; From : Index) return U32
   is (Shift_Left (U32 (Buffer (From)), 24)
       or Shift_Left (U32 (Buffer (From + 1)), 16)
       or Shift_Left (U32 (Buffer (From + 2)), 8)
       or U32 (Buffer (From + 3)))
   with Inline, Pre => Has (Buffer, From, 4);

   function U64_LE (Buffer : Bytes; From : Index) return U64
   is (U64 (U32_LE (Buffer, From)) or Shift_Left (U64 (U32_LE (Buffer, From + 4)), 32))
   with Inline, Pre => Has (Buffer, From, 8);

   function U64_BE (Buffer : Bytes; From : Index) return U64
   is (Shift_Left (U64 (U32_BE (Buffer, From)), 32) or U64 (U32_BE (Buffer, From + 4)))
   with Inline, Pre => Has (Buffer, From, 8);

   --  Reinterpretation of an unsigned value as a signed one in two's
   --  complement

   function To_S8 (Value : U8) return S8
   is (if Value < 2**7 then S8 (Value) else S8 (Integer (Value) - 2**8))
   with Inline;

   function To_S16 (Value : U16) return S16
   is (if Value < 2**15 then S16 (Value) else S16 (S32 (Value) - 2**16))
   with Inline;

   function To_S32 (Value : U32) return S32
   is (if Value < 2**31 then S32 (Value) else S32 (S64 (Value) - 2**32))
   with Inline;

   function To_S64 (Value : U64) return S64
   is (if Value < 2**63 then S64 (Value) else S64 (Value - 2**63) + S64'First)
   with Inline;

end Kaitai.Decoding;
