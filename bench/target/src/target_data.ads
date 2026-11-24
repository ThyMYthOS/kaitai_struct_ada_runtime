--  Input for the target benchmark: a buffer in static memory, since a
--  low-end target has neither a file system nor room for it on the stack.

with Kaitai.Types;    use Kaitai.Types;
with Stream_Variants; use Stream_Variants;

package Target_Data is

   Records : constant := 1_000;

   Buffer : aliased Bytes := [1 .. Records * 15 => 0];

   function View return Pointer_Sticky.Bytes_View
   is (Buffer'Access);

   --  Fill Buffer with pseudo random bytes
   procedure Fill;

end Target_Data;
