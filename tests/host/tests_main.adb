--  Test program for the development machine.  The exit status tells whether
--  all tests passed.

with Ada.Command_Line;
with All_Tests;
with Bits_Arith_Tests;
with Files_Tests;
with Float_Reading_Tests;
with Float_Steps_Tests;
with Repeat_Bits_Use_Tests;
with Repeat_Elements_Tests;
with Repeat_Second_Tests;
with Test_Support;

procedure Tests_Main is
begin
   Bits_Arith_Tests.Run;
   Files_Tests.Run;
   Float_Reading_Tests.Run;
   Float_Steps_Tests.Run;
   Repeat_Bits_Use_Tests.Run;
   Repeat_Elements_Tests.Run;
   Repeat_Second_Tests.Run;
   All_Tests;
   if Test_Support.Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests_Main;
