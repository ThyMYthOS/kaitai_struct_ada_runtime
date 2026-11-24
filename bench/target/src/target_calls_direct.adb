with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Calls_Direct is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Fields (Used);
      return Stream_Runs.Run_Calls_Direct (Target_Data.Work_Buffer (1 .. Used));
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Calls_Direct;
