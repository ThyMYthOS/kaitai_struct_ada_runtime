--  Usage: param_bench [records] [children] [variant] [phase]
--
--  Parses records of a parent with N children, in the variants of values that come in from outside (see
--  bench/README.md, group "outside"): the value is kept in the type of the child (V1), the caller gives it again to
--  every accessor of the child (V2), or the compiler reduces it to what the child uses (V3).  It prints the checksum
--  of every variant of the phase 1 .. 3 (see Param_Runs), and fails if variants of one format disagree.
--
--  The variant "all" is the default, "none" generates the input only, "sizes" prints the sizes of the types in bytes:
--  of the child, then of the parent.  It is meant for counting instructions with
--  icount.sh.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Kaitai.Types;     use Kaitai.Types;
with Param_Data;
with Param_Runs;       use Param_Runs;

procedure Param_Bench is

   use type Param_Data.Format;

   Records : Positive := 10_000;
   N       : Positive := 10;
   Phase   : Phase_Number := 3;

   type Bytes_Access is access Bytes;

   Failed : Boolean := False;

begin
   if Argument_Count >= 1 then
      Records := Positive'Value (Argument (1));
   end if;
   if Argument_Count >= 2 then
      N := Positive'Value (Argument (2));
   end if;
   if Argument_Count >= 4 then
      Phase := Phase_Number'Value (Argument (4));
   end if;

   declare
      Filter : constant String := (if Argument_Count >= 3 then Argument (3) else "all");

      Pstr  : constant Bytes_Access := new Bytes (1 .. Length (Records) * Param_Data.Record_Max (Param_Data.Pstr, N));
      Puser : constant Bytes_Access := new Bytes (1 .. Length (Records) * Param_Data.Record_Max (Param_Data.Puser, N));
      Pnav  : constant Bytes_Access := new Bytes (1 .. Length (Records) * Param_Data.Record_Max (Param_Data.Pnav, N));

      Pstr_Used  : Length;
      Puser_Used : Length;
      Pnav_Used  : Length;

      Sums : array (Variant) of U64 := [others => 0];
   begin
      if Filter = "sizes" then
         Put_Sizes;
         return;
      end if;

      --  All inputs are generated whatever the variant, so that "none" has the cost every variant starts with
      Param_Data.Fill (Param_Data.Pstr, Records, N, Pstr.all, Pstr_Used);
      Param_Data.Fill (Param_Data.Puser, Records, N, Puser.all, Puser_Used);
      Param_Data.Fill (Param_Data.Pnav, Records, N, Pnav.all, Pnav_Used);

      for V in Variant loop
         if Filter = "all" or else Filter = Name (V) then
            Sums (V) :=
              Run
                (V,
                 (case Format_Of (V) is
                    when Param_Data.Pstr  => Pstr (1 .. Pstr_Used),
                    when Param_Data.Puser => Puser (1 .. Puser_Used),
                    when Param_Data.Pnav  => Pnav (1 .. Pnav_Used)),
                 Phase);
            Put_Line (Name (V) & U64'Image (Sums (V)));
         end if;
      end loop;

      if Filter = "all" then
         for V in Variant loop
            for W in Variant when Format_Of (W) = Format_Of (V) and then Sums (W) /= Sums (V) loop
               Put_Line (Standard_Error, "variants disagree: " & Name (V) & " and " & Name (W));
               Failed := True;
            end loop;
         end loop;
      end if;
   end;

   if Failed then
      Set_Exit_Status (Failure);
   end if;
end Param_Bench;
