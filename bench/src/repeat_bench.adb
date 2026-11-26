--  Usage: repeat_bench [elements] [repetitions] [variant] [none]
--
--  Measures how the elements of a repetition with elements of a variable size can be used by expressions: parsing
--  again, keeping what is needed, handing it on.  The input has the given number of elements (default 10); every
--  variant parses it the given number of times (default 1) and prints a checksum.  Without a variant all of them run
--  and the program fails if variants of one group disagree.  With a variant and "none" it only generates the input,
--  which is what icount.sh subtracts.  The variants and what they do are in README.md.

with Ada.Characters.Handling;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Bench_Types;      use Bench_Types;
with Kaitai.Types;     use Kaitai.Types;
with Rep_Data;
with Rep_Runs;         use Rep_Runs;
with Rep_Setup;

procedure Repeat_Bench is

   N          : Natural := 10;
   Reps       : Positive := 1;
   Filter     : constant String :=
     (if Argument_Count >= 3 then Ada.Characters.Handling.To_Lower (Argument (3)) else "");
   Only_Input : constant Boolean := Argument_Count >= 4 and then Argument (4) = "none";
   Failed     : Boolean := False;
   Sums       : array (Variant) of U64 := [others => 0];
   Done       : array (Variant) of Boolean := [others => False];

   function Name (V : Variant) return String
   is (Ada.Characters.Handling.To_Lower (Variant'Image (V)));

   function Selected (V : Variant) return Boolean
   is (Filter = "" or else Filter = Name (V));

begin
   if Argument_Count >= 1 then
      N := Natural'Value (Argument (1));
   end if;
   if Argument_Count >= 2 then
      Reps := Positive'Value (Argument (2));
   end if;

   for V in Variant loop
      if Selected (V) then
         declare
            Size   : constant Length := (if Layout_Of (V) = Rep_Empty_L then 8 else Rep_Data.Max_Size (N));
            Buffer : constant Bytes_Access := new Bytes (1 .. Size);
            Used   : Length;
         begin
            Rep_Setup.Generate (Layout_Of (V), N, Buffer.all, Used);
            if not Only_Input then
               if V = Prev_Naive and then N > 24 then
                  Put_Line (Name (V) & " skipped: exponential");
               else
                  Sums (V) := Run (V, Buffer (1 .. Used), Reps);
                  Done (V) := True;
                  Put_Line (Name (V) & Natural'Image (N) & Natural'Image (Reps) & U64'Image (Sums (V)));
               end if;
            end if;
         end;
      end if;
   end loop;

   for V in Variant loop
      for W in Variant loop
         if Done (V) and then Done (W) and then Group_Of (V) = Group_Of (W) and then Sums (V) /= Sums (W) then
            Put_Line (Standard_Error, "variants disagree: " & Name (V) & " and " & Name (W));
            Failed := True;
         end if;
      end loop;
   end loop;
   if Failed then
      Set_Exit_Status (Failure);
   end if;
end Repeat_Bench;
