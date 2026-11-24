with Arith_Runs;
with Kaitai.Types; use Kaitai.Types;
with Target_Data;
with Target_Harness;

procedure Target_Arith_None is
   function Parse return U64;

   function Parse return U64 is
   begin
      Arith_Runs.Prepare (Target_Data.Buffer);
      return 0;
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Arith_None;
