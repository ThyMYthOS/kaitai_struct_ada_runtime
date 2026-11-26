with Bits_After_Bytes;
with Bits_Byte_Aligned;
with Bits_Enum;
with Bits_First_Type;
with Bits_In_Repeat;
with Bits_In_Types;
with Bits_Simple;
with Bytes_Pad_Term;
with Bytes_Pad_Term_Equal;
with Default_Endian_Expr_Is_Le;
with Enum_0;
with Enum_Long_Range_U;
with Expr_1;
with Expr_Sizeof_Type_0;
with Expr_Sizeof_Value_Sized;
with Expr_To_I_Trailing;
with Fixed_Struct;
with Hello_World;
with If_Struct;
with Imports0;
with Instance_Kept;
with Instance_Std;
with Kaitai.Byte_Arrays;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Kaitai.Writers;
with Outside;
with Params_Def;
with Position_Abs;
with Repeat_Bits;
with Repeat_Eos_U4;
with Repeat_Index;
with Repeat_N_Empty;
with Repeat_N_Struct;
with Repeat_Until_Complex;
with Sample_Data;    use Sample_Data;
with Str_Eos_Pad_Term;
with Str_Encodings;
with Str_Literal_Encodings;
with Str_Literals_Latin1;
with Str_Ordering;
with Subscripts;
with Switch_Bytearray;
with Switch_Else_Only;
with Switch_Manual_Int;
with Term_Strz;
with Term_Strz4;
with Term_Struct;
with Test_Support;   use Test_Support;
with Valid_Fail_Eq_Int;
with Valid_Fail_Range_Str;
with Valid_Fail_Repeat_Eq_Int;
with Valid_Long;
with Valid_Switch;
with Yaml_Ints;

