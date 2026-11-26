with Float_Runs;
with Kaitai.Types; use Kaitai.Types;
with Target_Data;
with Target_Harness;

procedure Target_Float_Expr_Guarded is
   function Parse return U64;

   function Parse return U64 is
   begin
      Float_Runs.Prepare (Target_Data.Buffer);
      return Float_Runs.Run_Expr_Guarded (Target_Data.Buffer);
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_Float_Expr_Guarded;
