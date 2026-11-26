--  Usage: float_bench [records] [variant]
--
--  Parses records of two floats and computes expressions from them, with
--  the operators of Ada and with the functions of Kaitai.Float_Arithmetic
--  that ask whether an operation is defined first, and prints a checksum.
--  The variants of one operation must agree on it.  The optional variant
--  argument restricts the run to one of them; "none" only generates the
--  input.  The program is meant for counting instructions with icount.sh.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Bench_Support;    use Bench_Support;
with Bench_Types;      use Bench_Types;
with Float_Runs;       use Float_Runs;
with Kaitai.Types;     use Kaitai.Types;

procedure Float_Bench is
   Records : constant Positive := (if Argument_Count >= 1 then Positive'Value (Argument (1)) else 100_000);
   Filter  : constant String := (if Argument_Count >= 2 then Argument (2) else "");
   Input   : constant Bytes_Access := Generate_Fixed (Records);

   procedure Report (Name : String; Sum : U64) is
   begin
      Put_Line (Name & " " & U64'Image (Sum));
   end Report;

   function Wanted (Name : String) return Boolean
   is (Filter = "" or else Filter = Name);
begin
   Prepare (Input.all);
   if Wanted ("nop") then
      Report ("nop", Run_Nop (Input.all));
   end if;
   if Wanted ("add_plain") then
      Report ("add_plain", Run_Add_Plain (Input.all));
   end if;
   if Wanted ("add_guarded") then
      Report ("add_guarded", Run_Add_Guarded (Input.all));
   end if;
   if Wanted ("add_lit_plain") then
      Report ("add_lit_plain", Run_Add_Lit_Plain (Input.all));
   end if;
   if Wanted ("add_lit_guarded") then
      Report ("add_lit_guarded", Run_Add_Lit_Guarded (Input.all));
   end if;
   if Wanted ("sub_plain") then
      Report ("sub_plain", Run_Sub_Plain (Input.all));
   end if;
   if Wanted ("sub_guarded") then
      Report ("sub_guarded", Run_Sub_Guarded (Input.all));
   end if;
   if Wanted ("mul_plain") then
      Report ("mul_plain", Run_Mul_Plain (Input.all));
   end if;
   if Wanted ("mul_guarded") then
      Report ("mul_guarded", Run_Mul_Guarded (Input.all));
   end if;
   if Wanted ("to_i_plain") then
      Report ("to_i_plain", Run_To_I_Plain (Input.all));
   end if;
   if Wanted ("to_i_guarded") then
      Report ("to_i_guarded", Run_To_I_Guarded (Input.all));
   end if;
   if Wanted ("expr_plain") then
      Report ("expr_plain", Run_Expr_Plain (Input.all));
   end if;
   if Wanted ("expr_guarded") then
      Report ("expr_guarded", Run_Expr_Guarded (Input.all));
   end if;
   if Wanted ("expr_guarded_where_needed") then
      Report ("expr_guarded_where_needed", Run_Expr_Guarded_Where_Needed (Input.all));
   end if;
end Float_Bench;
