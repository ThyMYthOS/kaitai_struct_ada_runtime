with Kaitai.Types; use Kaitai.Types;
with Param_Data;
with Param_Runs;
with Target_Data;
with Target_Harness;
with Target_Param_Config;

procedure Target_Param is
   function Parse return U64 is
      use Target_Param_Config;
      Format : constant Param_Data.Format := Param_Runs.Format_Of (Variant);
      Used   : Length;
   begin
      Param_Data.Fill
        (Format, Records, N, Target_Data.Work_Buffer (1 .. Length (Records) * Param_Data.Record_Max (Format, N)), Used);
      return Param_Runs.Run (Variant, Target_Data.Work_Buffer (1 .. Used), Phase);
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Param;
