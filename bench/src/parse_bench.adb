--  Usage: parse_bench [records] [repetitions] [variant]
--
--  Holds operations of the library against hand-written code that does the
--  same job on the buffer directly: zero-terminated strings, "contents",
--  substreams, and the local copy of the stream in small nested types.  It
--  prints the median time per record in nanoseconds and a checksum.
--  Variants of one group read the same data and must agree on the checksum;
--  if they do not, the program says so and fails.
--
--  The optional variant argument restricts the run to one variant; "none"
--  only generates the input.  It is meant for counting instructions with
--  icount.sh.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Long_Float_Text_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;      use Ada.Text_IO;
with Bench_Data;
with Bench_Support;    use Bench_Support;
with Bench_Types;      use Bench_Types;
with Kaitai.Types;     use Kaitai.Types;
with Stream_Runs;      use Stream_Runs;

procedure Parse_Bench is

   Records : Positive := 1_000_000;
   Reps    : Positive := 11;

   type Variant is
     (Kaitai_Term_V,
      Term_Classic_V,
      Kaitai_Contents_V,
      Contents_Classic_V,
      Kaitai_Substream_V,
      Substream_Classic_V,
      Nested_Local_V,
      Nested_Outer_Only_V,
      Nested_Direct_V);

   type Group is (Term_G, Contents_G, Substream_G, Nested_G);

   Groups : constant array (Variant) of Group :=
     [Kaitai_Term_V       => Term_G,
      Term_Classic_V      => Term_G,
      Kaitai_Contents_V   => Contents_G,
      Contents_Classic_V  => Contents_G,
      Kaitai_Substream_V  => Substream_G,
      Substream_Classic_V => Substream_G,
      Nested_Local_V      => Nested_G,
      Nested_Outer_Only_V => Nested_G,
      Nested_Direct_V     => Nested_G];

   subtype Name is String (1 .. 17);

   Names : constant array (Variant) of Name :=
     ["kaitai_term      ",
      "term_classic     ",
      "kaitai_contents  ",
      "contents_classic ",
      "kaitai_substream ",
      "substream_classic",
      "nested_local     ",
      "nested_outer_only",
      "nested_direct    "];

   Failed : Boolean := False;

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

      --  All inputs are generated whatever the variant, so that "none" has
      --  the cost every variant starts with
      Term           : constant Bytes_Access := new Bytes (1 .. Length (Records) * Bench_Data.Term_Record_Max);
      Contents       : constant Bytes_Access := new Bytes (1 .. Length (Records) * Bench_Data.Contents_Record_Size);
      Substream      : constant Bytes_Access := new Bytes (1 .. Length (Records) * Bench_Data.Substream_Record_Max);
      Nested         : constant Bytes_Access := new Bytes (1 .. Length (Records) * Bench_Data.Nested_Record_Size);
      Term_Used      : Length;
      Contents_Used  : Length;
      Substream_Used : Length;
      Nested_Used    : Length;

      Times : array (Variant) of Samples (1 .. Reps) := [others => [others => 0.0]];
      Sums  : array (Variant) of U64 := [others => 0];
      Watch : Stopwatch;
   begin
      Bench_Data.Fill_Term (Records, Term.all, Term_Used);
      Bench_Data.Fill_Contents (Records, Contents.all, Contents_Used);
      Bench_Data.Fill_Substream (Records, Substream.all, Substream_Used);
      Bench_Data.Fill_Nested (Records, Nested.all, Nested_Used);

      --  Interleave the variants so that drift affects all of them alike
      for R in 1 .. Reps loop
         for V in Variant loop
            if Selected (V) then
               Watch := Start;
               Sums (V) :=
                 (case V is
                    when Kaitai_Term_V       => Run_Term_Kaitai (Term (1 .. Term_Used)),
                    when Term_Classic_V      => Run_Term_Classic (Term (1 .. Term_Used)),
                    when Kaitai_Contents_V   => Run_Contents_Kaitai (Contents (1 .. Contents_Used)),
                    when Contents_Classic_V  => Run_Contents_Classic (Contents (1 .. Contents_Used)),
                    when Kaitai_Substream_V  => Run_Substream_Kaitai (Substream (1 .. Substream_Used)),
                    when Substream_Classic_V => Run_Substream_Classic (Substream (1 .. Substream_Used)),
                    when Nested_Local_V      => Run_Nested_Local (Nested (1 .. Nested_Used)),
                    when Nested_Outer_Only_V => Run_Nested_Outer_Only (Nested (1 .. Nested_Used)),
                    when Nested_Direct_V     => Run_Nested_Direct (Nested (1 .. Nested_Used)));
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

      for V in Variant when Selected (V) loop
         for W in Variant when Selected (W) and then Groups (W) = Groups (V) and then Sums (W) /= Sums (V) loop
            Put_Line (Standard_Error, "variants disagree: " & Names (V) & " and " & Names (W));
            Failed := True;
         end loop;
      end loop;
   end;

   if Failed then
      Set_Exit_Status (Failure);
   end if;
end Parse_Bench;
