with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Generated_Nested is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Nested (Used);
      return Stream_Runs.Run_Generated_Nested (Target_Data.Work_Buffer (1 .. Used));
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Generated_Nested;
