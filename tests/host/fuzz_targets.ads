--  The parsers that Fuzz_Main feeds, each with inputs to start from and a
--  procedure that parses an input and reads everything from the result.

with Kaitai.Types; use Kaitai.Types;

package Fuzz_Targets is

   type Target is (Showcase_Parser, Extras_Parser);

   --  An input the parser accepts.  Round selects one where there are
   --  several.
   function Seed (T : Target; Round : Positive) return Bytes;

   --  Parse Input and read every field, element and instance of the
   --  result.  Fields is the number of values read, 0 if the parser did
   --  not accept the input.  Argument is used where a parser has a
   --  parameter.
   procedure Run (T : Target; Input : Bytes; Argument : U16; Fields : out Natural);

end Fuzz_Targets;
