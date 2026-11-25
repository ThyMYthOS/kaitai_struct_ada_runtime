--  Loops that call the parsers of the formats/bench_bits_*.ksy formats once per record, as the generated code of a
--  repeated field would, and form a checksum of the values.  The variants of one format are:
--
--    v1   as generated (generated/): Parse begins with Align_To_Byte
--    v2   the same without that call (src/bench_bits_<format>_v2.adb)
--    v3   the same behind a test of Bits_Left (S) = 0 (src/bench_bits_<format>_v3.adb)
--    v3a  as v3, the branch for 0 calls Align_To_Byte (src/bench_bits_<format>_v3a.adb)
--    v4   hand-written, whole-byte reads and shifts (bench_bits_hand.adb)
--
--  The data is that of Bench_Data.Fill_Fields; a record is 4 bytes, 3 for the nested format.

with Kaitai.Types; use Kaitai.Types;

package Bit_Runs is

   function Run_Bits_Flat_V1 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Flat_V2 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Flat_V3 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Flat_V3a (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Flat_V4 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Le_V1 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Le_V2 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Le_V3 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Le_V3a (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Le_V4 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Mixed_V1 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Mixed_V2 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Mixed_V3 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Mixed_V3a (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Mixed_V4 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Nested_V1 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Nested_V2 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Nested_V3 (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Nested_V3a (Data : Bytes) return U64
   with No_Inline;

   function Run_Bits_Nested_V4 (Data : Bytes) return U64
   with No_Inline;

end Bit_Runs;
