--  Test program for a microcontroller.  There is nowhere to return to, so
--  it prints DONE and stops; the result is the line before that.

with Ada.Text_IO;
with All_Tests;

procedure Target_Tests_Main is
begin
   All_Tests;
   Ada.Text_IO.Put_Line ("DONE");
   loop
      null;
   end loop;
end Target_Tests_Main;
