--  Input for the target benchmark: a buffer in static memory, since a
--  low-end target has neither a file system nor room for it on the stack.

with Bench_Data;
with Kaitai.Types;    use Kaitai.Types;
with Stream_Variants; use Stream_Variants;

package Target_Data is

   Records : constant := 1_000;

   Buffer : aliased Bytes := [1 .. Records * 15 => 0];

   function View return Pointer_Sticky.Bytes_View
   is (Buffer'Access);

   --  Fill Buffer with pseudo random bytes
   procedure Fill;

   --  The buffer for the formats of Bench_Data, which parse_bench has on the
   --  host.  One buffer serves all of them, since a program uses only one and
   --  a low-end target has little memory.  The program fills it itself before
   --  it parses; the program that parses nothing does the same, so that the
   --  cost of filling is not part of the difference.  Used is the number of
   --  bytes that are meant.
   Work_Buffer : aliased Bytes (1 .. Records * Bench_Data.Process_Record_Size);

   procedure Fill_Fields (Used : out Length);
   procedure Fill_Process (Used : out Length);
   procedure Fill_Term (Used : out Length);
   procedure Fill_Contents (Used : out Length);
   procedure Fill_Substream (Used : out Length);
   procedure Fill_Nested (Used : out Length);

end Target_Data;
