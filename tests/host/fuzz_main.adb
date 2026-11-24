--  Usage: fuzz_main [rounds] [seed]
--
--  Feeds the parsers under examples/ with input that is changed at random
--  and reads everything from what they deliver.  The program is built with
--  all run-time checks and with contracts executed, so that a check that
--  fails or a contract that does not hold ends it with an exception.
--
--  GNATprove proves that this cannot happen.  The proof rests on what it
--  assumes about the compiler, the target and the code that is not in
--  SPARK; this program looks at the result from the other side.  It is
--  deterministic: the same arguments give the same inputs.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Fuzz_Targets;
with Kaitai.Types;     use Kaitai.Types;

procedure Fuzz_Main is

   Rounds : constant Positive := (if Argument_Count >= 1 then Positive'Value (Argument (1)) else 100_000);
   State  : U64 := (if Argument_Count >= 2 then U64'Value (Argument (2)) else 16#9E37_79B9_7F4A_7C15#);

   --  Pseudo random numbers (xorshift64)
   function Random return U64 is
   begin
      State := State xor Shift_Left (State, 13);
      State := State xor Shift_Right (State, 7);
      State := State xor Shift_Left (State, 17);
      return State;
   end Random;

   --  A number in 0 .. Limit - 1
   function Below (Limit : Length) return Length
   is (Length (Random mod U64 (Limit)))
   with Pre => Limit > 0;

   Capacity : constant := 512;

   --  The input of one round: Work (1 .. Last)
   Work : Bytes (1 .. Capacity) := (others => 0);
   Last : Length := 0;

   --  Change Work at random: flip bits, overwrite bytes, cut off the end,
   --  append bytes, or copy a part to another place
   procedure Mutate is
      Changes : constant Length := 1 + Below (4);
   begin
      for I in 1 .. Changes loop
         case Below (6) is
            when 0 | 1  =>
               if Last > 0 then
                  declare
                     At_Index : constant Index := 1 + Below (Last);
                  begin
                     Work (At_Index) := Work (At_Index) xor Shift_Left (Byte'(1), Natural (Below (8)));
                  end;
               end if;

            when 2      =>
               if Last > 0 then
                  Work (1 + Below (Last)) := Byte (Random mod 256);
               end if;

            when 3      =>
               Last := Below (Last + 1);

            when 4      =>
               for J in 1 .. Below (9) loop
                  if Last < Capacity then
                     Last := Last + 1;
                     Work (Last) := Byte (Random mod 256);
                  end if;
               end loop;

            when others =>
               if Last > 1 then
                  declare
                     Count : constant Length := 1 + Below (Length'Min (Last - 1, 16));
                     From  : constant Index := 1 + Below (Last - Count + 1);
                     To    : constant Index := 1 + Below (Last - Count + 1);
                     Part  : constant Bytes := Work (From .. From + Count - 1);
                  begin
                     Work (To .. To + Count - 1) := Part;
                  end;
               end if;
         end case;
      end loop;
   end Mutate;

   Accepted : array (Fuzz_Targets.Target) of Natural := (others => 0);

begin
   for T in Fuzz_Targets.Target loop
      for Round in 1 .. Rounds loop
         declare
            Seed : constant Bytes := Fuzz_Targets.Seed (T, Round);
         begin
            Last := Seed'Length;
            Work (1 .. Last) := Seed;
         end;
         Mutate;
         --  The buffer does not start at index 1, so that code that
         --  confuses a position with an index is caught as well
         declare
            Input  : constant Bytes (1001 .. 1000 + Last) := Work (1 .. Last);
            Fields : Natural;
         begin
            Fuzz_Targets.Run (T, Input, U16 (Random mod 65536), Fields);
            if Fields > 0 then
               Accepted (T) := Accepted (T) + 1;
            end if;
         end;
      end loop;
      Put_Line
        (Fuzz_Targets.Target'Image (T)
         & ":"
         & Natural'Image (Accepted (T))
         & " of"
         & Positive'Image (Rounds)
         & " inputs accepted");
   end loop;
   Put_Line ("PASSED");
end Fuzz_Main;
