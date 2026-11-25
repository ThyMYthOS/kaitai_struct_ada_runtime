--  Usage: parse_bench [records] [repetitions] [variant]
--
--  Holds operations of the library against hand-written code that does the
--  same job on the buffer directly: zero-terminated strings, "contents",
--  substreams, processing of whole records, and the local copy of the stream
--  in nested types and in records of few or many fields.  It prints the
--  median time per record in nanoseconds and a checksum.  Variants of one
--  group read the same data and must agree on the checksum; if they do not,
--  the program says so and fails.
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
with Bit_Runs;         use Bit_Runs;
with Kaitai.Types;     use Kaitai.Types;
with Stream_Runs;      use Stream_Runs;

procedure Parse_Bench is

   Records : Positive := 1_000_000;
   Reps    : Positive := 11;

   type Variant is
     (Kaitai_Term_V,
      Kaitai_Term_Local_V,
      Term_Classic_V,
      Kaitai_Contents_V,
      Kaitai_Contents_Local_V,
      Contents_Classic_V,
      Kaitai_Substream_V,
      Kaitai_Substream_Local_V,
      Substream_Classic_V,
      Nested_Local_V,
      Nested_Outer_Only_V,
      Nested_Direct_V,
      Fields1_Local_V,
      Fields1_Direct_V,
      Fields2_Local_V,
      Fields2_Direct_V,
      Fields3_Local_V,
      Fields3_Direct_V,
      Fields4_Local_V,
      Fields4_Direct_V,
      Fields8_Local_V,
      Fields8_Direct_V,
      Calls_Both_Local_V,
      Calls_Inner_Local_V,
      Calls_Direct_V,
      Kaitai_Xor_One_V,
      Xor_One_Classic_V,
      Kaitai_Xor_Many_V,
      Xor_Many_Classic_Mod_V,
      Xor_Many_Classic_Counter_V,
      Kaitai_Rotate_V,
      Rotate_Classic_V,
      Status1_Sticky_V,
      Status1_Returned_V,
      Status4_Sticky_V,
      Status4_Returned_V,
      Status8_Sticky_V,
      Status8_Returned_V,
      Generated_Fields4_V,
      Generated_Term_V,
      Generated_Nested_V,
      Bits_Flat_V1_V,
      Bits_Flat_V2_V,
      Bits_Flat_V3_V,
      Bits_Flat_V3a_V,
      Bits_Flat_V4_V,
      Bits_Le_V1_V,
      Bits_Le_V2_V,
      Bits_Le_V3_V,
      Bits_Le_V3a_V,
      Bits_Le_V4_V,
      Bits_Mixed_V1_V,
      Bits_Mixed_V2_V,
      Bits_Mixed_V3_V,
      Bits_Mixed_V3a_V,
      Bits_Mixed_V4_V,
      Bits_Nested_V1_V,
      Bits_Nested_V2_V,
      Bits_Nested_V3_V,
      Bits_Nested_V3a_V,
      Bits_Nested_V4_V);

   type Group is
     (Term_G,
      Contents_G,
      Substream_G,
      Nested_G,
      Fields1_G,
      Fields2_G,
      Fields3_G,
      Fields4_G,
      Fields8_G,
      Calls_G,
      Xor_One_G,
      Xor_Many_G,
      Rotate_G,
      Status1_G,
      Status4_G,
      Status8_G,
      Bits_Flat_G,
      Bits_Le_G,
      Bits_Mixed_G,
      Bits_Nested_G);

   Groups : constant array (Variant) of Group :=
     [Kaitai_Term_V              => Term_G,
      Kaitai_Term_Local_V        => Term_G,
      Term_Classic_V             => Term_G,
      Kaitai_Contents_V          => Contents_G,
      Kaitai_Contents_Local_V    => Contents_G,
      Contents_Classic_V         => Contents_G,
      Kaitai_Substream_V         => Substream_G,
      Kaitai_Substream_Local_V   => Substream_G,
      Substream_Classic_V        => Substream_G,
      Nested_Local_V             => Nested_G,
      Nested_Outer_Only_V        => Nested_G,
      Nested_Direct_V            => Nested_G,
      Fields1_Local_V            => Fields1_G,
      Fields1_Direct_V           => Fields1_G,
      Fields2_Local_V            => Fields2_G,
      Fields2_Direct_V           => Fields2_G,
      Fields3_Local_V            => Fields3_G,
      Fields3_Direct_V           => Fields3_G,
      Fields4_Local_V            => Fields4_G,
      Fields4_Direct_V           => Fields4_G,
      Fields8_Local_V            => Fields8_G,
      Fields8_Direct_V           => Fields8_G,
      Calls_Both_Local_V         => Calls_G,
      Calls_Inner_Local_V        => Calls_G,
      Calls_Direct_V             => Calls_G,
      Kaitai_Xor_One_V           => Xor_One_G,
      Xor_One_Classic_V          => Xor_One_G,
      Kaitai_Xor_Many_V          => Xor_Many_G,
      Xor_Many_Classic_Mod_V     => Xor_Many_G,
      Xor_Many_Classic_Counter_V => Xor_Many_G,
      Kaitai_Rotate_V            => Rotate_G,
      Rotate_Classic_V           => Rotate_G,
      Status1_Sticky_V           => Status1_G,
      Status1_Returned_V         => Status1_G,
      Status4_Sticky_V           => Status4_G,
      Status4_Returned_V         => Status4_G,
      Status8_Sticky_V           => Status8_G,
      Status8_Returned_V         => Status8_G,
      Generated_Fields4_V        => Fields4_G,
      Generated_Term_V           => Term_G,
      Generated_Nested_V         => Nested_G,
      Bits_Flat_V1_V             => Bits_Flat_G,
      Bits_Flat_V2_V             => Bits_Flat_G,
      Bits_Flat_V3_V             => Bits_Flat_G,
      Bits_Flat_V3a_V            => Bits_Flat_G,
      Bits_Flat_V4_V             => Bits_Flat_G,
      Bits_Le_V1_V               => Bits_Le_G,
      Bits_Le_V2_V               => Bits_Le_G,
      Bits_Le_V3_V               => Bits_Le_G,
      Bits_Le_V3a_V              => Bits_Le_G,
      Bits_Le_V4_V               => Bits_Le_G,
      Bits_Mixed_V1_V            => Bits_Mixed_G,
      Bits_Mixed_V2_V            => Bits_Mixed_G,
      Bits_Mixed_V3_V            => Bits_Mixed_G,
      Bits_Mixed_V3a_V           => Bits_Mixed_G,
      Bits_Mixed_V4_V            => Bits_Mixed_G,
      Bits_Nested_V1_V           => Bits_Nested_G,
      Bits_Nested_V2_V           => Bits_Nested_G,
      Bits_Nested_V3_V           => Bits_Nested_G,
      Bits_Nested_V3a_V          => Bits_Nested_G,
      Bits_Nested_V4_V           => Bits_Nested_G];

   subtype Name is String (1 .. 24);

   Names : constant array (Variant) of Name :=
     ["kaitai_term             ",
      "kaitai_term_local       ",
      "term_classic            ",
      "kaitai_contents         ",
      "kaitai_contents_local   ",
      "contents_classic        ",
      "kaitai_substream        ",
      "kaitai_substream_local  ",
      "substream_classic       ",
      "nested_local            ",
      "nested_outer_only       ",
      "nested_direct           ",
      "fields1_local           ",
      "fields1_direct          ",
      "fields2_local           ",
      "fields2_direct          ",
      "fields3_local           ",
      "fields3_direct          ",
      "fields4_local           ",
      "fields4_direct          ",
      "fields8_local           ",
      "fields8_direct          ",
      "calls_both_local        ",
      "calls_inner_local       ",
      "calls_direct            ",
      "kaitai_xor_one          ",
      "xor_one_classic         ",
      "kaitai_xor_many         ",
      "xor_many_classic_mod    ",
      "xor_many_classic_counter",
      "kaitai_rotate           ",
      "rotate_classic          ",
      "status1_sticky          ",
      "status1_returned        ",
      "status4_sticky          ",
      "status4_returned        ",
      "status8_sticky          ",
      "status8_returned        ",
      "generated_fields4       ",
      "generated_term          ",
      "generated_nested        ",
      "bits_flat_v1            ",
      "bits_flat_v2            ",
      "bits_flat_v3            ",
      "bits_flat_v3a           ",
      "bits_flat_v4            ",
      "bits_le_v1              ",
      "bits_le_v2              ",
      "bits_le_v3              ",
      "bits_le_v3a             ",
      "bits_le_v4              ",
      "bits_mixed_v1           ",
      "bits_mixed_v2           ",
      "bits_mixed_v3           ",
      "bits_mixed_v3a          ",
      "bits_mixed_v4           ",
      "bits_nested_v1          ",
      "bits_nested_v2          ",
      "bits_nested_v3          ",
      "bits_nested_v3a         ",
      "bits_nested_v4          "];

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
      Fields         : constant Bytes_Access := new Bytes (1 .. Length (Records) * Bench_Data.Fields_Record_Max);
      Process        : constant Bytes_Access := new Bytes (1 .. Length (Records) * Bench_Data.Process_Record_Size);
      Term_Used      : Length;
      Contents_Used  : Length;
      Substream_Used : Length;
      Nested_Used    : Length;
      Fields_Used    : Length;
      Process_Used   : Length;

      Times : array (Variant) of Samples (1 .. Reps) := [others => [others => 0.0]];
      Sums  : array (Variant) of U64 := [others => 0];
      Watch : Stopwatch;
   begin
      Bench_Data.Fill_Term (Records, Term.all, Term_Used);
      Bench_Data.Fill_Contents (Records, Contents.all, Contents_Used);
      Bench_Data.Fill_Substream (Records, Substream.all, Substream_Used);
      Bench_Data.Fill_Nested (Records, Nested.all, Nested_Used);
      Bench_Data.Fill_Fields (Records, Fields.all, Fields_Used);
      Bench_Data.Fill_Process (Records, Process.all, Process_Used);

      --  Interleave the variants so that drift affects all of them alike
      for R in 1 .. Reps loop
         for V in Variant loop
            if Selected (V) then
               Watch := Start;
               Sums (V) :=
                 (case V is
                    when Kaitai_Term_V              => Run_Term_Kaitai (Term (1 .. Term_Used)),
                    when Kaitai_Term_Local_V        => Run_Term_Kaitai_Local (Term (1 .. Term_Used)),
                    when Term_Classic_V             => Run_Term_Classic (Term (1 .. Term_Used)),
                    when Kaitai_Contents_V          => Run_Contents_Kaitai (Contents (1 .. Contents_Used)),
                    when Kaitai_Contents_Local_V    => Run_Contents_Kaitai_Local (Contents (1 .. Contents_Used)),
                    when Contents_Classic_V         => Run_Contents_Classic (Contents (1 .. Contents_Used)),
                    when Kaitai_Substream_V         => Run_Substream_Kaitai (Substream (1 .. Substream_Used)),
                    when Kaitai_Substream_Local_V   => Run_Substream_Kaitai_Local (Substream (1 .. Substream_Used)),
                    when Substream_Classic_V        => Run_Substream_Classic (Substream (1 .. Substream_Used)),
                    when Nested_Local_V             => Run_Nested_Local (Nested (1 .. Nested_Used)),
                    when Nested_Outer_Only_V        => Run_Nested_Outer_Only (Nested (1 .. Nested_Used)),
                    when Nested_Direct_V            => Run_Nested_Direct (Nested (1 .. Nested_Used)),
                    when Fields1_Local_V            => Run_Fields1_Local (Fields (1 .. 1 * Length (Records))),
                    when Fields1_Direct_V           => Run_Fields1_Direct (Fields (1 .. 1 * Length (Records))),
                    when Fields2_Local_V            => Run_Fields2_Local (Fields (1 .. 2 * Length (Records))),
                    when Fields2_Direct_V           => Run_Fields2_Direct (Fields (1 .. 2 * Length (Records))),
                    when Fields3_Local_V            => Run_Fields3_Local (Fields (1 .. 3 * Length (Records))),
                    when Fields3_Direct_V           => Run_Fields3_Direct (Fields (1 .. 3 * Length (Records))),
                    when Fields4_Local_V            => Run_Fields4_Local (Fields (1 .. 4 * Length (Records))),
                    when Fields4_Direct_V           => Run_Fields4_Direct (Fields (1 .. 4 * Length (Records))),
                    when Fields8_Local_V            => Run_Fields8_Local (Fields (1 .. 8 * Length (Records))),
                    when Fields8_Direct_V           => Run_Fields8_Direct (Fields (1 .. 8 * Length (Records))),
                    when Calls_Both_Local_V         => Run_Calls_Both_Local (Fields (1 .. Fields_Used)),
                    when Calls_Inner_Local_V        => Run_Calls_Inner_Local (Fields (1 .. Fields_Used)),
                    when Calls_Direct_V             => Run_Calls_Direct (Fields (1 .. Fields_Used)),
                    when Kaitai_Xor_One_V           => Run_Xor_One_Kaitai (Process (1 .. Process_Used)),
                    when Xor_One_Classic_V          => Run_Xor_One_Classic (Process (1 .. Process_Used)),
                    when Kaitai_Xor_Many_V          => Run_Xor_Many_Kaitai (Process (1 .. Process_Used)),
                    when Xor_Many_Classic_Mod_V     => Run_Xor_Many_Classic_Mod (Process (1 .. Process_Used)),
                    when Xor_Many_Classic_Counter_V => Run_Xor_Many_Classic_Counter (Process (1 .. Process_Used)),
                    when Kaitai_Rotate_V            => Run_Rotate_Kaitai (Process (1 .. Process_Used)),
                    when Rotate_Classic_V           => Run_Rotate_Classic (Process (1 .. Process_Used)),
                    when Status1_Sticky_V           => Run_Status1_Sticky (Fields (1 .. 1 * Length (Records))),
                    when Status1_Returned_V         => Run_Status1_Returned (Fields (1 .. 1 * Length (Records))),
                    when Status4_Sticky_V           => Run_Status4_Sticky (Fields (1 .. 4 * Length (Records))),
                    when Status4_Returned_V         => Run_Status4_Returned (Fields (1 .. 4 * Length (Records))),
                    when Status8_Sticky_V           => Run_Status8_Sticky (Fields (1 .. 8 * Length (Records))),
                    when Status8_Returned_V         => Run_Status8_Returned (Fields (1 .. 8 * Length (Records))),
                    when Generated_Fields4_V        => Run_Generated_Fields4 (Fields (1 .. 4 * Length (Records))),
                    when Generated_Term_V           => Run_Generated_Term (Term (1 .. Term_Used)),
                    when Generated_Nested_V         => Run_Generated_Nested (Nested (1 .. Nested_Used)),
                    when Bits_Flat_V1_V             => Run_Bits_Flat_V1 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Flat_V2_V             => Run_Bits_Flat_V2 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Flat_V3_V             => Run_Bits_Flat_V3 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Flat_V3a_V            => Run_Bits_Flat_V3a (Fields (1 .. 4 * Length (Records))),
                    when Bits_Flat_V4_V             => Run_Bits_Flat_V4 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Le_V1_V               => Run_Bits_Le_V1 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Le_V2_V               => Run_Bits_Le_V2 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Le_V3_V               => Run_Bits_Le_V3 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Le_V3a_V              => Run_Bits_Le_V3a (Fields (1 .. 4 * Length (Records))),
                    when Bits_Le_V4_V               => Run_Bits_Le_V4 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Mixed_V1_V            => Run_Bits_Mixed_V1 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Mixed_V2_V            => Run_Bits_Mixed_V2 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Mixed_V3_V            => Run_Bits_Mixed_V3 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Mixed_V3a_V           => Run_Bits_Mixed_V3a (Fields (1 .. 4 * Length (Records))),
                    when Bits_Mixed_V4_V            => Run_Bits_Mixed_V4 (Fields (1 .. 4 * Length (Records))),
                    when Bits_Nested_V1_V           => Run_Bits_Nested_V1 (Fields (1 .. 3 * Length (Records))),
                    when Bits_Nested_V2_V           => Run_Bits_Nested_V2 (Fields (1 .. 3 * Length (Records))),
                    when Bits_Nested_V3_V           => Run_Bits_Nested_V3 (Fields (1 .. 3 * Length (Records))),
                    when Bits_Nested_V3a_V          => Run_Bits_Nested_V3a (Fields (1 .. 3 * Length (Records))),
                    when Bits_Nested_V4_V           => Run_Bits_Nested_V4 (Fields (1 .. 3 * Length (Records))));
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