package body Examples_Tests is

   Sample_Fixed_Struct : Bytes renames Sample_Data.Fixed_Struct;
   Sample_Term_Strz    : Bytes renames Sample_Data.Term_Strz;

   procedure Test_Hello_World is
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Hello_World.T;
      None : constant Bytes (1 .. 0) := (others => 0);
   begin
      Group ("examples hello_world");
      Hello_World.Parse (This, Sample_Fixed_Struct, S);
      Check (Hello_World.Valid (This) and then OK (S), "parses");
      Check (Hello_World.One (This) = 16#50#, "one");
      Check (Pos (S) = 1, "one byte consumed");

      S := Open (None);
      Hello_World.Parse (This, None, S);
      Check (not Hello_World.Valid (This) and then Status (S) = End_Of_Stream, "an empty file is rejected");
   end Test_Hello_World;

   procedure Test_Fixed_Struct is
      use Fixed_Struct;
      S       : Stream := Open (Sample_Fixed_Struct);
      This    : Fixed_Struct.T;
      H       : Header_Type.T;
      Outcome : Status_Kind;
      Bad     : Bytes := Sample_Fixed_Struct;
   begin
      Group ("examples fixed_struct");
      Parse (This, Sample_Fixed_Struct, S);
      Check (Valid (This) and then Pos (S) = 0, "parses; the type has no fields in sequence");
      Hdr (This, Sample_Fixed_Struct, H, Outcome);
      Check (Outcome = Success and then Header_Type.Valid (H), "instance hdr parses");
      if Header_Type.Valid (H) then
         Check (Header_Type.Uint8 (H) = 255, "hdr.uint8");
         Check (Header_Type.Uint16 (H) = 65_535, "hdr.uint16");
         Check (Header_Type.Uint32 (H) = 4_294_967_295, "hdr.uint32");
         Check (Header_Type.Uint64 (H) = 18_446_744_073_709_551_615, "hdr.uint64");
         Check (Header_Type.Sint8 (H) = -1, "hdr.sint8");
         Check (Header_Type.Sint16 (H) = -1, "hdr.sint16");
         Check (Header_Type.Sint32 (H) = -1, "hdr.sint32");
         Check (Header_Type.Sint64 (H) = -1, "hdr.sint64");
         Check (Header_Type.Uint16le (H) = 66, "hdr.uint16le");
         Check (Header_Type.Uint32le (H) = 66, "hdr.uint32le");
         Check (Header_Type.Uint64le (H) = 66, "hdr.uint64le");
         Check (Header_Type.Sint16le (H) = -66, "hdr.sint16le");
         Check (Header_Type.Sint32le (H) = -66, "hdr.sint32le");
         Check (Header_Type.Sint64le (H) = -66, "hdr.sint64le");
         Check (Header_Type.Uint16be (H) = 66, "hdr.uint16be");
         Check (Header_Type.Uint32be (H) = 66, "hdr.uint32be");
         Check (Header_Type.Uint64be (H) = 66, "hdr.uint64be");
         Check (Header_Type.Sint16be (H) = -66, "hdr.sint16be");
         Check (Header_Type.Sint32be (H) = -66, "hdr.sint32be");
         Check (Header_Type.Sint64be (H) = -66, "hdr.sint64be");
      end if;
      Hdr (This, Sample_Fixed_Struct, H, Outcome);
      Check (Outcome = Success, "the instance can be asked for again");

      --  A file whose second magic is wrong
      Bad (9) := 16#51#;
      S := Open (Bad);
      Parse (This, Bad, S);
      Hdr (This, Bad, H, Outcome);
      Check (Outcome = Validation_Not_Equal and then not Header_Type.Valid (H), "wrong contents are rejected");

      --  Every truncated file
      for Last in 0 .. Sample_Fixed_Struct'Last - 1 loop
         S := Open (Sample_Fixed_Struct (1 .. Last));
         Parse (This, Sample_Fixed_Struct (1 .. Last), S);
         Hdr (This, Sample_Fixed_Struct (1 .. Last), H, Outcome);
         if Outcome /= End_Of_Stream or else Header_Type.Valid (H) then
            Check (False, "a truncated file runs out of bytes");
         end if;
      end loop;
      Check (True, "truncated files are rejected");
   end Test_Fixed_Struct;

   procedure Test_Bits_Simple is
      use Bits_Simple;
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Bits_Simple.T;
   begin
      Group ("examples bits_simple");
      Parse (This, Sample_Fixed_Struct, S);
      Check (Valid (This) and then Pos (S) = 28, "parses 28 bytes");
      if Valid (This) then
         Check (Byte_1 (This) = 16#50#, "byte_1");
         Check (Byte_2 (This) = 16#41#, "byte_2");
         Check (not Bits_A (This), "bits_a");
         Check (Bits_B (This) = 2#100#, "bits_b");
         Check (Bits_C (This) = 2#0011#, "bits_c");
         Check (Large_Bits_1 (This) = 2#0100101100#, "large_bits_1");
         Check (Spacer (This) = 2#101#, "spacer");
         Check (Large_Bits_2 (This) = 2#10100110001#, "large_bits_2");
         Check (Normal_S2 (This) = -1, "normal_s2");
         Check (Byte_8_9_10 (This) = 16#504143#, "byte_8_9_10");
         Check (Byte_11_To_14 (This) = 16#4B2D552D#, "byte_11_to_14");
         Check (Byte_15_To_19 (This) = 16#444546FFFF#, "byte_15_to_19");
         Check (Byte_20_To_27 (This) = 16#FFFFFFFFFFFFFFFF#, "byte_20_to_27");
         Check (Has_Test_If_B1 (This) and then Test_If_B1 (This) = 123, "test_if_b1");
      end if;

      S := Open (Sample_Fixed_Struct (1 .. 27));
      Parse (This, Sample_Fixed_Struct (1 .. 27), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a file one byte short is rejected");
   end Test_Bits_Simple;

   --  Bit fields in types and in repetitions: a type that starts with bit fields goes on in the byte that the bit
   --  fields before it left open

   procedure Test_Bits_In_Types is
      use Bits_In_Types;
      Data   : constant Bytes := (16#AB#, 16#CD#);
      S      : Stream := Open (Data);
      This   : Bits_In_Types.T;
      Target : Bytes (1 .. 2) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples bits_in_types");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 2, "parses two bytes");
      if Valid (This) then
         Check (A (This) = 16#A#, "a");
         Check (Child_Type.Lo (C (This)) = 16#B#, "c.lo is in the byte that a left open");
         Check (D (This) = 16#CD#, "d");
         Write (This, Target, W);
         Check (Kaitai.Writers.OK (W) and then Size (Kaitai.Writers.Written (W)) = 2 and then Target = Data, "written");
      end if;

      S := Open (Data (1 .. 1));
      Parse (This, Data (1 .. 1), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a file one byte short is rejected");
   end Test_Bits_In_Types;

   procedure Test_Bits_In_Repeat is
      use Bits_In_Repeat;
      Data    : constant Bytes := (16#AB#, 16#CD#, 16#EF#, 16#12#);
      Expect  : constant array (Length range 0 .. 2) of U64 := (16#B#, 16#C#, 16#D#);
      S       : Stream := Open (Data);
      This    : Bits_In_Repeat.T;
      Element : Nib_Type.T;
      Target  : Bytes (1 .. 4) := (others => 16#EE#);
      W       : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples bits_in_repeat");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 3, "parses three bytes");
      if Valid (This) then
         Check (A (This) = 16#A#, "a");
         Check (Items_Count (This) = 3, "three items");
         for I in Expect'Range loop
            Get_Items (This, Data, I, Element);
            Check (Nib_Type.Valid (Element) and then Nib_Type.Lo (Element) = Expect (I), "item");
         end loop;
         Check (D (This) = 16#EF#, "d");
         Write (This, Data, Target, W);
         Check
           (Kaitai.Writers.OK (W)
            and then Size (Kaitai.Writers.Written (W)) = 3
            and then Target (1 .. 3) = Data (1 .. 3),
            "written");
      end if;
   end Test_Bits_In_Repeat;

   procedure Test_Bits_After_Bytes is
      use Bits_After_Bytes;
      Data   : constant Bytes := (16#11#, 16#B6#, 16#2A#, 16#07#);
      S      : Stream := Open (Data);
      This   : Bits_After_Bytes.T;
      Target : Bytes (1 .. 4) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples bits_after_bytes");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 4, "parses four bytes");
      if Valid (This) then
         Check (Tag (This) = 16#11#, "tag");
         Check (Header_Type.Valid (Head (This)), "head");
         Check
           (Flags_Type_Type.Ready (Header_Type.Flags (Head (This)))
            and then Flags_Type_Type.Mode (Header_Type.Flags (Head (This))) = 3,
            "head.flags");
         Check (Header_Type.Level (Head (This)) = 6, "head.level goes on in the byte that flags left open");
         Check (Header_Type.Size (Head (This)) = 16#2A#, "head.size");
         Check (Tail (This) = 7, "tail");
         Write (This, Target, W);
         Check (Kaitai.Writers.OK (W) and then Size (Kaitai.Writers.Written (W)) = 4 and then Target = Data, "written");
      end if;
   end Test_Bits_After_Bytes;

   procedure Test_Bits_First_Type is
      use Bits_First_Type;
      Data   : constant Bytes := (16#B6#, 16#2A#, 16#07#);
      S      : Stream := Open (Data);
      This   : Bits_First_Type.T;
      Target : Bytes (1 .. 3) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples bits_first_type");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 3, "parses three bytes");
      if Valid (This) then
         Check
           (Flags_Type_Type.Ready (Header_Type.Flags (Head (This)))
            and then Flags_Type_Type.Mode (Header_Type.Flags (Head (This))) = 3,
            "head.flags");
         Check (Header_Type.Level (Head (This)) = 6, "head.level");
         Check (Header_Type.Size (Head (This)) = 16#2A#, "head.size");
         Check (Tail (This) = 7, "tail");
         Write (This, Target, W);
         Check (Kaitai.Writers.OK (W) and then Size (Kaitai.Writers.Written (W)) = 3 and then Target = Data, "written");
      end if;
   end Test_Bits_First_Type;

   procedure Test_Term_Strz is
      use Term_Strz;
      S    : Stream := Open (Sample_Term_Strz);
      This : Term_Strz.T;

      function Text (Item : Slice) return String is
         Result : String (1 .. Natural (Size (Item)));
      begin
         for I in Result'Range loop
            Result (I) := Character'Val (Sample_Term_Strz (Item.First + Length (I) - 1));
         end loop;
         return Result;
      end Text;
   begin
      Group ("examples term_strz");
      Parse (This, Sample_Term_Strz, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Text (S1 (This)) = "foo", "s1");
         Check (Text (S2 (This)) = "bar", "s2");
         Check (Text (S3 (This)) = "|baz@", "s3");
      end if;
      Check (Is_EOF (S), "the whole file is consumed");

      S := Open (Sample_Term_Strz (1 .. 11));
      Parse (This, Sample_Term_Strz (1 .. 11), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a missing terminator is rejected");
   end Test_Term_Strz;

   function Text (Data : Bytes; Item : Slice) return String is
      Result : String (1 .. Natural (Size (Item)));
   begin
      for I in Result'Range loop
         Result (I) := Character'Val (Data (Item.First + Length (I) - 1));
      end loop;
      return Result;
   end Text;

   procedure Test_Repeat_N_Struct is
      use Repeat_N_Struct;
      Data     : Bytes renames Sample_Data.Repeat_N_Struct;
      S        : Stream := Open (Data);
      This     : Repeat_N_Struct.T;
      C        : Chunk_Type.T;
      Position : Chunks_Cursor;
      Seen     : Natural := 0;
      Bad      : Natural := 0;
   begin
      Group ("examples repeat_n_struct");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Qty (This) = 2 and then Chunks_Count (This) = 2, "count");
         Get_Chunks (This, Data, 0, C);
         Check
           (Chunk_Type.Valid (C) and then Chunk_Type.Offset (C) = 16#10# and then Chunk_Type.Len (C) = 16#2078#,
            "chunks[0]");
         Get_Chunks (This, Data, 1, C);
         Check
           (Chunk_Type.Valid (C) and then Chunk_Type.Offset (C) = 16#2088# and then Chunk_Type.Len (C) = 16#F#,
            "chunks[1]");
         Position := Chunks_First (This);
         while Has_Element (Position) loop
            pragma Loop_Variant (Decreases => Remaining (Position));
            pragma Loop_Invariant (Belongs_To (Position, Data));
            Next (This, Data, Position, C);
            exit when not Chunk_Type.Valid (C);
            Seen := Seen + 1;
         end loop;
         Check (Seen = 2, "cursor");
      end if;
      for Last in 0 .. Data'Last - 1 loop
         S := Open (Data (1 .. Last));
         Parse (This, Data (1 .. Last), S);
         if Valid (This) then
            Bad := Bad + 1;
         end if;
      end loop;
      Check (Bad = 0, "every shorter input fails");
   end Test_Repeat_N_Struct;

   --  A count from the data with elements that can be empty.  With a length of zero the hundred million elements
   --  read nothing; a parser that went through all of them would not come back in the time a test has, least of
   --  all on the simulated target.
   procedure Test_Repeat_N_Empty is
      use Repeat_N_Empty;
      Many  : constant Bytes (1 .. 6) := (16#00#, 16#00#, 16#E1#, 16#F5#, 16#05#, 16#7F#);
      Huge  : constant Bytes (1 .. 6) := (16#00#, 16#FF#, 16#FF#, 16#FF#, 16#7F#, 16#7F#);
      Three : constant Bytes (1 .. 9) := (16#01#, 16#03#, 16#00#, 16#00#, 16#00#, 16#61#, 16#62#, 16#63#, 16#7F#);
      S     : Stream := Open (Many);
      This  : Repeat_N_Empty.T;
      E     : Item_Type.T;
   begin
      Group ("examples repeat_n_empty");
      Parse (This, Many, S);
      Check (Valid (This) and then Is_EOF (S), "a hundred million empty elements parse at once");
      if Valid (This) then
         Check (Qty (This) = 100_000_000 and then Items_Count (This) = 100_000_000, "the count is what the data say");
         Check (Tail (This) = 16#7F#, "the field after the repetition");
         Get_Items (This, Many, 0, E);
         Check (Item_Type.Valid (E) and then Is_Empty (Item_Type.Content (E)), "items[0] is empty");
         Get_Items (This, Many, 2, E);
         Check (Item_Type.Valid (E) and then Is_Empty (Item_Type.Content (E)), "items[2] is empty");
         Get_Items (This, Many, Items_Count (This) - 1, E);
         Check (Item_Type.Valid (E) and then Is_Empty (Item_Type.Content (E)), "the last of 100 million is empty");
      end if;

      --  A count of 2**31 - 1, the largest Length of the target, and no byte for any element: Get_Items stops at the
      --  first element, as Parse did, and does not go through two billion
      S := Open (Huge);
      Parse (This, Huge, S);
      Check (Valid (This) and then Is_EOF (S), "two billion empty elements parse at once");
      if Valid (This) then
         Check (Items_Count (This) = 2_147_483_647, "the count is what the data say");
         Get_Items (This, Huge, Items_Count (This) - 1, E);
         Check (Item_Type.Valid (E) and then Is_Empty (Item_Type.Content (E)), "the last of two billion is empty");
         declare
            Position : Items_Cursor := Items_First (This);
         begin
            Next (This, Huge, Position, E);
            Check (Item_Type.Valid (E) and then Remaining (Position) = 2_147_483_646, "Next goes one element on");
         end;
      end if;

      S := Open (Three);
      Parse (This, Three, S);
      Check (Valid (This) and then Is_EOF (S), "three elements of one byte");
      if Valid (This) then
         Check (Items_Count (This) = 3 and then Tail (This) = 16#7F#, "count and the field after");
         Get_Items (This, Three, 0, E);
         Check
           (Item_Type.Valid (E)
            and then Size (Item_Type.Content (E)) = 1
            and then Three (Item_Type.Content (E).First) = 16#61#,
            "items[0]");
         Get_Items (This, Three, 2, E);
         Check
           (Item_Type.Valid (E)
            and then Size (Item_Type.Content (E)) = 1
            and then Three (Item_Type.Content (E).First) = 16#63#,
            "items[2]");
      end if;

      --  the count says three, the data hold two
      S := Open (Three (1 .. 7));
      Parse (This, Three (1 .. 7), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "too few elements");
   end Test_Repeat_N_Empty;

   procedure Test_Repeat_Bits is
      use Repeat_Bits;
      Data   : constant Bytes (1 .. 8) := (16#03#, 16#00#, 16#00#, 16#00#, 16#AB#, 16#C0#, 16#7F#, 16#A5#);
      Flags  : constant array (Length range 0 .. 7) of Boolean := (True, False, True, False, False, True, False, True);
      Huge   : constant Bytes (1 .. 6) := (16#FF#, 16#FF#, 16#FF#, 16#7F#, 16#AB#, 16#C0#);
      S      : Stream := Open (Data);
      This   : Repeat_Bits.T;
      N      : Kaitai.Types.U64;
      Flag   : Boolean;
      Target : Bytes (1 .. 8) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples repeat_bits");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses all eight bytes");
      if Valid (This) then
         Check (Nibbles_Count (This) = 3 and then Tail (This) = 16#7F# and then Flags_Count (This) = 8, "counts");
         Get_Nibbles (This, Data, 0, N);
         Check (N = 16#A#, "nibbles[0]");
         Get_Nibbles (This, Data, 2, N);
         Check (N = 16#C#, "nibbles[2]");
         declare
            Position : Nibbles_Cursor := Nibbles_First (This);
            Sum      : Kaitai.Types.U64 := 0;
         begin
            while Has_Element (Position) loop
               Next (This, Data, Position, N);
               Sum := Sum + N;
            end loop;
            Check (Sum = 16#A# + 16#B# + 16#C#, "Next goes through the nibbles");
         end;
         for I in Flags'Range loop
            Get_Flags (This, Data, I, Flag);
            Check (Flag = Flags (I), "flags[i]");
         end loop;
         Write (This, Data, Target, W);
         Check (Kaitai.Writers.OK (W) and then Size (Kaitai.Writers.Written (W)) = 8 and then Target = Data, "written");
      end if;

      --  A count of 2**31 - 1 and bytes for three nibbles: the bits end at the end of the data, as the loop does
      S := Open (Huge);
      Parse (This, Huge, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a huge count of nibbles in six bytes");

      S := Open (Data (1 .. 4));
      Parse (This, Data (1 .. 4), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "the nibbles are missing");
   end Test_Repeat_Bits;

   procedure Test_Repeat_Index is
      use Repeat_Index;
      Data   : constant Bytes (1 .. 13) :=
        (16#03#, 16#00#, 16#00#, 16#00#, 16#02#, 16#00#, 16#01#, 16#61#, 16#62#, 16#63#, 16#11#, 16#22#, 16#22#);
      Huge   : constant Bytes (1 .. 6) := (16#FF#, 16#FF#, 16#FF#, 16#7F#, 16#01#, 16#02#);
      Short  : constant Bytes (1 .. 7) := (16#02#, 16#00#, 16#00#, 16#00#, 16#05#, 16#05#, 16#61#);
      S      : Stream := Open (Data);
      This   : Repeat_Index.T;
      Buf    : Slice;
      Row    : Row_Type.T;
      Target : Bytes (1 .. 13) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples repeat_index");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses all thirteen bytes");
      if Valid (This) then
         Check (Bufs_Count (This) = 3 and then Rows_Count (This) = 3, "counts");
         Get_Bufs (This, Data, 0, Buf);
         Check (Size (Buf) = 2 and then Data (Buf.First) = 16#61#, "bufs[0] has the size sizes[0]");
         Get_Bufs (This, Data, 1, Buf);
         Check (Size (Buf) = 0, "bufs[1] is empty");
         Get_Bufs (This, Data, 2, Buf);
         Check (Size (Buf) = 1 and then Data (Buf.First) = 16#63#, "bufs[2]");
         Get_Rows (This, Data, 0, Row);
         Check (Row_Type.Valid (Row) and then Row_Type.N (Row) = 0 and then Size (Row_Type.Cells (Row)) = 0, "rows[0]");
         Get_Rows (This, Data, 2, Row);
         Check
           (Row_Type.Valid (Row) and then Row_Type.N (Row) = 2 and then Size (Row_Type.Cells (Row)) = 2,
            "rows[2] has two bytes: its element knows that it is the third");
         Write (This, Data, Target, W);
         Check
           (Kaitai.Writers.OK (W) and then Size (Kaitai.Writers.Written (W)) = 13 and then Target = Data, "written");
      end if;

      --  A count of 2**31 - 1 and no bytes for it: the sizes are not there
      S := Open (Huge);
      Parse (This, Huge, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a huge count in six bytes");

      --  The size of the first element is beyond the data
      S := Open (Short);
      Parse (This, Short, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "an element beyond the data");
   end Test_Repeat_Index;

   procedure Test_Repeat_Eos_U4 is
      use Repeat_Eos_U4;
      Data : Bytes renames Sample_Data.Repeat_Eos_Struct;
      S    : Stream := Open (Data);
      This : Repeat_Eos_U4.T;
   begin
      Group ("examples repeat_eos_u4");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Numbers_Count (This) = 4, "count");
         Check
           (Numbers (This, Data, 0) = 0
            and then Numbers (This, Data, 1) = 16#42#
            and then Numbers (This, Data, 2) = 16#42#
            and then Numbers (This, Data, 3) = 16#815#,
            "elements");
      end if;
      S := Open (Data (1 .. 15));
      Parse (This, Data (1 .. 15), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "an incomplete element is rejected");
   end Test_Repeat_Eos_U4;

   procedure Test_Repeat_Until_Complex is
      use Repeat_Until_Complex;
      Data : Bytes renames Sample_Data.Repeat_Until_Complex;
      S    : Stream := Open (Data);
      This : Repeat_Until_Complex.T;
      U1   : Type_U1_Type.T;
      U2   : Type_U2_Type.T;
   begin
      Group ("examples repeat_until_complex");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (First_Count (This) = 3, "first: count includes the last element");
         Get_First (This, Data, 0, U1);
         Check
           (Type_U1_Type.Valid (U1)
            and then Type_U1_Type.Count (U1) = 4
            and then Type_U1_Type.Values_Count (U1) = 4
            and then Type_U1_Type.Values (U1, Data, 0) = 1
            and then Type_U1_Type.Values (U1, Data, 3) = 4,
            "first[0]");
         Get_First (This, Data, 1, U1);
         Check (Type_U1_Type.Valid (U1) and then Type_U1_Type.Count (U1) = 2, "first[1]");
         Get_First (This, Data, 2, U1);
         Check (Type_U1_Type.Valid (U1) and then Type_U1_Type.Count (U1) = 0, "first[2] ends it");
         Check (Second_Count (This) = 4, "second: count");
         Get_Second (This, Data, 0, U2);
         Check
           (Type_U2_Type.Valid (U2) and then Type_U2_Type.Count (U2) = 6 and then Type_U2_Type.Values (U2, Data, 5) = 6,
            "second[0]");
         Get_Second (This, Data, 3, U2);
         Check (Type_U2_Type.Valid (U2) and then Type_U2_Type.Count (U2) = 0, "second[3] ends it");
         Check (Third_Count (This) = 7, "third: count, a repetition of integers up to a condition");
         Check
           (Third (This, Data, 0) = 102 and then Third (This, Data, 5) = 114 and then Third (This, Data, 6) = 0,
            "third: elements");
      end if;
      S := Open (Data (1 .. 49));
      Parse (This, Data (1 .. 49), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "input that ends before the condition holds");
   end Test_Repeat_Until_Complex;

   procedure Test_Switch_Manual_Int is
      use Switch_Manual_Int;
      use type Opcode_Type.Body_Kind;
      Data     : Bytes renames Sample_Data.Switch_Opcodes;
      S        : Stream := Open (Data);
      This     : Switch_Manual_Int.T;
      O        : Opcode_Type.T;
      Position : Opcodes_Cursor;
      Seen     : Natural := 0;
   begin
      Group ("examples switch_manual_int");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Opcodes_Count (This) = 4, "count");
         Get_Opcodes (This, Data, 0, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Code (O) = 83
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Strval
            and then Text (Data, Opcode_Type.Strval_Type.Value (Opcode_Type.Body_As_Strval (O))) = "foobar",
            "opcodes[0] is a string");
         Get_Opcodes (This, Data, 1, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Intval
            and then Opcode_Type.Intval_Type.Value (Opcode_Type.Body_As_Intval (O)) = 16#42#,
            "opcodes[1] is an integer");
         Get_Opcodes (This, Data, 2, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Intval
            and then Opcode_Type.Intval_Type.Value (Opcode_Type.Body_As_Intval (O)) = 16#37#,
            "opcodes[2]");
         Get_Opcodes (This, Data, 3, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Strval
            and then Is_Empty (Opcode_Type.Strval_Type.Value (Opcode_Type.Body_As_Strval (O))),
            "opcodes[3] is an empty string");
         Position := Opcodes_First (This);
         while Has_Element (Position) loop
            pragma Loop_Variant (Decreases => Remaining (Position));
            pragma Loop_Invariant (Belongs_To (Position, Data));
            Next (This, Data, Position, O);
            exit when not Opcode_Type.Valid (O);
            Seen := Seen + 1;
         end loop;
         Check (Seen = 4, "cursor");
      end if;
   end Test_Switch_Manual_Int;

   procedure Test_Enum_0 is
      use Enum_0;
      Data : Bytes renames Sample_Data.Enum_0;
      S    : Stream := Open (Data);
      This : Enum_0.T;
   begin
      Group ("examples enum_0");
      Parse (This, Data, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Pet_1_Value (This) = 7 and then Pet_1 (This) = Animal_Cat, "pet_1");
         Check (Pet_2_Value (This) = 12 and then Pet_2 (This) = Animal_Chicken, "pet_2");
         Check (To_Integer (Animal_Dog) = 4, "integer of a literal");
      end if;
   end Test_Enum_0;

   procedure Test_If_Struct is
      use If_Struct;
      Data : Bytes renames Sample_Data.If_Struct;
      S    : Stream := Open (Data);
      This : If_Struct.T;
   begin
      Group ("examples if_struct");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Operation_Type.Opcode (Op1 (This)) = 16#53#, "op1.opcode");
         Check (not Operation_Type.Has_Arg_Tuple (Op1 (This)), "op1.arg_tuple is absent");
         Check
           (Operation_Type.Has_Arg_Str (Op1 (This))
            and then Text (Data, Arg_Str_Type.Str (Operation_Type.Arg_Str (Op1 (This)))) = "foo",
            "op1.arg_str");
         Check
           (Operation_Type.Has_Arg_Tuple (Op2 (This))
            and then Arg_Tuple_Type.Num1 (Operation_Type.Arg_Tuple (Op2 (This))) = 16#42#
            and then Arg_Tuple_Type.Num2 (Operation_Type.Arg_Tuple (Op2 (This))) = 16#43#
            and then not Operation_Type.Has_Arg_Str (Op2 (This)),
            "op2.arg_tuple");
         Check
           (Operation_Type.Has_Arg_Str (Op3 (This))
            and then Text (Data, Arg_Str_Type.Str (Operation_Type.Arg_Str (Op3 (This)))) = "bar",
            "op3.arg_str");
      end if;
   end Test_If_Struct;

   procedure Test_Expr_1 is
      use Expr_1;
      Data : Bytes renames Sample_Data.Str_Encodings;
      S    : Stream := Open (Data);
      This : Expr_1.T;
      Bad  : Bytes := Data;
   begin
      Group ("examples expr_1");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 10, "parses");
      if Valid (This) then
         Check (Len_Of_1 (This) = 10, "len_of_1");
         Check (Len_Of_1_Mod (This) = 8, "instance with a value");
         Check (Text (Data, Str1 (This)) = "Some ASC", "size from an instance");
         Check (Str1_Len (This, Data) = 8, "length of a string");
      end if;
      Bad (1) := 1;
      Bad (2) := 0;
      S := Open (Bad);
      Parse (This, Bad, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a negative size fails");
      Bad (1) := 2;
      S := Open (Bad);
      Parse (This, Bad, S);
      Check (Valid (This) and then Len_Of_1_Mod (This) = 0, "an empty string");
   end Test_Expr_1;

   procedure Test_Params_Def is
      use Params_Def;
      Data : constant Bytes (1 .. 4) := (16#61#, 16#62#, 16#63#, 16#58#);
      Bad  : constant Bytes (1 .. 4) := (16#61#, 16#FF#, 16#63#, 16#58#);
      S    : Stream := Open (Data);
      This : Params_Def.T;
   begin
      Group ("examples params_def");
      Parse (This, Data, S, 3, True);
      Check (Valid (This) and then Is_EOF (S), "parses with a trailer");
      if Valid (This) then
         Check (Len (This) = 3 and then Has_Trailer_Field (This), "the parameters are kept");
         Check (Text (Data, Buf (This)) = "abc", "size from a parameter");
         Check (Has_Trailer (This) and then Trailer (This) = 16#58#, "field with a condition on a parameter");
      end if;
      S := Open (Data);
      Parse (This, Data, S, 3, False);
      Check (Valid (This) and then not Has_Trailer (This) and then Pos (S) = 3, "parses without a trailer");
      S := Open (Data);
      Parse (This, Data, S, 5, False);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a size beyond the input fails");
      S := Open (Bad);
      Parse (This, Bad, S, 3, True);
      Check (not Valid (This) and then Status (S) = Illegal_Sequence, "the string is checked as UTF-8");
   end Test_Params_Def;

   procedure Test_Outside is
      use Outside;
      Data  : constant Bytes (1 .. 16) :=
        (16#66#, 16#6F#, 16#6F#, 2, 3, 16#78#, 16#79#, 16#7A#, 1, 2, 3, 4, 5, 6, 16#6E#, 16#6F#);
      Other : Bytes (1 .. 16) := Data;
      Short : constant Bytes (1 .. 12) := Data (1 .. 12);
      S     : Stream := Open (Data);
      This  : Outside.T;
   begin
      Group ("examples outside");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses");
      if Valid (This) then
         Check (Size (Item_Type.Body_Field (Item (This))) = 3, "size from the length of a string of the parent");
         Check (Size (Item_Type.Pixels (Item (This))) = 6, "size from two integers of a value of the parent");
         Check (Note_Type.From_Foo (Note (This)), "the string of the parent is foo");
      end if;
      Other (1) := 16#62#;
      S := Open (Other);
      Parse (This, Other, S);
      if Valid (This) then
         Check (not Note_Type.From_Foo (Note (This)), "the string of the parent is not foo");
      else
         Check (False, "parses another name");
      end if;
      S := Open (Short);
      Parse (This, Short, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a size from the header beyond the input fails");
   end Test_Outside;

   procedure Test_Instance_Std is
      use Instance_Std;
      Data    : constant Bytes (1 .. 9) := (16#78#, 16#78#, 16#48#, 16#45#, 16#4C#, 16#4C#, 16#4F#, 16#79#, 16#79#);
      S       : Stream := Open (Data);
      This    : Instance_Std.T;
      Result  : Slice;
      Outcome : Status_Kind;
   begin
      Group ("examples instance_std");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 0, "parses; the type has no fields in sequence");
      Header (This, Data, Result, Outcome);
      Check (Outcome = Success and then Text (Data, Result) = "HELLO", "instance with a position and a size");
      S := Open (Data (1 .. 5));
      Parse (This, Data (1 .. 5), S);
      Header (This, Data (1 .. 5), Result, Outcome);
      Check (Outcome = End_Of_Stream and then Is_Empty (Result), "the instance runs out of bytes");
   end Test_Instance_Std;

   --  A parse instance that expressions of the sequence need is parsed once, where it is first needed, and kept: the
   --  count of the records and the size of the body come from `header`, which is in the last bytes, and the end of the
   --  numbers from `limit`, which lies two bytes after the first number.  The count is a number of the data and the
   --  input is tiny: the loop ends at the first record that cannot be read.
   procedure Test_Instance_Kept is
      use Instance_Kept;
      Data   : Bytes renames Sample_Data.Instance_Kept;
      Huge   : constant Bytes (1 .. 6) := (16#01#, 16#FF#, 16#FF#, 16#FF#, 16#7F#, 16#00#);
      Short  : constant Bytes (1 .. 4) := (16#01#, 16#02#, 16#03#, 16#04#);
      No_End : constant Bytes (1 .. 5) := (16#00#, 16#00#, 16#00#, 16#00#, 16#00#);
      S      : Stream := Open (Data);
      This   : Instance_Kept.T;
      Rec    : Record_Type.T;
   begin
      Group ("examples instance_kept");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 12, "parses up to the header, which no field reads");
      if Valid (This) then
         Check
           (Header_Type_Type.Count (Header (This)) = 2 and then Header_Type_Type.Body_Len (Header (This)) = 2,
            "the instance is kept and its accessor returns it");
         Check (Records_Count (This) = 2, "the count of the records is the field of the instance");
         Get_Records (This, Data, 1, Rec);
         Check (Record_Type.Valid (Rec) and then Record_Type.Key (Rec) = 2, "records[1]");
         Check (Has_Len_Body (This) and then Len_Body (This) = 4, "a value instance of a kept instance");
         Check (Size (Body_Field (This)) = 4 and then Data (Body_Field (This).First) = 16#41#, "the size of the body");
         Check (Limit (This) = 5, "limit was read after the first number, two bytes further");
         Check
           (Numbers_Count (This) = 3 and then Numbers (This, Data, 0) = 7 and then Numbers (This, Data, 2) = 5,
            "the numbers end where one equals the limit");
      end if;

      S := Open (Huge);
      Parse (This, Huge, S);
      Check
        (not Valid (This) and then Status (S) = End_Of_Stream, "a count of 2**31-1 in a tiny input ends at the data");

      S := Open (Short);
      Parse (This, Short, S);
      Check (not Valid (This), "the header does not fit into the input");

      S := Open (No_End);
      Parse (This, No_End, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "the limit lies beyond the input");
   end Test_Instance_Kept;

   procedure Test_Position_Abs is
      use Position_Abs;
      Data    : Bytes renames Sample_Data.Position_Abs;
      S       : Stream := Open (Data);
      This    : Position_Abs.T;
      Index_V : Index_Obj_Type.T;
      Outcome : Status_Kind;
   begin
      Group ("examples position_abs");
      Parse (This, Data, S);
      Check (Valid (This) and then Index_Offset (This) = 16#20#, "parses");
      if Valid (This) then
         Position_Abs.Index (This, Data, Index_V, Outcome);
         Check
           (Outcome = Success
            and then Index_Obj_Type.Valid (Index_V)
            and then Text (Data, Index_Obj_Type.Entry_Field (Index_V)) = "foo",
            "instance at an absolute position");
      end if;
      S := Open (Data (1 .. 20));
      Parse (This, Data (1 .. 20), S);
      if Valid (This) then
         Position_Abs.Index (This, Data (1 .. 20), Index_V, Outcome);
         Check
           (Outcome = End_Of_Stream and then not Index_Obj_Type.Valid (Index_V), "a position beyond the input fails");
      else
         Check (False, "short input parses");
      end if;
   end Test_Position_Abs;

   procedure Test_Valid_Fail_Eq_Int is
      use Valid_Fail_Eq_Int;
      Data : Bytes := Sample_Data.Fixed_Struct;
      S    : Stream := Open (Data);
      This : Valid_Fail_Eq_Int.T;
   begin
      Group ("examples valid_fail_eq_int");
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Validation_Not_Equal, "0x50 is not 123");
      Data (1) := 123;
      S := Open (Data);
      Parse (This, Data, S);
      Check (Valid (This) and then Foo (This) = 123, "123 is accepted");
   end Test_Valid_Fail_Eq_Int;

   procedure Test_Default_Endian is
      use Default_Endian_Expr_Is_Le;
      Data     : Bytes renames Sample_Data.Endian_Expr;
      S        : Stream := Open (Data);
      This     : Default_Endian_Expr_Is_Le.T;
      D        : Doc_Type.T;
      Position : Docs_Cursor;
      Seen     : Natural := 0;
      Good     : Natural := 0;
   begin
      Group ("examples default_endian_expr_is_le");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Docs_Count (This) = 3, "count");
         Position := Docs_First (This);
         while Has_Element (Position) loop
            pragma Loop_Variant (Decreases => Remaining (Position));
            pragma Loop_Invariant (Belongs_To (Position, Data));
            Next (This, Data, Position, D);
            exit when not Doc_Type.Valid (D);
            Seen := Seen + 1;
            declare
               M : constant Doc_Type.Main_Obj_Type.T := Doc_Type.Main (D);
            begin
               if Doc_Type.Main_Obj_Type.Some_Int (M) = 16#42#
                 and then Doc_Type.Main_Obj_Type.Some_Int_Be (M) = 16#42#
                 and then Doc_Type.Main_Obj_Type.Some_Int_Le (M) = 16#42#
               then
                  Good := Good + 1;
               end if;
            end;
         end loop;
         Check (Seen = 3 and then Good = 3, "the calculated byte order decides the integers of the nested type");
      end if;
   end Test_Default_Endian;

   procedure Test_Str_Encodings is
      use Str_Encodings;
      Data : Bytes := Sample_Data.Str_Encodings;
      S    : Stream := Open (Data);
      This : Str_Encodings.T;
   begin
      Group ("examples str_encodings");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Text (Data, Str1 (This)) = "Some ASCII", "ASCII");
         Check (Size (Str2 (This)) = 15, "UTF-8");
         Check (Size (Str3 (This)) = 10, "SJIS, one byte per character for the library");
         Check (Size (Str4 (This)) = 3, "IBM437");
      end if;
      Data (3) := 16#80#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Illegal_Sequence, "a byte above 127 is not ASCII");
      Data := Sample_Data.Str_Encodings;
      Data (16) := 16#FF#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Illegal_Sequence, "0xFF is not UTF-8");
   end Test_Str_Encodings;

   procedure Test_Bits_Enum is
      use Bits_Enum;
      Data : Bytes renames Sample_Data.Fixed_Struct;
      S    : Stream := Open (Data);
      This : Bits_Enum.T;
   begin
      Group ("examples bits_enum");
      Parse (This, Data, S);
      Check (Valid (This) and then Pos (S) = 2, "parses");
      if Valid (This) then
         Check (One_Value (This) = 5 and then One (This) = Animal_Platypus, "one");
         Check (Two_Value (This) = 4 and then Two (This) = Animal_Horse, "two");
         Check (Three_Value (This) = 0 and then Three (This) = Animal_Cat, "three");
      end if;
   end Test_Bits_Enum;

   procedure Test_Bits_Byte_Aligned is
      use Bits_Byte_Aligned;
      Data : Bytes renames Sample_Data.Fixed_Struct;
      S    : Stream := Open (Data);
      This : Bits_Byte_Aligned.T;
   begin
      Group ("examples bits_byte_aligned");
      Parse (This, Data, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (One (This) = 2#010100# and then Byte_1 (This) = 16#41#, "one, byte_1");
         Check (Two (This) = 2#010# and then not Three (This), "two, three");
         Check (Size (Byte_2 (This)) = 1 and then Data (Byte_2 (This).First) = 16#4B#, "byte_2");
         Check (Four (This) = 2#00101101_001100#, "four");
         Check (Foo_Type.Inner (Byte_3 (This)) = 2#11111111_11111111_010#, "byte_3.inner");
         Check (Full_Byte (This) = 16#41# and then Byte_4 (This) = 16#43#, "full_byte, byte_4");
         Check (Five (This) = 2#01001011_00101101_010101#, "five");
         Check (Text (Data, Bytes_Term (This)) = "-DE", "bytes_term");
         Check (Six (This) = 16#46#, "six");
      end if;
   end Test_Bits_Byte_Aligned;

   procedure Test_Bytes_Pad_Term_Equal is
      use Bytes_Pad_Term_Equal;
      Data : Bytes renames Sample_Data.Str_Pad_Term;
      S    : Stream := Open (Data);
      This : Bytes_Pad_Term_Equal.T;
   begin
      Group ("examples bytes_pad_term_equal");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses");
      if Valid (This) then
         Check (Text (Data, S1 (This)) = "str1", "padding that is the terminator is not stripped first");
         Check (Text (Data, S2 (This)) = "str2foo@", "terminator included, other padding");
         Check (Text (Data, S3 (This)) = "str", "terminator that is the padding");
         Check (Text (Data, S4 (This)) = "str4baz@.", "terminator included, and the same padding");
      end if;
   end Test_Bytes_Pad_Term_Equal;

   procedure Test_Expr_Sizeof_Type_0 is
      use Expr_Sizeof_Type_0;
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Expr_Sizeof_Type_0.T;
   begin
      Group ("examples expr_sizeof_type_0");
      Parse (This, Sample_Fixed_Struct, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Sizeof_Block (This) = 7, "the size of a type is in bytes");
      end if;
   end Test_Expr_Sizeof_Type_0;

   procedure Test_Expr_Sizeof_Value_Sized is
      use Expr_Sizeof_Value_Sized;
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Expr_Sizeof_Value_Sized.T;
   begin
      Group ("examples expr_sizeof_value_sized");
      Parse (This, Sample_Fixed_Struct, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Self_Sizeof (This) = 12 + 2, "_sizeof is the size of the type, with the size of the field it is in");
         Check (Sizeof_Block (This) = 12, "the size of a field with a size is that size");
         Check (Sizeof_Block_A (This) = 1, "the size of an integer");
         Check (Sizeof_Block_B (This) = 4, "the size of a larger integer");
         Check (Sizeof_Block_C (This) = 2, "the size of bytes with a size");
      end if;
   end Test_Expr_Sizeof_Value_Sized;

   procedure Test_Term_Struct is
      use Term_Struct;
      Data : Bytes renames Sample_Term_Strz;
      S    : Stream := Open (Data);
      This : Term_Struct.T;
   begin
      Group ("examples term_struct");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses");
      if Valid (This) then
         Check (Text (Data, Bytes_Wrapper_Type.Value (S1 (This))) = "foo", "s1");
         Check (Text (Data, Bytes_Wrapper_Type.Value (S2 (This))) = "bar", "s2, terminator not consumed");
         Check (Text (Data, Bytes_Wrapper_Type.Value (S3 (This))) = "|baz@", "s3, terminator included");
      end if;

      S := Open (Data (1 .. 11));
      Parse (This, Data (1 .. 11), S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a missing terminator is rejected");
   end Test_Term_Struct;

   procedure Test_Imports0 is
      use Imports0;
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Imports0.T;
   begin
      Group ("examples imports0");
      Parse (This, Sample_Fixed_Struct, S);
      Check (Valid (This) and then Pos (S) = 2, "parses");
      if Valid (This) then
         Check (Two (This) = 16#50#, "two");
         Check (Hello_World.One (Hw (This)) = 16#41#, "a field of the type of another description");
         Check (Has_Hw_One (This) and then Hw_One (This) = 16#41#, "an instance that uses it");
      end if;
   end Test_Imports0;

   --  Round trips: parse a sample, write the value, compare with the sample

   procedure Test_Write_Bits_Enum is
      Data   : Bytes renames Sample_Data.Fixed_Struct;
      S      : Stream := Open (Data);
      This   : Bits_Enum.T;
      Target : Bytes (1 .. 8) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write bits_enum");
      Bits_Enum.Parse (This, Data, S);
      if Bits_Enum.Valid (This) then
         Bits_Enum.Write (This, Target, W);
         Check (Kaitai.Writers.OK (W) and then Size (Kaitai.Writers.Written (W)) = 2, "two bytes are written");
         --  The three bits of the second byte that no field reads are written as zero
         Check
           (Target (1) = Data (1) and then (Target (2) and 16#F8#) = (Data (2) and 16#F8#), "the bits that were read");
         Check ((Target (2) and 16#07#) = 0, "and zero for the others");
      else
         Check (False, "parses");
      end if;
   end Test_Write_Bits_Enum;

   procedure Test_Write_Bits_Byte_Aligned is
      use Bits_Byte_Aligned;
      Data   : Bytes renames Sample_Data.Fixed_Struct;
      S      : Stream := Open (Data);
      This   : Bits_Byte_Aligned.T;
      Again  : Bits_Byte_Aligned.T;
      Target : Bytes (1 .. 40) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write bits_byte_aligned");
      Parse (This, Data, S);
      if Valid (This) then
         Write (This, Data, Target, W);
         Check (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = Pos (S), "as many bytes as were read");
         --  Bits that no field reads (the description skips some) are written as zero, so the bytes are not
         --  the same; what is written reads back as the same values
         declare
            Last : constant Length := Kaitai.Writers.Pos (W);
            S2   : Stream := Open (Target (1 .. Last));
         begin
            Parse (Again, Target (1 .. Last), S2);
            Check (Valid (Again), "the output parses");
            if Valid (Again) then
               Check
                 (One (Again) = One (This)
                  and then Byte_1 (Again) = Byte_1 (This)
                  and then Two (Again) = Two (This)
                  and then Three (Again) = Three (This)
                  and then Four (Again) = Four (This)
                  and then Foo_Type.Inner (Byte_3 (Again)) = Foo_Type.Inner (Byte_3 (This))
                  and then Full_Byte (Again) = Full_Byte (This)
                  and then Byte_4 (Again) = Byte_4 (This)
                  and then Five (Again) = Five (This)
                  and then Six (Again) = Six (This),
                  "the same values");
               Check
                 (Text (Target, Bytes_Term (Again)) = "-DE" and then Target (Byte_2 (Again).First) = 16#4B#,
                  "the same bytes and strings");
            end if;
         end;
      else
         Check (False, "parses");
      end if;
   end Test_Write_Bits_Byte_Aligned;

   procedure Test_Write_Term_Struct is
      Data   : Bytes renames Sample_Term_Strz;
      S      : Stream := Open (Data);
      This   : Term_Struct.T;
      Target : Bytes (1 .. 20) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write term_struct");
      Term_Struct.Parse (This, Data, S);
      if Term_Struct.Valid (This) then
         Term_Struct.Write (This, Data, Target, W);
         --  The terminator of s1 is written, that of s2 is not consumed and left to s3, which includes it
         Check
           (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = 12 and then Target (1 .. 12) = Data,
            "the same bytes");
      else
         Check (False, "parses");
      end if;
   end Test_Write_Term_Struct;

   procedure Test_Write_Term_Strz is
      Data   : Bytes renames Sample_Term_Strz;
      S      : Stream := Open (Data);
      This   : Term_Strz.T;
      Target : Bytes (1 .. 20) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write term_strz");
      Term_Strz.Parse (This, Data, S);
      if Term_Strz.Valid (This) then
         Term_Strz.Write (This, Data, Target, W);
         Check
           (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = 12 and then Target (1 .. 12) = Data,
            "the same bytes");
         W := Kaitai.Writers.Open (Target (1 .. 11));
         Term_Strz.Write (This, Data, Target (1 .. 11), W);
         Check (Kaitai.Writers.Status (W) = Capacity_Exceeded, "a target that is too small");
      else
         Check (False, "parses");
      end if;
   end Test_Write_Term_Strz;

   procedure Test_Write_Bytes_Pad_Term_Equal is
      Data   : Bytes renames Sample_Data.Str_Pad_Term;
      S      : Stream := Open (Data);
      This   : Bytes_Pad_Term_Equal.T;
      Target : Bytes (1 .. 100) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write bytes_pad_term_equal");
      Bytes_Pad_Term_Equal.Parse (This, Data, S);
      if Bytes_Pad_Term_Equal.Valid (This) then
         Bytes_Pad_Term_Equal.Write (This, Data, Target, W);
         Check (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = 80, "four fields of 20 bytes");
         Check (Target (1 .. 40) = Data (1 .. 40), "padding that is the terminator, or is not");
         --  s3 ends at its terminator; what the input has behind it is not kept, and is written as padding
         Check
           (Target (41 .. 43) = Data (41 .. 43) and then Target (44 .. 60) = (44 .. 60 => 16#2B#),
            "padding is written with the padding byte");
         Check (Target (61 .. 80) = Data (61 .. 80), "terminator included");
      else
         Check (False, "parses");
      end if;
   end Test_Write_Bytes_Pad_Term_Equal;

   procedure Test_Write_Default_Endian is
      Data   : Bytes renames Sample_Data.Endian_Expr;
      S      : Stream := Open (Data);
      This   : Default_Endian_Expr_Is_Le.T;
      Target : Bytes (1 .. 64) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write default_endian_expr_is_le");
      Default_Endian_Expr_Is_Le.Parse (This, Data, S);
      if Default_Endian_Expr_Is_Le.Valid (This) and then Data'Length <= 64 then
         Default_Endian_Expr_Is_Le.Write (This, Data, Target, W);
         Check (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = Data'Length, "all bytes are written");
         Check (Target (1 .. Data'Length) = Data, "with the byte order that was calculated");
      else
         Check (False, "parses");
      end if;
   end Test_Write_Default_Endian;

   --  Fields that end at the end of their substream without the terminator that eos-error: false allows:
   --  the terminator is written only where there is room for it
   procedure Test_Write_Term_Strz4 is
      Data   : Bytes renames Sample_Term_Strz;
      S      : Stream := Open (Data);
      This   : Term_Strz4.T;
      Again  : Term_Strz4.T;
      Target : Bytes (1 .. 20) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write term_strz4");
      Term_Strz4.Parse (This, Data, S);
      if Term_Strz4.Valid (This) then
         Term_Strz4.Write (This, Data, Target, W);
         Check
           (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = 11,
            "written, without a terminator that was not there");
         Check (Target (1 .. 11) = Data (1 .. 11), "the same bytes");
         declare
            S2 : Stream := Open (Target (1 .. 11));
         begin
            Term_Strz4.Parse (Again, Target (1 .. 11), S2);
            Check
              (Term_Strz4.Valid (Again)
               and then Text (Target, Term_Strz4.S1_Type_Type.Value (Term_Strz4.S1 (Again))) = "foo"
               and then Text (Target, Term_Strz4.S2_Type_Type.Value (Term_Strz4.S2 (Again))) = "bar"
               and then Text (Target, Term_Strz4.S3_Type_Type.Value (Term_Strz4.S3 (Again))) = "baz",
               "the output reads back as the same values");
         end;
      else
         Check (False, "parses");
      end if;
   end Test_Write_Term_Strz4;

   --  The terminator of a field with a size and padding is written, since the padding is stripped first
   procedure Test_Write_Bytes_Pad_Term is
      use Bytes_Pad_Term;
      Data   : Bytes renames Sample_Data.Str_Pad_Term;
      S      : Stream := Open (Data);
      This   : Bytes_Pad_Term.T;
      Again  : Bytes_Pad_Term.T;
      Target : Bytes (1 .. 80) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write bytes_pad_term");
      Parse (This, Data, S);
      if Valid (This) then
         Write (This, Data, Target, W);
         Check (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = 80, "four fields of 20 bytes");
         Check (Target (1 .. 20) = Data (1 .. 20), "padding");
         Check
           (Target (21 .. 28) = Data (21 .. 28) and then Target (29 .. 40) = (29 .. 40 => 16#40#),
            "terminator, and the rest is written as terminator");
         Check (Target (41 .. 60) = Data (41 .. 60), "terminator and padding");
         Check (Target (61 .. 68) = Data (61 .. 68), "terminator included; what follows it is written as terminator");
         declare
            S2 : Stream := Open (Target);
         begin
            Parse (Again, Target, S2);
            Check
              (Valid (Again)
               and then Text (Target, Str_Pad (Again)) = Text (Data, Str_Pad (This))
               and then Text (Target, Str_Term (Again)) = Text (Data, Str_Term (This))
               and then Text (Target, Str_Term_And_Pad (Again)) = Text (Data, Str_Term_And_Pad (This))
               and then Text (Target, Str_Term_Include (Again)) = Text (Data, Str_Term_Include (This)),
               "the output reads back as the same values");
         end;
      else
         Check (False, "parses");
      end if;
   end Test_Write_Bytes_Pad_Term;

   --  A value cut from a field of 20 bytes: padding and terminator go to the end of its substream
   procedure Test_Write_Str_Eos_Pad_Term is
      use Str_Eos_Pad_Term;
      Data   : Bytes renames Sample_Data.Str_Pad_Term;
      S      : Stream := Open (Data);
      This   : Str_Eos_Pad_Term.T;
      Again  : Str_Eos_Pad_Term.T;
      Target : Bytes (1 .. 80) := (others => 16#EE#);
      W      : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);
   begin
      Group ("examples write str_eos_pad_term");
      Parse (This, Data, S);
      if Valid (This) then
         Write (This, Data, Target, W);
         Check (Kaitai.Writers.OK (W) and then Kaitai.Writers.Pos (W) = 80, "four fields of 20 bytes");
         Check (Target (1 .. 20) = Data (1 .. 20), "padding up to the end of the substream");
         Check (Target (21 .. 28) = Data (21 .. 28), "terminator; the rest is not what was there, and is zero");
         Check (Target (41 .. 60) = Data (41 .. 60), "terminator with padding");
         Check (Target (61 .. 68) = Data (61 .. 68), "terminator included; the rest of the substream is zero");
         declare
            S2 : Stream := Open (Target);
         begin
            Parse (Again, Target, S2);
            Check
              (Valid (Again)
               and then Text (Target, Str_Pad_Type_Type.Value (Str_Pad (Again))) = "str1"
               and then Text (Target, Str_Term_Type_Type.Value (Str_Term (Again))) = "str2foo"
               and then Text (Target, Str_Term_And_Pad_Type_Type.Value (Str_Term_And_Pad (Again))) = "str+++3bar+++",
               "the output reads back as the same values");
         end;
      else
         Check (False, "parses");
      end if;
   end Test_Write_Str_Eos_Pad_Term;

   procedure Test_Valid_Fail_Repeat_Eq_Int is
      use Valid_Fail_Repeat_Eq_Int;
      Data : Bytes := (16#12#, 16#34#, 16#56#, 16#78#, 16#12#, 16#34#, 16#56#, 16#78#);
      S    : Stream := Open (Data);
      This : Valid_Fail_Repeat_Eq_Int.T;
   begin
      Group ("examples valid_fail_repeat_eq_int");
      Parse (This, Data, S);
      Check (Valid (This) and then Foo_Count (This) = 2, "every element is as required");
      Data (6) := 0;
      S := Open (Data);
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Validation_Not_Equal, "a wrong element is found");
      S := Open (Sample_Fixed_Struct);
      Parse (This, Sample_Fixed_Struct, S);
      Check (not Valid (This) and then Status (S) = Validation_Not_Equal, "so is one in the sample");
   end Test_Valid_Fail_Repeat_Eq_Int;

   procedure Test_Subscripts is
      use Subscripts;
      Data : constant Bytes := (2, 1, 16#34#, 16#12#, 16#78#, 16#56#, 10, 20, 30, 40, 5, 6, 7, 0, 8, 9);
      S    : Stream := Open (Data);
      This : Subscripts.T;
   begin
      Group ("examples subscripts");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses; records end at the first that starts with 0");
      if Valid (This) then
         Check (Has_First_Item (This, Data) and then First_Item (This, Data) = 16#1234#, "items[0]");
         Check (Has_Chosen_Item (This, Data) and then Chosen_Item (This, Data) = 16#5678#, "items[pick]");
         Check (Has_Raw_Mid (This, Data) and then Raw_Mid (This, Data) = 20, "raw[1]");
         Check (Has_Chosen_Raw (This, Data) and then Chosen_Raw (This, Data) = 20, "raw[pick]");
      end if;
      declare
         Bad : Bytes := Data;
      begin
         Bad (2) := 2;
         S := Open (Bad);
         Parse (This, Bad, S);
         Check (Valid (This) and then not Has_Chosen_Item (This, Bad), "an index past the end is not defined");
      end;
   end Test_Subscripts;

   procedure Test_Switch_Bytearray is
      use Switch_Bytearray;
      use type Opcode_Type.Body_Kind;
      Data     : Bytes renames Sample_Data.Switch_Opcodes;
      S        : Stream := Open (Data);
      This     : Switch_Bytearray.T;
      O        : Opcode_Type.T;
      Position : Opcodes_Cursor;
      Seen     : Natural := 0;
   begin
      Group ("examples switch_bytearray");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Opcodes_Count (This) = 4, "count");
         Get_Opcodes (This, Data, 0, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Strval
            and then Text (Data, Opcode_Type.Strval_Type.Value (Opcode_Type.Body_As_Strval (O))) = "foobar",
            "a case that is the byte array [83] is a string");
         Get_Opcodes (This, Data, 1, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Intval
            and then Opcode_Type.Intval_Type.Value (Opcode_Type.Body_As_Intval (O)) = 16#42#,
            "[73] is an integer");
         Get_Opcodes (This, Data, 3, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Strval
            and then Is_Empty (Opcode_Type.Strval_Type.Value (Opcode_Type.Body_As_Strval (O))),
            "opcodes[3] is an empty string");
         Position := Opcodes_First (This);
         while Has_Element (Position) loop
            Next (This, Data, Position, O);
            exit when not Opcode_Type.Valid (O);
            Seen := Seen + 1;
         end loop;
         Check (Seen = 4, "cursor");
      end if;

      --  a code that no case names is not an error
      declare
         Other : constant Bytes := (16#41#, 16#01#, 16#02#);
      begin
         S := Open (Other);
         Parse (This, Other, S);
         Check (Valid (This) and then Opcodes_Count (This) = 3, "parses a code that no case names, which has no body");
         Get_Opcodes (This, Other, 0, O);
         Check
           (Opcode_Type.Valid (O) and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_None, "none of the cases");
      end;
   end Test_Switch_Bytearray;

   procedure Test_Switch_Else_Only is
      use Switch_Else_Only;
      Data : Bytes renames Sample_Data.Switch_Opcodes;
      S    : Stream := Open (Data);
      This : Switch_Else_Only.T;
   begin
      Group ("examples switch_else_only");
      Parse (This, Data, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Opcode (This) = 16#53#, "opcode");
         Check (Prim_Byte (This) = 16#66#, "a switch of integers that has only the else case");
         Check (Ut_Case (This) = Ut_Is_Data, "a switch of bytes that has only the else case");
         Check
           (Kaitai.Byte_Arrays.Equal (Data, Data_Type.Value (Ut_As_Data (This)), (16#72#, 16#00#, 16#49#, 16#42#)),
            "ut.value");
      end if;
   end Test_Switch_Else_Only;

   procedure Test_Valid_Switch is
      use Valid_Switch;
      Data : Bytes := Sample_Data.Fixed_Struct;
      S    : Stream := Open (Data);
      This : Valid_Switch.T;
   begin
      Group ("examples valid_switch");
      Parse (This, Data, S);
      Check
        (Valid (This) and then A (This) = 16#50# and then B (This) = 16#4341#, "the value of the switch is checked");
      Data (3) := 16#44#;
      S := Open (Data);
      Parse (This, Data, S);
      Check
        (not Valid (This) and then Status (S) = Validation_Not_Equal, "another value of the switch is not accepted");
   end Test_Valid_Switch;

   procedure Test_Str_Literals_Latin1 is
      use Str_Literals_Latin1;
      Data : constant Bytes := (2, 0, 16#C2#, 16#A3#);
      S    : Stream := Open (Data);
      This : Str_Literals_Latin1.T;
   begin
      Group ("examples str_literals_latin1");
      Parse (This, Data, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check
           (Parsed_Eq_Literal (This, Data), "a literal that is not ASCII is compared in the encoding of the string");
      end if;
      declare
         Other : constant Bytes := (2, 0, 16#C2#, 16#A4#);
      begin
         S := Open (Other);
         Parse (This, Other, S);
         Check (Valid (This) and then not Parsed_Eq_Literal (This, Other), "another character is not equal");
      end;
   end Test_Str_Literals_Latin1;

   procedure Test_Str_Literal_Encodings is
      use Str_Literal_Encodings;
      Data : Bytes :=
        (16#A3#, 16#C2#, 16#A3#, 16#A3#, 0, 16#AC#, 16#20#, 16#D8#, 16#3D#, 16#DE#, 0, 16#61#, 16#0A#, 16#61#, 0);
      S    : Stream := Open (Data);
      This : Str_Literal_Encodings.T;
   begin
      Group ("examples str_literal_encodings");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses");
      if Valid (This) then
         Check (Latin1_Is_Pound (This, Data), "ISO-8859-1: one byte");
         Check (Utf8_Is_Pound (This, Data), "UTF-8: two bytes");
         Check (Utf16le_Is_Pound_Euro (This, Data), "UTF-16LE: two units, low byte first");
         Check (Utf16be_Is_Grin (This, Data), "UTF-16BE: a surrogate pair");
         Check (not Utf16be_Is_Not_Grin (This, Data), "!= is the opposite");
         Check (Ascii_Has_Newline (This, Data), "a control character in ASCII");
         Check (Grin_Length (This) = 1, "the length of a literal counts characters");
      end if;

      --  other strings are not equal to the literals
      Data (1) := 16#A4#;
      Data (9) := 16#3E#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (Valid (This) and then not Latin1_Is_Pound (This, Data), "another character");
      Check (not Utf16be_Is_Grin (This, Data) and then Utf16be_Is_Not_Grin (This, Data), "another surrogate pair");
      Check (Utf8_Is_Pound (This, Data), "the others are unchanged");
      Data (14) := 16#62#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Validation_Not_Equal, "valid with a literal in UTF-16LE");
   end Test_Str_Literal_Encodings;

   procedure Test_Expr_To_I_Trailing is
      use Expr_To_I_Trailing;
      S    : Stream := Open (Sample_Term_Strz);
      This : Expr_To_I_Trailing.T;
   begin
      Group ("examples expr_to_i_trailing");
      Parse (This, Sample_Term_Strz, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (not Has_To_I_R10 (This), "letters after the figures are a conversion error in base 10");
         Check (To_I_R16 (This) = 16#9173ABC#, "the same letters are figures in base 16");
         Check (not Has_To_I_Garbage (This), "characters that are no figures are a conversion error");
      end if;
   end Test_Expr_To_I_Trailing;

   procedure Test_Valid_Fail_Range_Str is
      use Valid_Fail_Range_Str;
      Data : Bytes := Sample_Data.Fixed_Struct;
      S    : Stream := Open (Data);
      This : Valid_Fail_Range_Str.T;
   begin
      Group ("examples valid_fail_range_str");
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Validation_Greater_Than, "PA is above P1");
      Data (2) := Character'Pos ('1');
      S := Open (Data);
      Parse (This, Data, S);
      Check (Valid (This), "P1 is the upper end of the range");
      Data (2) := 0;
      S := Open (Data);
      Parse (This, Data, S);
      Check (Valid (This), "P and a byte 0 is above P and below P1");
      Data (1) := Character'Pos ('O');
      S := Open (Data);
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Validation_Less_Than, "O is below P");
   end Test_Valid_Fail_Range_Str;

   procedure Test_Str_Ordering is
      use Str_Ordering;
      Data : Bytes := (16#C2#, 16#A3#, 16#C2#, 16#A3#);
      S    : Stream := Open (Data);
      This : Str_Ordering.T;
   begin
      Group ("examples str_ordering");
      Parse (This, Data, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (not A_Lt_B (This, Data) and then A_Le_B (This, Data), "equal strings");
         Check (not A_Gt_Pound (This, Data) and then Pound_Ge_B (This, Data), "equal to the literal");
         Check (Literals (This), "two literals");
      end if;
      Data (4) := 16#A4#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (Valid (This) and then A_Lt_B (This, Data) and then A_Le_B (This, Data), "the second byte decides");
      Check (not Pound_Ge_B (This, Data), "the literal is below the string");
      Data (1) := 16#61#;
      Data (2) := 16#62#;
      S := Open (Data);
      Parse (This, Data, S);
      Check
        (Valid (This) and then A_Lt_B (This, Data) and then not A_Gt_Pound (This, Data), "ab is below the pound sign");
      Data (1) := 16#C3#;
      Data (2) := 16#80#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (Valid (This) and then A_Gt_Pound (This, Data), "a larger character");
   end Test_Str_Ordering;

   procedure Test_Valid_Long is
      use Valid_Long;
      Data : Bytes := Sample_Data.Fixed_Struct;
      S    : Stream := Open (Data);
      This : Valid_Long.T;
   begin
      Group ("examples valid_long");
      Parse (This, Data, S);
      Check (Valid (This), "the largest value of u8 is valid, as 18446744073709551615 in U64");
      if Valid (This) then
         Check (Uint64 (This) = U64'Last and then Sint64 (This) = -1, "uint64 and sint64");
      end if;
      Data (32) := 16#FE#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (not Valid (This) and then Status (S) = Validation_Not_Equal, "a value of u8 that is not the largest");
      Data := Sample_Data.Fixed_Struct;
      Data (33) := 16#FE#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (not Valid (This), "a letter of the next string");
   end Test_Valid_Long;

   procedure Test_Yaml_Ints is
      use Yaml_Ints;
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Yaml_Ints.T;
   begin
      Group ("examples yaml_ints");
      Parse (This, Sample_Fixed_Struct, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Test_U4_Dec (This) = 16#FFFF_FFFF# and then Test_U4_Hex (This) = 16#FFFF_FFFF#, "32 bits");
         Check
           (Test_U8_Dec (This) = 16#FFFF_FFFF_FFFF_FFFF# and then Test_U8_Hex (This) = U64'Last,
            "an integer above the largest S64 is a U64");
      end if;
   end Test_Yaml_Ints;

   procedure Test_Enum_Long_Range_U is
      use Enum_Long_Range_U;
      Data : Bytes (1 .. 32) :=
        (0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         16#FF#,
         16#FF#,
         16#FF#,
         16#FF#,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         16#FF#,
         16#FF#,
         16#FF#,
         16#FF#,
         16#FF#,
         16#FF#,
         16#FF#,
         16#FF#);
      S    : Stream := Open (Data);
      This : Enum_Long_Range_U.T;
   begin
      Group ("examples enum_long_range_u");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses");
      if Valid (This) then
         Check (F1 (This) = Constants_Zero, "0");
         Check (F2 (This) = Constants_Int_Max, "2**32-1");
         Check (F3 (This) = Constants_Int_Over_Max, "2**32");
         Check (F4_Value (This) = U64'Last and then F4 (This) = Constants_Long_Max, "2**64-1 is mapped to its label");
         Check (To_Integer (F4 (This)) = U64'Last, "and back");
      end if;
      Data (32) := 16#FE#;
      S := Open (Data);
      Parse (This, Data, S);
      Check (Valid (This) and then not Is_Constants_Enum (F4_Value (This)), "another value has no label");
   end Test_Enum_Long_Range_U;

   procedure Run is
   begin
      Test_Hello_World;
      Test_Fixed_Struct;
      Test_Bits_Simple;
      Test_Bits_In_Types;
      Test_Bits_In_Repeat;
      Test_Bits_After_Bytes;
      Test_Bits_First_Type;
      Test_Term_Strz;
      Test_Repeat_N_Struct;
      Test_Repeat_N_Empty;
      Test_Repeat_Bits;
      Test_Repeat_Index;
      Test_Repeat_Eos_U4;
      Test_Repeat_Until_Complex;
      Test_Switch_Manual_Int;
      Test_Enum_0;
      Test_If_Struct;
      Test_Expr_1;
      Test_Params_Def;
      Test_Outside;
      Test_Instance_Std;
      Test_Instance_Kept;
      Test_Position_Abs;
      Test_Valid_Fail_Eq_Int;
      Test_Default_Endian;
      Test_Str_Encodings;
      Test_Bits_Enum;
      Test_Bits_Byte_Aligned;
      Test_Bytes_Pad_Term_Equal;
      Test_Expr_Sizeof_Type_0;
      Test_Expr_Sizeof_Value_Sized;
      Test_Term_Struct;
      Test_Imports0;
      Test_Write_Bits_Enum;
      Test_Write_Bits_Byte_Aligned;
      Test_Write_Term_Struct;
      Test_Write_Term_Strz;
      Test_Write_Bytes_Pad_Term_Equal;
      Test_Write_Default_Endian;
      Test_Write_Term_Strz4;
      Test_Write_Bytes_Pad_Term;
      Test_Write_Str_Eos_Pad_Term;
      Test_Valid_Fail_Repeat_Eq_Int;
      Test_Subscripts;
      Test_Switch_Bytearray;
      Test_Switch_Else_Only;
      Test_Valid_Switch;
      Test_Str_Literals_Latin1;
      Test_Str_Literal_Encodings;
      Test_Expr_To_I_Trailing;
      Test_Valid_Fail_Range_Str;
      Test_Str_Ordering;
      Test_Valid_Long;
      Test_Yaml_Ints;
      Test_Enum_Long_Range_U;
   end Run;

end Examples_Tests;
