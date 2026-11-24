--  Helpers for bit fields: integers of 1 to 64 bits that need not start or
--  end at a byte boundary.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Bits
  with Pure, SPARK_Mode
is

   --  Width of a bit field
   subtype Bit_Count is Natural range 1 .. 64;

   --  Number of bits of a byte that a bit field has left unread
   subtype Bit_Remainder is Natural range 0 .. 7;

   --  The largest value of a bit field of Count bits: Count one bits
   function Mask (Count : Natural) return U64
   is (if Count >= 64 then U64'Last else 2**Count - 1);

   --  Number of whole bytes that reading Count bits takes from a stream in
   --  which Left bits of the byte read last are still unread
   function Bytes_Needed (Count : Bit_Count; Left : Bit_Remainder) return Length
   is (if Count <= Left then 0 else Length ((Count - Left + 7) / 8));

   --  Number of bits that are left unread after such a read
   function Left_After (Count : Bit_Count; Left : Bit_Remainder) return Bit_Remainder
   is (if Count <= Left then Left - Count else (8 - (Count - Left) mod 8) mod 8);

end Kaitai.Bits;
