with Kaitai.Types; use Kaitai.Types;

with Target_Harness;

procedure Target_None is
   function Parse return U64
   is (0);

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_None;
