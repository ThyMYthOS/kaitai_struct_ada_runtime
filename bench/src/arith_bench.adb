--  Usage: arith_bench [records] [variant]
--
--  Parses a buffer and computes two expressions per record, with each way
--  of keeping integer arithmetic from overflowing, and prints a checksum.
--  All variants must agree on it.  The optional variant argument restricts
--  the run to one of them; "none" only generates the input.  The program is
--  meant for counting instructions with icount.sh.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Arith_Runs;       use Arith_Runs;
with Bench_Support;    use Bench_Support;
with Bench_Types;      use Bench_Types;
with Kaitai.Types;     use Kaitai.Types;

procedure Arith_Bench is
   Records : constant Positive := (if Argument_Count >= 1 then Positive'Value (Argument (1)) else 100_000);
   Filter  : constant String := (if Argument_Count >= 2 then Argument (2) else "");
   Input   : constant Bytes_Access := Generate_Fixed (Records);

   procedure Report (Name : String; Sum : U64) is
   begin
      Put_Line (Name & " " & U64'Image (Sum));
   end Report;
begin
   Prepare (Input.all);
   if Filter = "" or else Filter = "plain" then
      Report ("plain", Run_Plain (Input.all));
   end if;
   if Filter = "" or else Filter = "guarded" then
      Report ("guarded", Run_Guarded (Input.all));
   end if;
   if Filter = "" or else Filter = "guarded_where_needed" then
      Report ("guarded_where_needed", Run_Guarded_Where_Needed (Input.all));
   end if;
   if Filter = "" or else Filter = "checked" then
      Report ("checked", Run_Checked (Input.all));
   end if;
   if Filter = "" or else Filter = "flagged" then
      Report ("flagged", Run_Flagged (Input.all));
   end if;
end Arith_Bench;
