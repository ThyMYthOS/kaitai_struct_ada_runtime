with Kaitai.Types; use Kaitai.Types;
with Stream_Runs;
with Target_Data;
with Target_Harness;

procedure Target_Term_Classic is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Term (Used);
      return Stream_Runs.Run_Term_Classic (Target_Data.Term_Buffer (1 .. Used));
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Term_Classic;
