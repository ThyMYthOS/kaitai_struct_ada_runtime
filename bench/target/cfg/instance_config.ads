--  What target_instance measures: the variant and the number of records.  run_inst.sh writes this file for every
--  program it builds; the values here are those of a program that parses 100 records.

with Inst_Runs;

package Instance_Config is

   Variant : constant Inst_Runs.Variant := Inst_Runs.Int_D1_Parse;
   Records : constant := 100;

   --  False: only generate the input, which is what the cost of the variant is measured against
   Run : constant Boolean := True;

end Instance_Config;
