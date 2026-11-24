with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Pointer_Sticky is
   function Parse return U64
   is (Stream_Runs.Run_Pointer_Sticky (Target_Data.View));

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Pointer_Sticky;
