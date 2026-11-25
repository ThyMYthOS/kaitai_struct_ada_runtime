with Bit_Runs;
with Kaitai.Types; use Kaitai.Types;
with Target_Data;
with Target_Harness;

procedure Target_Bits_Flat_V1 is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Fields (Used);
      return Bit_Runs.Run_Bits_Flat_V1 (Target_Data.Work_Buffer (1 .. 4 * Target_Data.Records));
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Bits_Flat_V1;
