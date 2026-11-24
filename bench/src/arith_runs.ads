--  The loops of the arithmetic benchmark.  Each parses records of
--
--     a : u1,  b : u2le,  c : u4le,  d : u8be
--
--  and computes two expressions from them,
--
--     x = c * b + a - 7        which cannot overflow, as the types show
--     y = d * b + c            which does not overflow for the input used
--                              here, but the compiler cannot know that
--
--  The parser is not inlined and gets the stream as a parameter, as
--  generated code would.

with Kaitai.Types; use Kaitai.Types;

package Arith_Runs is

   --  Clear the upper three bytes of every d, so that y does not overflow
   procedure Prepare (Data : in out Bytes);

   --  No protection against overflow: what the checks cost is measured
   --  against this
   function Run_Plain (Data : Bytes) return U64;

   --  Kaitai.Arithmetic: ask first, then compute
   function Run_Guarded (Data : Bytes) return U64;

   --  The same, but only where the types do not rule out an overflow, as a
   --  compiler backend that tracks the ranges of expressions could do it
   function Run_Guarded_Where_Needed (Data : Bytes) return U64;

   --  Values with a validity flag
   function Run_Checked (Data : Bytes) return U64;

   --  Procedures with a flag that stays False
   function Run_Flagged (Data : Bytes) return U64;

end Arith_Runs;
