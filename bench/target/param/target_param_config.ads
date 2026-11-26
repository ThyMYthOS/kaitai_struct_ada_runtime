--  What the program target_param does: which variant of which format, how many records of how many children, and up to
--  which phase (see Param_Runs).  run.sh writes a file like this one for every measurement and names its directory
--  with PARAM_DIR; this is the default.

with Param_Runs;

package Target_Param_Config is

   Variant : constant Param_Runs.Variant := Param_Runs.Pstr_1;

   Records : constant := 100;

   N : constant := 10;

   Phase : constant Param_Runs.Phase_Number := 3;

end Target_Param_Config;
