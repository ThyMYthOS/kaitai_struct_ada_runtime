--  Callers of the parsers of param_bench, written to be proven: each parses a parent, walks its children with the
--  cursor and reads from each the one thing that needs a value from outside.  They show which contracts a caller
--  has to satisfy in the variants V1 (the child keeps the value), V2 (the caller gives it again) and V3 (the compiler
--  reduces it).  GNATprove proves them with outside_proof.gpr; they are not part of any benchmark.

with Kaitai.Types;

package Outside_Callers
  with SPARK_Mode
is

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Pstr_V1 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Pstr_V2 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Pstr_V2W (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Puser_V1 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Puser_V2 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Puser_V2W (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Puser_V3 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Pnav_V1 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Pnav_V2 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

   --  The number of children of the first parent in Buffer for which the value is true
   procedure Count_Pnav_V3 (Buffer : Kaitai.Types.Bytes; Found : out Natural);

end Outside_Callers;
