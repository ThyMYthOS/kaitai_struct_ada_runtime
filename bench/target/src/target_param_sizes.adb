with Ada.Text_IO;
with Param_Runs;

--  Prints the sizes of the types of the variants of param_bench; no measurement

procedure Target_Param_Sizes is
begin
   Param_Runs.Put_Sizes;
   Ada.Text_IO.Put_Line ("DONE");
   loop
      null;
   end loop;
end Target_Param_Sizes;
