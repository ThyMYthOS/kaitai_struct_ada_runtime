--  Input for the benchmarks of repetitions (repeat_bench and its counterpart for the target).  The generators are
--  deterministic and need neither the heap nor a clock, so that the host and the target program see the same bytes.
--
--  An element of the repetitions with elements of a variable size is
--
--     len : u1,  name : len bytes,  v : u1
--
--  and the element with the number K has len = K mod 8.  The caller provides a buffer of at least Max_Size (N) bytes;
--  Used is the number of bytes that were filled in.

with Kaitai.Types; use Kaitai.Types;

package Rep_Data is

   --  Upper bound of the size of every layout below for N elements
   function Max_Size (N : Natural) return Length
   is (Length (N) * 24 + 64);

   --  num_items : u4, then N elements (bench_rep)
   procedure Fill_Rep (N : Natural; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Max_Size (N);

   --  num_items : u4 = N, flag : u1 = 0 (bench_rep_empty): N elements that are empty
   procedure Fill_Rep_Empty (N : Natural; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= 8;

   --  num_items : u4, N bytes of the number of the element mod 8 (bench_rep_fixed)
   procedure Fill_Rep_Fixed (N : Natural; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Max_Size (N);

   --  What follows the elements in the layouts that use them: num_refs : u4 = N, then N references
   --
   --     idx : u4 = (7 * J + 3) mod N,  tag : (idx mod 8) bytes
   --
   --  The size of a tag is the len of the element idx.  Index_Fixed has the elements of Rep_Fixed in front.
   procedure Fill_Index (N : Natural; Fixed : Boolean; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Max_Size (N) and then N > 0;

   --  The worst input for Index_Get that a given size allows: N elements of 2 bytes (len = 0), then N / 4 references
   --  of 4 bytes, each to the last element, which has a tag of no bytes: every reference parses all N elements again
   procedure Fill_Index_Worst (N : Natural; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Max_Size (N) and then N > 0;

   --  The elements, then tail : (len of the last element) bytes
   procedure Fill_Last (N : Natural; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Max_Size (N) and then N > 0;

   --  num_items : u4, then N elements of which each, except the first, is followed by (len of the one before) bytes
   procedure Fill_Prev_Self (N : Natural; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Max_Size (N) and then N > 0;

   --  The elements, then N blocks of which each, except the first, is (len of the element before it) bytes
   procedure Fill_Prev_Other (N : Natural; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Max_Size (N) and then N > 0;

end Rep_Data;
