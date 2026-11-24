with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Fields4_Direct is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Fields (Used);
      return Stream_Runs.Run_Fields4_Direct (Target_Data.Work_Buffer (1 .. 4 * Target_Data.Records));
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Fields4_Direct;
