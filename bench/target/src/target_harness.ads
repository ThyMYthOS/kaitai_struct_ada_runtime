--  Common main program of the target benchmark.  It fills the buffer, runs
--  Parse over it once, prints the checksum and stops.  The number of
--  instructions the simulator has executed by then, minus that of the
--  program whose Parse does nothing, is the cost of parsing.

with Kaitai.Types; use Kaitai.Types;

generic
   with function Parse return U64;
procedure Target_Harness;
