--  Input for the parsing benchmarks (parse_bench and its counterpart for the
--  target).  The generators are deterministic and need neither the heap nor
--  a clock, so that the host and the target program see the same bytes.
--
--  The caller provides a buffer of at least the maximum size for the number
--  of records; Used is the number of bytes that were filled in.

with Kaitai.Types; use Kaitai.Types;

package Bench_Data is

   --  The four bytes every record of the "contents" format starts with
   Magic : constant Bytes := [16#4B#, 16#53#, 16#41#, 16#44#];

   --  Records of two zero-terminated strings of 0 .. 12 bytes (none of them
   --  zero) followed by a u2le: at most 28 bytes
   Term_Record_Max : constant := 28;

   --  Records of the 4 bytes Magic followed by a u4le: 8 bytes
   Contents_Record_Size : constant := 8;

   --  Records of a length N (u1, 4 .. 16) followed by N bytes: at most 17
   --  bytes
   Substream_Record_Max : constant := 17;

   --  Records of four u1: 4 bytes
   Nested_Record_Size : constant := 4;

   procedure Fill_Term (Records : Positive; Buffer : out Bytes; Used : out Length);
   procedure Fill_Contents (Records : Positive; Buffer : out Bytes; Used : out Length);
   procedure Fill_Substream (Records : Positive; Buffer : out Bytes; Used : out Length);
   procedure Fill_Nested (Records : Positive; Buffer : out Bytes; Used : out Length);

end Bench_Data;
