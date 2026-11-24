--  A test harness small enough for a light run-time library: no exceptions,
--  no heap, output through Ada.Text_IO only.

package Test_Support is

   --  Start a group of checks; its name prefixes the report of a failure
   procedure Group (Name : String);

   --  Count a check and report it if Condition is False
   procedure Check (Condition : Boolean; What : String);

   --  Print the totals.  The last line is "PASSED" or "FAILED".
   procedure Summary;

   function Failures return Natural;

end Test_Support;
