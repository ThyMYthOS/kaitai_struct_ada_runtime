--  Test program for the development machine.  The exit status tells whether
--  all tests passed.

with Ada.Command_Line;
with All_Tests;
with Test_Support;

procedure Tests_Main is
begin
   All_Tests;
   if Test_Support.Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests_Main;
