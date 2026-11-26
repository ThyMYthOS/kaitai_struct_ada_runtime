with Inst_Data;
with Inst_Runs;
with Instance_Config;
with Kaitai.Types; use Kaitai.Types;
with Target_Harness;

procedure Target_Instance is
   Layout : constant Inst_Runs.Layout := Inst_Runs.Layout_Of (Instance_Config.Variant);

   Buffer : Bytes (1 .. Length (Instance_Config.Records) * Inst_Runs.Record_Size (Layout));

   function Parse return U64 is
      Used : Length;
   begin
      Inst_Data.Generate (Layout, Instance_Config.Records, Buffer, Used);
      if Instance_Config.Run then
         return Inst_Runs.Run (Instance_Config.Variant, Buffer (1 .. Used));
      else
         return 0;
      end if;
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Instance;
