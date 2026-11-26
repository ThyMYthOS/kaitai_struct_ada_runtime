--  Input for the benchmarks of instances (instance_bench and its counterpart for the target).  The generators are
--  deterministic and need neither the heap nor a clock, so that the host and the target program see the same bytes.
--
--  A record of Int_L is the 8 chunks (offset : u4, len : u4) and then num_chunks : u4 = 8.  A record of User_L is
--  3 numbers (u1), 6 entries (s2, the last one 7), and the header (qty : u2 = 3, limit : s2 = 7, tag : 2 bytes).
--  A record of Until_L is the 6 entries and the header.  The instance is the last 4 or 6 bytes of the record.

with Inst_Runs;
with Kaitai.Types; use Kaitai.Types;

package Inst_Data is

   --  Fills Buffer with Records records of the layout; Used is the number of bytes
   procedure Generate (L : Inst_Runs.Layout; Records : Positive; Buffer : out Bytes; Used : out Length)
   with
     Pre =>
       Buffer'First = 1
       and then Records < 100_000_000
       and then Buffer'Length >= Length (Records) * Inst_Runs.Record_Size (L);

end Inst_Data;
