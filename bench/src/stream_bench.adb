--  Usage: stream_bench [records] [repetitions] [variant]
--
--  Parses a buffer with each stream design and prints the median time per
--  15 bytes in nanoseconds and a checksum.  The byte-aligned designs read
--  records of u1, u2le, u4le and u8be; the bit field designs read records of
--  3, 13, 4 and 12 bits.  Designs that read the same fields must agree on the
--  checksum.
--
--  The optional variant argument restricts the run to one design; "none"
--  only generates the input.  It is meant for counting instructions with
--  icount.sh.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Long_Float_Text_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;      use Ada.Text_IO;
with Bench_Support;    use Bench_Support;
with Bench_Types;      use Bench_Types;
with Kaitai.Types;     use Kaitai.Types;
with Stream_Runs;      use Stream_Runs;
with Stream_Runs.Raising;
with Stream_Variants;  use Stream_Variants;

procedure Stream_Bench is

   Records : Positive := 1_000_000;
   Reps    : Positive := 11;

   type Variant is
     (Cursor_Sticky_V,
      Pointer_Sticky_V,
      Cursor_Status_V,
      Cursor_Raise_V,
      Block_Check_V,
      Kaitai_V,
      Kaitai_Block_V,
      Kaitai_Local_V,
      Bits_Classic_Be_V,
      Kaitai_Bits_Be_V,
      Bits_Classic_Le_V,
      Kaitai_Bits_Le_V);

   subtype Name is String (1 .. 15);

   Names : constant array (Variant) of Name :=
     ["cursor_sticky  ",
      "pointer_sticky ",
      "cursor_status  ",
      "cursor_raise   ",
      "block_check    ",
      "kaitai         ",
      "kaitai_block   ",
      "kaitai_local   ",
      "bits_classic_be",
      "kaitai_bits_be ",
      "bits_classic_le",
      "kaitai_bits_le "];

begin
   if Argument_Count >= 1 then
      Records := Positive'Value (Argument (1));
   end if;
   if Argument_Count >= 2 then
      Reps := Positive'Value (Argument (2));
   end if;

   declare
      Filter : constant String := (if Argument_Count >= 3 then Argument (3) else "");

      function Selected (V : Variant) return Boolean
      is (Filter = "" or else Filter = Ada.Strings.Fixed.Trim (Names (V), Ada.Strings.Right));

      Input : constant Bytes_Access := Generate_Fixed (Records);
      View  : constant Pointer_Sticky.Bytes_View := Pointer_Sticky.Bytes_View (Input);
      Times : array (Variant) of Samples (1 .. Reps) := [others => [others => 0.0]];
      Sums  : array (Variant) of U64 := [others => 0];
      Watch : Stopwatch;
   begin
      --  Interleave the variants so that drift affects all of them alike
      for R in 1 .. Reps loop
         for V in Variant loop
            if Selected (V) then
               Watch := Start;
               Sums (V) :=
                 (case V is
                    when Cursor_Sticky_V   => Run_Cursor_Sticky (Input.all),
                    when Pointer_Sticky_V  => Run_Pointer_Sticky (View),
                    when Cursor_Status_V   => Run_Cursor_Status (Input.all),
                    when Cursor_Raise_V    => Raising.Run_Cursor_Raise (Input.all),
                    when Block_Check_V     => Run_Block_Check (Input.all),
                    when Kaitai_V          => Run_Kaitai (Input.all),
                    when Kaitai_Block_V    => Run_Kaitai_Block (Input.all),
                    when Kaitai_Local_V    => Run_Kaitai_Local (Input.all),
                    when Bits_Classic_Be_V => Run_Bits_Classic_Be (Input.all),
                    when Kaitai_Bits_Be_V  => Run_Kaitai_Bits_Be (Input.all),
                    when Bits_Classic_Le_V => Run_Bits_Classic_Le (Input.all),
                    when Kaitai_Bits_Le_V  => Run_Kaitai_Bits_Le (Input.all));
               Times (V) (R) := Elapsed_NS (Watch) / Long_Float (Records);
            end if;
         end loop;
      end loop;

      for V in Variant when Selected (V) loop
         Put (Names (V) & " ");
         Ada.Long_Float_Text_IO.Put (Median (Times (V)), Fore => 6, Aft => 3, Exp => 0);
         Ada.Long_Float_Text_IO.Put (Minimum (Times (V)), Fore => 6, Aft => 3, Exp => 0);
         Put_Line ("  " & U64'Image (Sums (V)));
      end loop;
   end;
end Stream_Bench;
