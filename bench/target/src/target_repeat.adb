with Kaitai.Types; use Kaitai.Types;
with Rep_Data;
with Rep_Runs;
with Rep_Setup;
with Repeat_Config;
with Target_Harness;

procedure Target_Repeat is
   use type Rep_Runs.Layout;

   Layout : constant Rep_Runs.Layout := Rep_Runs.Layout_Of (Repeat_Config.Variant);

   Buffer : Bytes (1 .. (if Layout = Rep_Runs.Rep_Empty_L then 8 else Rep_Data.Max_Size (Repeat_Config.Elements)));

   function Parse return U64 is
      Used : Length;
   begin
      Rep_Setup.Generate (Layout, Repeat_Config.Elements, Buffer, Used);
      if Repeat_Config.Run then
         return Rep_Runs.Run (Repeat_Config.Variant, Buffer (1 .. Used), Repeat_Config.Reps);
      else
         return 0;
      end if;
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Repeat;
