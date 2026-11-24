with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Status1_Sticky is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Fields (Used);
      return Stream_Runs.Run_Status1_Sticky (Target_Data.Work_Buffer (1 .. 1 * Target_Data.Records));
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Status1_Sticky;
