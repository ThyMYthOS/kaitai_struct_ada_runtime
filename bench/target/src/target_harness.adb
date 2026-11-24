with Ada.Text_IO;
with Target_Data;

procedure Target_Harness is
   Sum : U64;
begin
   Target_Data.Fill;
   Sum := Parse;
   Ada.Text_IO.Put_Line ("SUM" & U64'Image (Sum));
   Ada.Text_IO.Put_Line ("DONE");
   loop
      null;
   end loop;
end Target_Harness;
