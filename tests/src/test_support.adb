with Ada.Text_IO; use Ada.Text_IO;

package body Test_Support is

   Checks : Natural := 0;
   Failed : Natural := 0;

   --  Name of the current group, kept in a buffer of fixed size
   Current : String (1 .. 40) := (others => ' ');
   Used    : Natural := 0;

   procedure Group (Name : String) is
   begin
      Used := Natural'Min (Name'Length, Current'Length);
      Current (1 .. Used) := Name (Name'First .. Name'First + Used - 1);
   end Group;

   procedure Check (Condition : Boolean; What : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         Failed := Failed + 1;
         Put_Line ("FAIL " & Current (1 .. Used) & ": " & What);
      end if;
   end Check;

   procedure Summary is
   begin
      Put_Line ("checks:" & Natural'Image (Checks) & ", failed:" & Natural'Image (Failed));
      Put_Line (if Failed = 0 then "PASSED" else "FAILED");
   end Summary;

   function Failures return Natural
   is (Failed);

end Test_Support;
