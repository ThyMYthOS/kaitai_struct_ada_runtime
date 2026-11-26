--  Usage: instance_bench [records] [variant] [none]
--         instance_bench 1 sizes
--
--  Measures what an instance with a position costs when an expression of `seq` needs it: parsed again at every use
--  (D1) or parsed once at the first use and kept in the value (D2).  Every variant parses the given number of records
--  (default 1000) and prints a checksum.  Without a variant all of them run and the program fails if variants of one
--  group disagree.  With a variant and "none" it only generates the input, which is what icount.sh subtracts.  The
--  variants and what they do are in README.md.

with Ada.Characters.Handling;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Bench_Inst_Int_D1;
with Bench_Inst_Int_D2;
with Bench_Inst_Until_D1;
with Bench_Inst_Until_D2;
with Bench_Inst_User_D1;
with Bench_Inst_User_D2;
with Bench_Types;      use Bench_Types;
with Inst_Data;
with Inst_Runs;        use Inst_Runs;
with Kaitai.Types;     use Kaitai.Types;

procedure Instance_Bench is

   Records    : Positive := 1_000;
   Filter     : constant String :=
     (if Argument_Count >= 2 then Ada.Characters.Handling.To_Lower (Argument (2)) else "");
   Only_Input : constant Boolean := Argument_Count >= 3 and then Argument (3) = "none";
   Failed     : Boolean := False;
   Sums       : array (Variant) of U64 := [others => 0];
   Done       : array (Variant) of Boolean := [others => False];

   function Name (V : Variant) return String
   is (Ada.Characters.Handling.To_Lower (Variant'Image (V)));

   function Selected (V : Variant) return Boolean
   is (Filter = "" or else Filter = Name (V));

   procedure Put_Size (Item : String; Bits : Natural) is
   begin
      Put_Line ("size " & Item & Natural'Image (Bits));
   end Put_Size;

begin
   if Argument_Count >= 1 then
      Records := Positive'Value (Argument (1));
   end if;
   if Filter = "sizes" then
      Put_Size ("int_d1", Bench_Inst_Int_D1.T'Object_Size);
      Put_Size ("int_d2", Bench_Inst_Int_D2.T'Object_Size);
      Put_Size ("user_d1", Bench_Inst_User_D1.T'Object_Size);
      Put_Size ("user_d2", Bench_Inst_User_D2.T'Object_Size);
      Put_Size ("until_d1", Bench_Inst_Until_D1.T'Object_Size);
      Put_Size ("until_d2", Bench_Inst_Until_D2.T'Object_Size);
      return;
   end if;

   for V in Variant loop
      if Selected (V) then
         declare
            Buffer : constant Bytes_Access := new Bytes (1 .. Length (Records) * Record_Size (Layout_Of (V)));
            Used   : Length;
         begin
            Inst_Data.Generate (Layout_Of (V), Records, Buffer.all, Used);
            if not Only_Input then
               Sums (V) := Run (V, Buffer (1 .. Used));
               Done (V) := True;
               Put_Line (Name (V) & Natural'Image (Records) & U64'Image (Sums (V)));
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
end Instance_Bench;
