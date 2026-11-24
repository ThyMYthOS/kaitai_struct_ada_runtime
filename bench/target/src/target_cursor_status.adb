with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Cursor_Status is
   function Parse return U64
   is (Stream_Runs.Run_Cursor_Status (Target_Data.Buffer));

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Cursor_Status;
