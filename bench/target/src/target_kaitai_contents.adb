with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Kaitai_Contents is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Contents (Used);
      return Stream_Runs.Run_Contents_Kaitai (Target_Data.Contents_Buffer (1 .. Used));
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Kaitai_Contents;
