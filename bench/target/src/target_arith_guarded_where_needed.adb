with Arith_Runs;
with Kaitai.Types; use Kaitai.Types;
with Target_Data;
with Target_Harness;

procedure Target_Arith_Guarded_Where_Needed is
   function Parse return U64;

   function Parse return U64 is
   begin
      Arith_Runs.Prepare (Target_Data.Buffer);
      return Arith_Runs.Run_Guarded_Where_Needed (Target_Data.Buffer);
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Arith_Guarded_Where_Needed;
