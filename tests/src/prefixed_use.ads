pragma Extensions_Allowed (On);

with Kaitai.Types;

--  A caller of a generated parser that uses the prefixed notation of GNAT for
--  untagged types (V.Parse (Buffer, S, 3), V.Samples (Buffer, I)). It is
--  in SPARK and proven, so it shows that the notation keeps the contracts of
--  the parser: V.Samples (Buffer, I) has the precondition of Samples.

package Prefixed_Use
  with SPARK_Mode, Always_Terminates
is

   --  What Summarise found in the data
   type Summary is record
      --  True if the data were accepted as a `showcase`
      Parsed   : Boolean := False;
      --  True if Parse has read all of the data
      Complete : Boolean := False;
      --  The number of samples
      Samples  : Kaitai.Types.Length := 0;
      --  The largest sample, 0 if there are none
      Largest  : Kaitai.Types.U16 := 0;
      --  True if one of the entries is a text
      Has_Text : Boolean := False;
   end record;

   --  Parses Buffer as a `showcase` with the argument 3, goes through its samples and its entries
   --  @param Buffer The data
   --  @param Result What was found
   procedure Summarise (Buffer : Kaitai.Types.Bytes; Result : out Summary);

end Prefixed_Use;
