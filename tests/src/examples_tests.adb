with Bits_Byte_Aligned;
with Bits_Enum;
with Bits_Simple;
with Bytes_Pad_Term_Equal;
with Default_Endian_Expr_Is_Le;
with Enum_0;
with Expr_1;
with Expr_Sizeof_Type_0;
with Fixed_Struct;
with Hello_World;
with If_Struct;
with Imports0;
with Instance_Std;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Params_Def;
with Position_Abs;
with Repeat_Eos_U4;
with Repeat_N_Struct;
with Repeat_Until_Complex;
with Sample_Data;    use Sample_Data;
with Str_Encodings;
with Switch_Manual_Int;
with Term_Strz;
with Term_Struct;
with Test_Support;   use Test_Support;
with Valid_Fail_Eq_Int;

package body Examples_Tests is

   Sample_Fixed_Struct : Bytes renames Sample_Data.Fixed_Struct;
   Sample_Term_Strz    : Bytes renames Sample_Data.Term_Strz;

   procedure Test_Hello_World is
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Hello_World.T;
      None : constant Bytes (1 .. 0) := (others => 0);
   begin
      Group ("examples hello_world");
      Hello_World.Parse (Sample_Fixed_Struct, S, This);
      Check (Hello_World.Valid (This) and then OK (S), "parses");
      Check (Hello_World.One (This) = 16#50#, "one");
      Check (Pos (S) = 1, "one byte consumed");

      S := Open (None);
      Hello_World.Parse (None, S, This);
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
      Parse (Sample_Fixed_Struct, S, This);
      Check (Valid (This) and then Pos (S) = 0, "parses; the type has no fields in sequence");
      Hdr (Sample_Fixed_Struct, This, H, Outcome);
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
      Hdr (Sample_Fixed_Struct, This, H, Outcome);
      Check (Outcome = Success, "the instance can be asked for again");

      --  A file whose second magic is wrong
      Bad (9) := 16#51#;
      S := Open (Bad);
      Parse (Bad, S, This);
      Hdr (Bad, This, H, Outcome);
      Check (Outcome = Validation_Not_Equal and then not Header_Type.Valid (H), "wrong contents are rejected");

      --  Every truncated file
      for Last in 0 .. Sample_Fixed_Struct'Last - 1 loop
         S := Open (Sample_Fixed_Struct (1 .. Last));
         Parse (Sample_Fixed_Struct (1 .. Last), S, This);
         Hdr (Sample_Fixed_Struct (1 .. Last), This, H, Outcome);
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
      Parse (Sample_Fixed_Struct, S, This);
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
      Parse (Sample_Fixed_Struct (1 .. 27), S, This);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a file one byte short is rejected");
   end Test_Bits_Simple;

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
      Parse (Sample_Term_Strz, S, This);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Text (S1 (This)) = "foo", "s1");
         Check (Text (S2 (This)) = "bar", "s2");
         Check (Text (S3 (This)) = "|baz@", "s3");
      end if;
      Check (Is_EOF (S), "the whole file is consumed");

      S := Open (Sample_Term_Strz (1 .. 11));
      Parse (Sample_Term_Strz (1 .. 11), S, This);
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
      Parse (Data, S, This);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Qty (This) = 2 and then Chunks_Count (This) = 2, "count");
         Get_Chunks (Data, This, 0, C);
         Check
           (Chunk_Type.Valid (C) and then Chunk_Type.Offset (C) = 16#10# and then Chunk_Type.Len (C) = 16#2078#,
            "chunks[0]");
         Get_Chunks (Data, This, 1, C);
         Check
           (Chunk_Type.Valid (C) and then Chunk_Type.Offset (C) = 16#2088# and then Chunk_Type.Len (C) = 16#F#,
            "chunks[1]");
         Position := Chunks_First (This);
         while Has_Element (Position) loop
            pragma Loop_Variant (Decreases => Remaining (Position));
            pragma Loop_Invariant (Belongs_To (Position, Data));
            Next (Data, This, Position, C);
            exit when not Chunk_Type.Valid (C);
            Seen := Seen + 1;
         end loop;
         Check (Seen = 2, "cursor");
      end if;
      for Last in 0 .. Data'Last - 1 loop
         S := Open (Data (1 .. Last));
         Parse (Data (1 .. Last), S, This);
         if Valid (This) then
            Bad := Bad + 1;
         end if;
      end loop;
      Check (Bad = 0, "every shorter input fails");
   end Test_Repeat_N_Struct;

   procedure Test_Repeat_Eos_U4 is
      use Repeat_Eos_U4;
      Data : Bytes renames Sample_Data.Repeat_Eos_Struct;
      S    : Stream := Open (Data);
      This : Repeat_Eos_U4.T;
   begin
      Group ("examples repeat_eos_u4");
      Parse (Data, S, This);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Numbers_Count (This) = 4, "count");
         Check
           (Numbers (Data, This, 0) = 0
            and then Numbers (Data, This, 1) = 16#42#
            and then Numbers (Data, This, 2) = 16#42#
            and then Numbers (Data, This, 3) = 16#815#,
            "elements");
      end if;
      S := Open (Data (1 .. 15));
      Parse (Data (1 .. 15), S, This);
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
      Parse (Data, S, This);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (First_Count (This) = 3, "first: count includes the last element");
         Get_First (Data, This, 0, U1);
         Check
           (Type_U1_Type.Valid (U1)
            and then Type_U1_Type.Count (U1) = 4
            and then Type_U1_Type.Values_Count (U1) = 4
            and then Type_U1_Type.Values (Data, U1, 0) = 1
            and then Type_U1_Type.Values (Data, U1, 3) = 4,
            "first[0]");
         Get_First (Data, This, 1, U1);
         Check (Type_U1_Type.Valid (U1) and then Type_U1_Type.Count (U1) = 2, "first[1]");
         Get_First (Data, This, 2, U1);
         Check (Type_U1_Type.Valid (U1) and then Type_U1_Type.Count (U1) = 0, "first[2] ends it");
         Check (Second_Count (This) = 4, "second: count");
         Get_Second (Data, This, 0, U2);
         Check
           (Type_U2_Type.Valid (U2) and then Type_U2_Type.Count (U2) = 6 and then Type_U2_Type.Values (Data, U2, 5) = 6,
            "second[0]");
         Get_Second (Data, This, 3, U2);
         Check (Type_U2_Type.Valid (U2) and then Type_U2_Type.Count (U2) = 0, "second[3] ends it");
         Check (Third_Count (This) = 7, "third: count, a repetition of integers up to a condition");
         Check
           (Third (Data, This, 0) = 102 and then Third (Data, This, 5) = 114 and then Third (Data, This, 6) = 0,
            "third: elements");
      end if;
      S := Open (Data (1 .. 49));
      Parse (Data (1 .. 49), S, This);
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
      Parse (Data, S, This);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Opcodes_Count (This) = 4, "count");
         Get_Opcodes (Data, This, 0, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Code (O) = 83
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Strval
            and then Text (Data, Opcode_Type.Strval_Type.Value (Opcode_Type.Body_As_Strval (O))) = "foobar",
            "opcodes[0] is a string");
         Get_Opcodes (Data, This, 1, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Intval
            and then Opcode_Type.Intval_Type.Value (Opcode_Type.Body_As_Intval (O)) = 16#42#,
            "opcodes[1] is an integer");
         Get_Opcodes (Data, This, 2, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Intval
            and then Opcode_Type.Intval_Type.Value (Opcode_Type.Body_As_Intval (O)) = 16#37#,
            "opcodes[2]");
         Get_Opcodes (Data, This, 3, O);
         Check
           (Opcode_Type.Valid (O)
            and then Opcode_Type.Body_Case (O) = Opcode_Type.Body_Is_Strval
            and then Is_Empty (Opcode_Type.Strval_Type.Value (Opcode_Type.Body_As_Strval (O))),
            "opcodes[3] is an empty string");
         Position := Opcodes_First (This);
         while Has_Element (Position) loop
            pragma Loop_Variant (Decreases => Remaining (Position));
            pragma Loop_Invariant (Belongs_To (Position, Data));
            Next (Data, This, Position, O);
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
      Parse (Data, S, This);
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
      Parse (Data, S, This);
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
      Parse (Data, S, This);
      Check (Valid (This) and then Pos (S) = 10, "parses");
      if Valid (This) then
         Check (Len_Of_1 (This) = 10, "len_of_1");
         Check (Len_Of_1_Mod (This) = 8, "instance with a value");
         Check (Text (Data, Str1 (This)) = "Some ASC", "size from an instance");
         Check (Str1_Len (Data, This) = 8, "length of a string");
      end if;
      Bad (1) := 1;
      Bad (2) := 0;
      S := Open (Bad);
      Parse (Bad, S, This);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a negative size fails");
      Bad (1) := 2;
      S := Open (Bad);
      Parse (Bad, S, This);
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
      Parse (Data, S, 3, True, This);
      Check (Valid (This) and then Is_EOF (S), "parses with a trailer");
      if Valid (This) then
         Check (Len (This) = 3 and then Has_Trailer_Field (This), "the parameters are kept");
         Check (Text (Data, Buf (This)) = "abc", "size from a parameter");
         Check (Has_Trailer (This) and then Trailer (This) = 16#58#, "field with a condition on a parameter");
      end if;
      S := Open (Data);
      Parse (Data, S, 3, False, This);
      Check (Valid (This) and then not Has_Trailer (This) and then Pos (S) = 3, "parses without a trailer");
      S := Open (Data);
      Parse (Data, S, 5, False, This);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a size beyond the input fails");
      S := Open (Bad);
      Parse (Bad, S, 3, True, This);
      Check (not Valid (This) and then Status (S) = Illegal_Sequence, "the string is checked as UTF-8");
   end Test_Params_Def;

   procedure Test_Instance_Std is
      use Instance_Std;
      Data    : constant Bytes (1 .. 9) := (16#78#, 16#78#, 16#48#, 16#45#, 16#4C#, 16#4C#, 16#4F#, 16#79#, 16#79#);
      S       : Stream := Open (Data);
      This    : Instance_Std.T;
      Result  : Slice;
      Outcome : Status_Kind;
   begin
      Group ("examples instance_std");
      Parse (Data, S, This);
      Check (Valid (This) and then Pos (S) = 0, "parses; the type has no fields in sequence");
      Header (Data, This, Result, Outcome);
      Check (Outcome = Success and then Text (Data, Result) = "HELLO", "instance with a position and a size");
      S := Open (Data (1 .. 5));
      Parse (Data (1 .. 5), S, This);
      Header (Data (1 .. 5), This, Result, Outcome);
      Check (Outcome = End_Of_Stream and then Is_Empty (Result), "the instance runs out of bytes");
   end Test_Instance_Std;

   procedure Test_Position_Abs is
      use Position_Abs;
      Data    : Bytes renames Sample_Data.Position_Abs;
      S       : Stream := Open (Data);
      This    : Position_Abs.T;
      Index_V : Index_Obj_Type.T;
      Outcome : Status_Kind;
   begin
      Group ("examples position_abs");
      Parse (Data, S, This);
      Check (Valid (This) and then Index_Offset (This) = 16#20#, "parses");
      if Valid (This) then
         Position_Abs.Index (Data, This, Index_V, Outcome);
         Check
           (Outcome = Success
            and then Index_Obj_Type.Valid (Index_V)
            and then Text (Data, Index_Obj_Type.Entry_Field (Index_V)) = "foo",
            "instance at an absolute position");
      end if;
      S := Open (Data (1 .. 20));
      Parse (Data (1 .. 20), S, This);
      if Valid (This) then
         Position_Abs.Index (Data (1 .. 20), This, Index_V, Outcome);
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
      Parse (Data, S, This);
      Check (not Valid (This) and then Status (S) = Validation_Not_Equal, "0x50 is not 123");
      Data (1) := 123;
      S := Open (Data);
      Parse (Data, S, This);
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
      Parse (Data, S, This);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Docs_Count (This) = 3, "count");
         Position := Docs_First (This);
         while Has_Element (Position) loop
            pragma Loop_Variant (Decreases => Remaining (Position));
            pragma Loop_Invariant (Belongs_To (Position, Data));
            Next (Data, This, Position, D);
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
      Parse (Data, S, This);
      Check (Valid (This) and then Is_EOF (S), "parses to the end");
      if Valid (This) then
         Check (Text (Data, Str1 (This)) = "Some ASCII", "ASCII");
         Check (Size (Str2 (This)) = 15, "UTF-8");
         Check (Size (Str3 (This)) = 10, "SJIS, one byte per character for the library");
         Check (Size (Str4 (This)) = 3, "IBM437");
      end if;
      Data (3) := 16#80#;
      S := Open (Data);
      Parse (Data, S, This);
      Check (not Valid (This) and then Status (S) = Illegal_Sequence, "a byte above 127 is not ASCII");
      Data := Sample_Data.Str_Encodings;
      Data (16) := 16#FF#;
      S := Open (Data);
      Parse (Data, S, This);
      Check (not Valid (This) and then Status (S) = Illegal_Sequence, "0xFF is not UTF-8");
   end Test_Str_Encodings;

   procedure Test_Bits_Enum is
      use Bits_Enum;
      Data : Bytes renames Sample_Data.Fixed_Struct;
      S    : Stream := Open (Data);
      This : Bits_Enum.T;
   begin
      Group ("examples bits_enum");
      Parse (Data, S, This);
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
      Parse (Data, S, This);
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
      Parse (Data, S, This);
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
      Parse (Sample_Fixed_Struct, S, This);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Sizeof_Block (This) = 7, "the size of a type is in bytes");
      end if;
   end Test_Expr_Sizeof_Type_0;

   procedure Test_Term_Struct is
      use Term_Struct;
      Data : Bytes renames Sample_Term_Strz;
      S    : Stream := Open (Data);
      This : Term_Struct.T;
   begin
      Group ("examples term_struct");
      Parse (Data, S, This);
      Check (Valid (This) and then Is_EOF (S), "parses");
      if Valid (This) then
         Check (Text (Data, Bytes_Wrapper_Type.Value (S1 (This))) = "foo", "s1");
         Check (Text (Data, Bytes_Wrapper_Type.Value (S2 (This))) = "bar", "s2, terminator not consumed");
         Check (Text (Data, Bytes_Wrapper_Type.Value (S3 (This))) = "|baz@", "s3, terminator included");
      end if;

      S := Open (Data (1 .. 11));
      Parse (Data (1 .. 11), S, This);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a missing terminator is rejected");
   end Test_Term_Struct;

   procedure Test_Imports0 is
      use Imports0;
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Imports0.T;
   begin
      Group ("examples imports0");
      Parse (Sample_Fixed_Struct, S, This);
      Check (Valid (This) and then Pos (S) = 2, "parses");
      if Valid (This) then
         Check (Two (This) = 16#50#, "two");
         Check (Hello_World.One (Hw (This)) = 16#41#, "a field of the type of another description");
         Check (Has_Hw_One (This) and then Hw_One (This) = 16#41#, "an instance that uses it");
      end if;
   end Test_Imports0;

   procedure Run is
   begin
      Test_Hello_World;
      Test_Fixed_Struct;
      Test_Bits_Simple;
      Test_Term_Strz;
      Test_Repeat_N_Struct;
      Test_Repeat_Eos_U4;
      Test_Repeat_Until_Complex;
      Test_Switch_Manual_Int;
      Test_Enum_0;
      Test_If_Struct;
      Test_Expr_1;
      Test_Params_Def;
      Test_Instance_Std;
      Test_Position_Abs;
      Test_Valid_Fail_Eq_Int;
      Test_Default_Endian;
      Test_Str_Encodings;
      Test_Bits_Enum;
      Test_Bits_Byte_Aligned;
      Test_Bytes_Pad_Term_Equal;
      Test_Expr_Sizeof_Type_0;
      Test_Term_Struct;
      Test_Imports0;
   end Run;

end Examples_Tests;
