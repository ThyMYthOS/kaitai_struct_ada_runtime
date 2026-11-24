--  Usage: memory_bench <strategy> [records] [max_payload] [repetitions] [phases]
--
--  Prints one line: strategy, then per-record medians in nanoseconds for
--  build, traverse, pick (per access) and teardown, then resident memory per
--  record in bytes, then checksums that must agree across strategies.
--
--  The optional phases argument (0 .. 4) stops each repetition early; see
--  Strategies.Run.  It is meant for counting instructions with icount.sh.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;
with Strategies;

procedure Memory_Bench is
   Records     : Positive := 1_000_000;
   Max_Payload : Natural := 32;
   Reps        : Positive := 7;
   Phases      : Strategies.Phase_Count := 4;
begin
   if Argument_Count < 1 then
      Ada.Text_IO.Put_Line ("usage: memory_bench <strategy> [records] [max_payload] [reps] [phases]");
      Set_Exit_Status (Failure);
      return;
   end if;
   if Argument_Count >= 2 then
      Records := Positive'Value (Argument (2));
   end if;
   if Argument_Count >= 3 then
      Max_Payload := Natural'Value (Argument (3));
   end if;
   if Argument_Count >= 4 then
      Reps := Positive'Value (Argument (4));
   end if;
   if Argument_Count >= 5 then
      Phases := Strategies.Phase_Count'Value (Argument (5));
   end if;
   Strategies.Run (Strategies.Strategy'Value (Argument (1)), Records, Max_Payload, Reps, Phases);
end Memory_Bench;
