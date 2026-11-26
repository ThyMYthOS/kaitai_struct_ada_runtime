--  What target_repeat measures: the variant, the number of elements and the number of repetitions.  run_rep.sh writes
--  this file for every program it builds; the values here are those of a program that parses once.

with Rep_Runs;

package Repeat_Config is

   Variant  : constant Rep_Runs.Variant := Rep_Runs.A_Parse;
   Elements : constant := 10;
   Reps     : constant := 1;

   --  False: only generate the input, which is what the cost of the variant is measured against
   Run : constant Boolean := True;

end Repeat_Config;
