with Kaitai.Types; use Kaitai.Types;
with Target_Data;
with Target_Harness;

procedure Target_None_Fields is
   function Parse return U64 is
      Used : Length;
   begin
      Target_Data.Fill_Fields (Used);
      return 0;
   end Parse;

   procedure Run is new Target_Harness (Parse);
begin
   Run;
end Target_None_Fields;
