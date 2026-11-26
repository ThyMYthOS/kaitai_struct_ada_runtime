with Bits_Byte_Aligned;
with Bits_After_Bytes;
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
with Extras;
with Fixed_Struct;
with Foreign;
with Hello_World;
with If_Struct;
with Imports0;
with Instance_Std;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Writers;
with Outside;
with Params_Def;
with Position_Abs;
with Repeat_Eos_U4;
with Repeat_N_Empty;
with Repeat_N_Struct;
with Repeat_Until_Complex;
with Sample_Data;
with Showcase;
with Str_Encodings;
with Str_Eos_Pad_Term;
with Str_Literal_Encodings;
with Str_Literals_Latin1;
with Str_Ordering;
with Subscripts;
with Timestamp;
with Switch_Bytearray;
with Switch_Else_Only;
with Switch_Manual_Int;
with Term_Struct;
with Term_Strz;
with Term_Strz4;
with Valid_Fail_Eq_Int;
with Valid_Fail_Range_Str;
with Valid_Fail_Repeat_Eq_Int;
with Valid_Long;
with Valid_Switch;
with Write_Model;
with Yaml_Ints;

package body Fuzz_Targets is

   Showcase_Full : constant Bytes :=
     (16#53#,
      16#48#,
      16#02#,
      16#02#,
      16#00#,
      16#07#,
      16#01#,
      16#05#,
      16#41#,
      16#42#,
      16#01#,
      16#01#,
      16#00#,
      16#FE#,
      16#FF#,
      16#09#,
      16#02#,
      16#68#,
      16#69#,
      16#00#,
      16#0A#,
      16#2A#,
      16#00#,
      16#00#,
      16#00#,
      16#05#,
      16#00#,
      16#06#,
      16#00#,
      16#00#,
      16#00#,
      16#07#,
      16#00#,
      16#08#,
      16#01#,
      16#00#,
      16#02#,
      16#00#,
      16#03#,
      16#00#,
      16#04#,
      16#00#,
      16#10#,
      16#00#,
      16#20#,
      16#00#,
      16#30#,
      16#00#);

   Showcase_Minimal : constant Bytes := (16#53#, 16#48#, 1, 1, 0, 0, 0, 3, 3, 0, 0, 9, 0, 0, 16#10#, 0);

   --  A value of examples/foreign: the key, a timestamp, 3 bytes of text, a frame of 5 bytes, two timestamps
   Foreign_Data : constant Bytes :=
     (16#05#,
      16#00#,
      16#00#,
      16#01#,
      16#00#,
      16#03#,
      16#6B#,
      16#97#,
      16#69#,
      16#05#,
      16#FF#,
      16#00#,
      16#12#,
      16#34#,
      16#FF#,
      16#00#,
      16#00#,
      16#00#,
      16#0A#,
      16#00#,
      16#00#,
      16#00#,
      16#14#);

   Extras_Full : constant Bytes :=
     (16#5A#,
      16#02#,
      16#3B#,
      16#38#,
      16#03#,
      16#42#,
      16#86#,
      16#CA#,
      16#01#,
      16#02#,
      16#0A#,
      16#04#,
      16#05#,
      16#0B#,
      16#01#,
      16#02#,
      16#02#,
      16#00#,
      16#07#,
      16#03#,
      16#01#,
      16#04#,
      16#00#,
      16#08#,
      16#09#,
      16#0C#);

   --  No key, nothing to process, and a tree of nodes with one child each
   Extras_Chain : constant Bytes := (0, 0, 0, 1, 1, 2, 1, 3, 1, 4, 1, 5, 1, 6, 0);

   Bits_In_Types_Data    : constant Bytes := (16#AB#, 16#CD#);
   Bits_In_Repeat_Data   : constant Bytes := (16#AB#, 16#CD#, 16#EF#, 16#12#);
   Bits_After_Bytes_Data : constant Bytes := (16#11#, 16#B6#, 16#2A#, 16#07#);
   Bits_First_Type_Data  : constant Bytes := (16#B6#, 16#2A#, 16#07#);

   Subscripts_Data : constant Bytes := (2, 1, 16#34#, 16#12#, 16#78#, 16#56#, 10, 20, 30, 40, 5, 6, 7, 0, 8, 9);

   --  A string of two bytes in UTF-8 that is the pound sign
   Str_Literals_Latin1_Data : constant Bytes := (2, 0, 16#C2#, 16#A3#);

   --  Strings in ISO-8859-1, UTF-8, UTF-16LE, UTF-16BE and ASCII that the instances compare with literals, and one that
   --  is valid
   Str_Literal_Encodings_Data : constant Bytes :=
     (16#A3#, 16#C2#, 16#A3#, 16#A3#, 0, 16#AC#, 16#20#, 16#D8#, 16#3D#, 16#DE#, 0, 16#61#, 16#0A#, 16#61#, 0);

   --  Two strings of two bytes in UTF-8: the pound sign and "ab"
   Str_Ordering_Data : constant Bytes := (16#C2#, 16#A3#, 16#61#, 16#62#);

   --  Two bytes that are within the range of the string "P" .. "P1" ("P1")
   Range_Str_Data : constant Bytes := (16#50#, 16#31#, 0, 0);

   --  Four values of an enumeration of values above the largest S64: 0, 2**32-1, 2**32 and 2**64-1
   Enum_Long_Data : constant Bytes :=
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

   --  Two values that are 0x12345678, and none: the parser accepts no others
   Repeat_Eq_Int_Data : constant Bytes := (16#12#, 16#34#, 16#56#, 16#78#, 16#12#, 16#34#, 16#56#, 16#78#);

   Repeat_Eq_Int_Empty : constant Bytes (1 .. 0) := (others => 0);

   Outside_Seed : constant Bytes :=
     (16#66#, 16#6F#, 16#6F#, 2, 3, 16#78#, 16#79#, 16#7A#, 1, 2, 3, 4, 5, 6, 16#6E#, 16#6F#);

   function Seed (T : Target; Round : Positive) return Bytes is
   begin
      case T is
         when Showcase_Parser                  =>
            return (if Round mod 4 = 0 then Showcase_Minimal else Showcase_Full);

         when Extras_Parser                    =>
            return (if Round mod 3 = 0 then Extras_Chain else Extras_Full);

         when Write_Model_Parser               =>
            return (if Round mod 4 = 0 then Showcase_Minimal else Showcase_Full);

         when Params_Def_Parser                =>
            return Sample_Data.Str_Encodings;

         when Outside_Parser                   =>
            return Outside_Seed;

         when Hello_World_Parser               =>
            return Sample_Data.Fixed_Struct;

         when Fixed_Struct_Parser              =>
            return Sample_Data.Fixed_Struct;

         when Bits_Simple_Parser               =>
            return Sample_Data.Fixed_Struct;

         when Bits_Enum_Parser                 =>
            return Sample_Data.Fixed_Struct;

         when Bits_In_Types_Parser             =>
            return Bits_In_Types_Data;

         when Bits_In_Repeat_Parser            =>
            return Bits_In_Repeat_Data;

         when Bits_After_Bytes_Parser          =>
            return Bits_After_Bytes_Data;

         when Bits_First_Type_Parser           =>
            return Bits_First_Type_Data;

         when Bits_Byte_Aligned_Parser         =>
            return Sample_Data.Fixed_Struct;

         when Term_Strz_Parser                 =>
            return Sample_Data.Term_Strz;

         when Repeat_N_Struct_Parser           =>
            return Sample_Data.Repeat_N_Struct;

         when Repeat_N_Empty_Parser            =>
            return Sample_Data.Repeat_N_Empty;

         when Repeat_Eos_U4_Parser             =>
            return Sample_Data.Repeat_Eos_Struct;

         when Repeat_Until_Complex_Parser      =>
            return Sample_Data.Repeat_Until_Complex;

         when Switch_Manual_Int_Parser         =>
            return Sample_Data.Switch_Opcodes;

         when Enum_0_Parser                    =>
            return Sample_Data.Enum_0;

         when If_Struct_Parser                 =>
            return Sample_Data.If_Struct;

         when Expr_1_Parser                    =>
            return Sample_Data.Str_Encodings;

         when Instance_Std_Parser              =>
            return Sample_Data.Str_Encodings;

         when Position_Abs_Parser              =>
            return Sample_Data.Position_Abs;

         when Str_Encodings_Parser             =>
            return Sample_Data.Str_Encodings;

         when Default_Endian_Expr_Is_Le_Parser =>
            return Sample_Data.Endian_Expr;

         when Valid_Fail_Eq_Int_Parser         =>
            return Sample_Data.Fixed_Struct;

         when Imports0_Parser                  =>
            return Sample_Data.Fixed_Struct;

         when Term_Struct_Parser               =>
            return Sample_Data.Term_Strz;

         when Bytes_Pad_Term_Equal_Parser      =>
            return Sample_Data.Str_Pad_Term;

         when Expr_Sizeof_Type_0_Parser        =>
            return Sample_Data.Fixed_Struct;

         when Expr_Sizeof_Value_Sized_Parser   =>
            return Sample_Data.Fixed_Struct;

         when Term_Strz4_Parser                =>
            return Sample_Data.Term_Strz;

         when Bytes_Pad_Term_Parser            =>
            return Sample_Data.Str_Pad_Term;

         when Str_Eos_Pad_Term_Parser          =>
            return Sample_Data.Str_Pad_Term;

         when Subscripts_Parser                =>
            return Subscripts_Data;

         when Valid_Fail_Repeat_Eq_Int_Parser  =>
            return (if Round mod 2 = 0 then Repeat_Eq_Int_Empty else Repeat_Eq_Int_Data);

         when Switch_Bytearray_Parser          =>
            return Sample_Data.Switch_Opcodes;

         when Switch_Else_Only_Parser          =>
            return Sample_Data.Switch_Opcodes;

         when Valid_Switch_Parser              =>
            return Sample_Data.Fixed_Struct;

         when Str_Literals_Latin1_Parser       =>
            return Str_Literals_Latin1_Data;

         when Str_Literal_Encodings_Parser     =>
            return Str_Literal_Encodings_Data;

         when Expr_To_I_Trailing_Parser        =>
            return Sample_Data.Term_Strz;

         when Valid_Fail_Range_Str_Parser      =>
            return Range_Str_Data;

         when Str_Ordering_Parser              =>
            return Str_Ordering_Data;

         when Valid_Long_Parser                =>
            return Sample_Data.Fixed_Struct;

         when Yaml_Ints_Parser                 =>
            return Sample_Data.Fixed_Struct;

         when Enum_Long_Range_U_Parser         =>
            return Enum_Long_Data;

         when Foreign_Parser                   =>
            return Foreign_Data;
      end case;
   end Seed;

   procedure Count (Fields : in out Natural; Condition : Boolean := True) is
   begin
      if Condition then
         Fields := Fields + 1;
      end if;
   end Count;

   procedure Run_Showcase (Input : Bytes; Argument : U16; Fields : out Natural) is
      package Entries renames Showcase.Entry_Type;
      package Points renames Showcase.Entry_Type.Point_Type;
      use type Entries.Body_Kind;
      use type Showcase.Kind_Enum;

      S       : Stream := Open (Input);
      R       : Showcase.T;
      E       : Entries.T;
      P       : Points.T;
      Outcome : Status_Kind;

      procedure Read_Entry is
      begin
         if not Entries.Valid (E) then
            return;
         end if;
         Count (Fields, Entries.Code (E) = 0 or else Entries.Flags (E) = 0);
         case Entries.Body_Case (E) is
            when Entries.Body_Is_Point =>
               Count (Fields, Points.X (Entries.Body_As_Point (E)) = Points.Y (Entries.Body_As_Point (E)));

            when Entries.Body_Is_Text  =>
               Count (Fields, Within (Entries.Text_Type.Value (Entries.Body_As_Text (E)), Input));

            when Entries.Body_Is_None  =>
               null;
         end case;
         if Entries.Has_Extra (E) then
            Count (Fields, Entries.Extra (E) = 0);
         end if;
      end Read_Entry;
   begin
      Fields := 0;
      Showcase.Parse (Input, S, Argument, R);
      pragma Assert (Showcase.Valid (R) = OK (S));
      if not Showcase.Valid (R) then
         return;
      end if;
      Fields := 1;
      Count (Fields, Showcase.Scale (R) = Argument);
      if Showcase.Is_Kind_Enum (S64 (Showcase.Kind_Value (R))) then
         Count (Fields, Showcase.Kind (R) = Showcase.Kind_Big);
      end if;
      Count (Fields, Showcase.Num_Entries (R) = 0);
      Count (Fields, Showcase.Header_Type.Version (Showcase.Header (R)) = 0);
      Count (Fields, Within (Showcase.Header_Type.Name (Showcase.Header (R)), Input));
      if Showcase.Has_Tail_Len (R) then
         Count (Fields, Showcase.Tail_Len (R) = 0);
      end if;
      if Showcase.Has_Total (R) then
         Count (Fields, Showcase.Total (R) = 0);
      end if;

      declare
         Position : Showcase.Entries_Cursor := Showcase.Entries_First (R);
      begin
         while Showcase.Has_Element (Position) loop
            Showcase.Next (Input, R, Position, E);
            Read_Entry;
         end loop;
      end;
      if Showcase.Entries_Count (R) > 0 then
         Showcase.Get_Entries (Input, R, Showcase.Entries_Count (R) - 1, E);
         --  What Parse accepted is accepted again
         pragma Assert (Entries.Valid (E));
         Read_Entry;
      end if;

      for I in 0 .. Showcase.Points_Count (R) - 1 loop
         Showcase.Get_Points (Input, R, I, P);
         pragma Assert (Points.Valid (P));
         Count (Fields, Points.X (P) = 0);
      end loop;

      for I in 0 .. Showcase.Log_Type.Records_Count (Showcase.Log (R)) - 1 loop
         Showcase.Log_Type.Get_Records (Input, Showcase.Log (R), I, P);
         pragma Assert (Points.Valid (P));
         Count (Fields, Points.Y (P) = 0);
      end loop;

      for I in 0 .. Showcase.Samples_Count (R) - 1 loop
         Count (Fields, Showcase.Samples (Input, R, I) = 0);
      end loop;

      Showcase.First_Entry (Input, R, E, Outcome);
      pragma Assert (Entries.Valid (E) = (Outcome = Success));
      Read_Entry;
   end Run_Showcase;

   procedure Run_Extras (Input : Bytes; Fields : out Natural) is
      package Nodes renames Extras.Node_Type;
      package Items renames Extras.Item_Type;

      S       : Stream := Open (Input);
      R       : Extras.T;
      Item    : Items.T;
      Inner   : Extras.Inner_Type.T;
      Storage : Bytes (7 .. 70) := (others => 0);
      Last    : Length;
      Outcome : Status_Kind;

      --  Read Node and everything below it, at most Levels deep, since a
      --  tree can have many more nodes than the input has bytes to visit
      procedure Walk (Node : Nodes.T; Levels : Natural) is
         Child : Nodes.T;
      begin
         if not (Nodes.Valid (Node) and then Nodes.Belongs_To (Node, Input)) then
            return;
         end if;
         Count (Fields, Nodes.Tag (Node) = 0 or else Nodes.Num_Children (Node) = 0);
         if Nodes.Has_Weight (Node) then
            Count (Fields, Nodes.Weight (Node) = 0);
         end if;
         if Levels > 0 then
            for I in 0 .. Length'Min (Nodes.Children_Count (Node), 3) - 1 loop
               Nodes.Get_Children (Input, Node, I, Child);
               --  What Parse accepted is accepted again
               pragma Assert (Nodes.Valid (Child));
               Walk (Child, Levels - 1);
            end loop;
         end if;
      end Walk;
   begin
      Fields := 0;
      Extras.Parse (Input, S, R);
      pragma Assert (Extras.Valid (R) = OK (S));
      if not Extras.Valid (R) then
         return;
      end if;
      Fields := 1;
      Count (Fields, Extras.Key (R) = Extras.Len_Secret (R));
      Extras.Secret (Input, R, Storage, Last, Outcome);
      pragma Assert ((Outcome = Success) = (Size (Extras.Secret_Raw (R)) <= Storage'Length));
      Count (Fields, Outcome = Success and then Last >= Storage'First);
      Extras.Packed (Input, R, Storage, Inner, Outcome);
      if Extras.Inner_Type.Valid (Inner) then
         Count (Fields, Extras.Inner_Type.A (Inner) = 0 or else Extras.Inner_Type.B (Inner) = 0);
      end if;
      for I in 0 .. Extras.Items_Count (R) - 1 loop
         Extras.Get_Items (Input, R, I, Item);
         pragma Assert (Items.Valid (Item));
         Count (Fields, Within (Items.Value (Item), Input));
         if Items.Has_Extra (Item) then
            Count (Fields, Items.Extra (Item) = 0);
         end if;
      end loop;
      Walk (Extras.Tree (R), 6);
   end Run_Extras;

   --  Parse Input with a parser that is not looked into any further
   generic
      type T is private;
      with procedure Parse (Buffer : Bytes; S : in out Stream; This : out T);
      with function Valid (This : T) return Boolean;
   procedure Run_Parse_Only (Input : Bytes; Fields : out Natural);

   procedure Run_Parse_Only (Input : Bytes; Fields : out Natural) is
      S : Stream := Open (Input);
      R : T;
   begin
      Parse (Input, S, R);
      pragma Assert (Valid (R) = OK (S));
      Fields := (if Valid (R) then 1 else 0);
   end Run_Parse_Only;

   procedure Run_Hello_World is new Run_Parse_Only (Hello_World.T, Hello_World.Parse, Hello_World.Valid);
   procedure Run_Fixed_Struct is new Run_Parse_Only (Fixed_Struct.T, Fixed_Struct.Parse, Fixed_Struct.Valid);
   procedure Run_Bits_Simple is new Run_Parse_Only (Bits_Simple.T, Bits_Simple.Parse, Bits_Simple.Valid);
   procedure Run_Bits_Enum is new Run_Parse_Only (Bits_Enum.T, Bits_Enum.Parse, Bits_Enum.Valid);
   procedure Run_Bits_In_Types is new Run_Parse_Only (Bits_In_Types.T, Bits_In_Types.Parse, Bits_In_Types.Valid);
   procedure Run_Bits_In_Repeat is new Run_Parse_Only (Bits_In_Repeat.T, Bits_In_Repeat.Parse, Bits_In_Repeat.Valid);
   procedure Run_Bits_After_Bytes is new
     Run_Parse_Only (Bits_After_Bytes.T, Bits_After_Bytes.Parse, Bits_After_Bytes.Valid);
   procedure Run_Bits_First_Type is new
     Run_Parse_Only (Bits_First_Type.T, Bits_First_Type.Parse, Bits_First_Type.Valid);
   procedure Run_Bits_Byte_Aligned is new
     Run_Parse_Only (Bits_Byte_Aligned.T, Bits_Byte_Aligned.Parse, Bits_Byte_Aligned.Valid);
   procedure Run_Term_Strz is new Run_Parse_Only (Term_Strz.T, Term_Strz.Parse, Term_Strz.Valid);
   procedure Run_Repeat_N_Struct is new
     Run_Parse_Only (Repeat_N_Struct.T, Repeat_N_Struct.Parse, Repeat_N_Struct.Valid);
   --  Only Parse: the count of a mutated input can be billions, and walking the elements is the caller's loop
   procedure Run_Repeat_N_Empty is new Run_Parse_Only (Repeat_N_Empty.T, Repeat_N_Empty.Parse, Repeat_N_Empty.Valid);
   procedure Run_Repeat_Eos_U4 is new Run_Parse_Only (Repeat_Eos_U4.T, Repeat_Eos_U4.Parse, Repeat_Eos_U4.Valid);
   procedure Run_Repeat_Until_Complex is new
     Run_Parse_Only (Repeat_Until_Complex.T, Repeat_Until_Complex.Parse, Repeat_Until_Complex.Valid);
   procedure Run_Switch_Manual_Int is new
     Run_Parse_Only (Switch_Manual_Int.T, Switch_Manual_Int.Parse, Switch_Manual_Int.Valid);
   procedure Run_Enum_0 is new Run_Parse_Only (Enum_0.T, Enum_0.Parse, Enum_0.Valid);
   procedure Run_If_Struct is new Run_Parse_Only (If_Struct.T, If_Struct.Parse, If_Struct.Valid);
   procedure Run_Expr_1 is new Run_Parse_Only (Expr_1.T, Expr_1.Parse, Expr_1.Valid);
   procedure Run_Instance_Std is new Run_Parse_Only (Instance_Std.T, Instance_Std.Parse, Instance_Std.Valid);
   procedure Run_Position_Abs is new Run_Parse_Only (Position_Abs.T, Position_Abs.Parse, Position_Abs.Valid);
   procedure Run_Str_Encodings is new Run_Parse_Only (Str_Encodings.T, Str_Encodings.Parse, Str_Encodings.Valid);
   procedure Run_Default_Endian_Expr_Is_Le is new
     Run_Parse_Only (Default_Endian_Expr_Is_Le.T, Default_Endian_Expr_Is_Le.Parse, Default_Endian_Expr_Is_Le.Valid);
   procedure Run_Valid_Fail_Eq_Int is new
     Run_Parse_Only (Valid_Fail_Eq_Int.T, Valid_Fail_Eq_Int.Parse, Valid_Fail_Eq_Int.Valid);

   procedure Run_Params_Def (Input : Bytes; Argument : U16; Fields : out Natural) is
      S : Stream := Open (Input);
      R : Params_Def.T;
   begin
      Params_Def.Parse (Input, S, U32 (Argument mod 64), Argument mod 2 = 0, R);
      pragma Assert (Params_Def.Valid (R) = OK (S));
      Fields := (if Params_Def.Valid (R) then 1 else 0);
   end Run_Params_Def;

   procedure Run_Outside is new Run_Parse_Only (Outside.T, Outside.Parse, Outside.Valid);

   --  Parse Input, write the result and compare: what is written is what
   --  was read, and as long
   procedure Run_Write_Model (Input : Bytes; Argument : U16; Fields : out Natural) is
      S      : Stream := Open (Input);
      R      : Write_Model.T;
      Output : Bytes (1 .. 600) := (others => 0);
      W      : Kaitai.Writers.Writer;
   begin
      Fields := 0;
      Write_Model.Parse (Input, S, Argument, R);
      pragma Assert (Write_Model.Valid (R) = OK (S));
      if not Write_Model.Valid (R) then
         return;
      end if;
      Fields := 1;
      W := Kaitai.Writers.Open (Output);
      Write_Model.Write (Input, R, Output, W);
      pragma Assert (Kaitai.Writers.OK (W));
      pragma Assert (Kaitai.Writers.Pos (W) = Pos (S));
      pragma Assert (Output (1 .. Pos (S)) = Input (Input'First .. Input'First + Pos (S) - 1));
   end Run_Write_Model;

   procedure Run_Imports0 (Input : Bytes; Fields : out Natural) is
      S : Stream := Open (Input);
      R : Imports0.T;
   begin
      Fields := 0;
      Imports0.Parse (Input, S, R);
      pragma Assert (Imports0.Valid (R) = OK (S));
      if not Imports0.Valid (R) then
         return;
      end if;
      Fields := 1;
      Count (Fields, Imports0.Two (R) = 0);
      Count (Fields, Hello_World.One (Imports0.Hw (R)) = 0);
      if Imports0.Has_Hw_One (R) then
         Count (Fields, Imports0.Hw_One (R) = 0);
      end if;
   end Run_Imports0;

   procedure Run_Expr_Sizeof_Type_0 (Input : Bytes; Fields : out Natural) is
      package Blocks renames Expr_Sizeof_Type_0.Block_Type;

      S : Stream := Open (Input);
      R : Expr_Sizeof_Type_0.T;
      B : Blocks.T;
   begin
      Fields := 0;
      Expr_Sizeof_Type_0.Parse (Input, S, R);
      pragma Assert (Expr_Sizeof_Type_0.Valid (R) = OK (S));
      if Expr_Sizeof_Type_0.Valid (R) then
         Fields := 1;
         Count (Fields, Expr_Sizeof_Type_0.Sizeof_Block (R) = 7);
      end if;

      --  The type that the instance measures is not part of the parsed one, so it is parsed on its own
      S := Open (Input);
      Blocks.Parse (Input, S, B);
      pragma Assert (Blocks.Valid (B) = OK (S));
      if Blocks.Valid (B) then
         Count (Fields);
         Count (Fields, Blocks.A (B) = 0 or else Blocks.B (B) = 0);
         Count (Fields, Within (Blocks.C (B), Input));
      end if;
   end Run_Expr_Sizeof_Type_0;

   procedure Run_Expr_Sizeof_Value_Sized (Input : Bytes; Fields : out Natural) is
      S : Stream := Open (Input);
      R : Expr_Sizeof_Value_Sized.T;
   begin
      Fields := 0;
      Expr_Sizeof_Value_Sized.Parse (Input, S, R);
      pragma Assert (Expr_Sizeof_Value_Sized.Valid (R) = OK (S));
      if Expr_Sizeof_Value_Sized.Valid (R) then
         Fields := 1;
         Count (Fields, Expr_Sizeof_Value_Sized.More (R) = 0);
         Count (Fields, Expr_Sizeof_Value_Sized.Self_Sizeof (R) = 14);
         Count (Fields, Expr_Sizeof_Value_Sized.Sizeof_Block (R) = 12);
         Count (Fields, Expr_Sizeof_Value_Sized.Sizeof_Block_A (R) = 1);
         Count (Fields, Expr_Sizeof_Value_Sized.Sizeof_Block_B (R) = 4);
         Count (Fields, Expr_Sizeof_Value_Sized.Sizeof_Block_C (R) = 2);
         Count (Fields, Expr_Sizeof_Value_Sized.Block_Type.Valid (Expr_Sizeof_Value_Sized.Block1 (R)));
      end if;
   end Run_Expr_Sizeof_Value_Sized;

   procedure Run_Subscripts (Input : Bytes; Fields : out Natural) is
      S        : Stream := Open (Input);
      R        : Subscripts.T;
      Element  : Slice;
      Position : Subscripts.Records_Cursor;
   begin
      Fields := 0;
      Subscripts.Parse (Input, S, R);
      pragma Assert (Subscripts.Valid (R) = OK (S));
      if not Subscripts.Valid (R) then
         return;
      end if;
      Fields := 1;
      Count (Fields, Subscripts.Qty (R) = Subscripts.Pick (R));
      Count (Fields, Within (Subscripts.Raw (R), Input));

      for I in 0 .. Subscripts.Items_Count (R) - 1 loop
         Count (Fields, Subscripts.Items (Input, R, I) = 0);
      end loop;

      Position := Subscripts.Records_First (R);
      while Subscripts.Has_Element (Position) loop
         Subscripts.Next (Input, R, Position, Element);
         Count (Fields, Within (Element, Input));
      end loop;
      for I in 0 .. Subscripts.Records_Count (R) - 1 loop
         Subscripts.Get_Records (Input, R, I, Element);
         Count (Fields, Within (Element, Input));
      end loop;

      --  The instances that index are defined only where the index is in range
      if Subscripts.Has_First_Item (Input, R) then
         Count (Fields, Subscripts.First_Item (Input, R) = 0);
      end if;
      if Subscripts.Has_Chosen_Item (Input, R) then
         Count (Fields, Subscripts.Chosen_Item (Input, R) = 0);
      end if;
      if Subscripts.Has_Raw_Mid (Input, R) then
         Count (Fields, Subscripts.Raw_Mid (Input, R) = 0);
      end if;
      if Subscripts.Has_Chosen_Raw (Input, R) then
         Count (Fields, Subscripts.Chosen_Raw (Input, R) = 0);
      end if;
   end Run_Subscripts;

   procedure Run_Valid_Fail_Repeat_Eq_Int (Input : Bytes; Fields : out Natural) is
      S : Stream := Open (Input);
      R : Valid_Fail_Repeat_Eq_Int.T;
   begin
      Fields := 0;
      Valid_Fail_Repeat_Eq_Int.Parse (Input, S, R);
      pragma Assert (Valid_Fail_Repeat_Eq_Int.Valid (R) = OK (S));
      if not Valid_Fail_Repeat_Eq_Int.Valid (R) then
         return;
      end if;
      Fields := 1;
      for I in 0 .. Valid_Fail_Repeat_Eq_Int.Foo_Count (R) - 1 loop
         Count (Fields, Valid_Fail_Repeat_Eq_Int.Foo (Input, R, I) = 16#1234_5678#);
      end loop;
   end Run_Valid_Fail_Repeat_Eq_Int;

   --  The fields of the parsers that have a Write, read from the buffer that the value was parsed from

   procedure Read_Term_Struct (Buffer : Bytes; R : Term_Struct.T; Fields : in out Natural) is
   begin
      Count (Fields, Within (Term_Struct.Bytes_Wrapper_Type.Value (Term_Struct.S1 (R)), Buffer));
      Count (Fields, Within (Term_Struct.Bytes_Wrapper_Type.Value (Term_Struct.S2 (R)), Buffer));
      Count (Fields, Within (Term_Struct.Bytes_Wrapper_Type.Value (Term_Struct.S3 (R)), Buffer));
   end Read_Term_Struct;

   procedure Read_Bytes_Pad_Term_Equal (Buffer : Bytes; R : Bytes_Pad_Term_Equal.T; Fields : in out Natural) is
   begin
      Count (Fields, Within (Bytes_Pad_Term_Equal.S1 (R), Buffer));
      Count (Fields, Within (Bytes_Pad_Term_Equal.S2 (R), Buffer));
      Count (Fields, Within (Bytes_Pad_Term_Equal.S3 (R), Buffer));
      Count (Fields, Within (Bytes_Pad_Term_Equal.S4 (R), Buffer));
   end Read_Bytes_Pad_Term_Equal;

   procedure Read_Term_Strz4 (Buffer : Bytes; R : Term_Strz4.T; Fields : in out Natural) is
   begin
      Count (Fields, Within (Term_Strz4.S1_Type_Type.Value (Term_Strz4.S1 (R)), Buffer));
      Count (Fields, Term_Strz4.Skip_Term1 (R) = 16#7C#);
      Count (Fields, Within (Term_Strz4.S2_Type_Type.Value (Term_Strz4.S2 (R)), Buffer));
      Count (Fields, Term_Strz4.Skip_Term2 (R) = 16#7C#);
      Count (Fields, Within (Term_Strz4.S3_Type_Type.Value (Term_Strz4.S3 (R)), Buffer));
   end Read_Term_Strz4;

   procedure Read_Bytes_Pad_Term (Buffer : Bytes; R : Bytes_Pad_Term.T; Fields : in out Natural) is
   begin
      Count (Fields, Within (Bytes_Pad_Term.Str_Pad (R), Buffer));
      Count (Fields, Within (Bytes_Pad_Term.Str_Term (R), Buffer));
      Count (Fields, Within (Bytes_Pad_Term.Str_Term_And_Pad (R), Buffer));
      Count (Fields, Within (Bytes_Pad_Term.Str_Term_Include (R), Buffer));
   end Read_Bytes_Pad_Term;

   procedure Read_Str_Eos_Pad_Term (Buffer : Bytes; R : Str_Eos_Pad_Term.T; Fields : in out Natural) is
   begin
      Count (Fields, Within (Str_Eos_Pad_Term.Str_Pad_Type_Type.Value (Str_Eos_Pad_Term.Str_Pad (R)), Buffer));
      Count (Fields, Within (Str_Eos_Pad_Term.Str_Term_Type_Type.Value (Str_Eos_Pad_Term.Str_Term (R)), Buffer));
      Count
        (Fields,
         Within (Str_Eos_Pad_Term.Str_Term_And_Pad_Type_Type.Value (Str_Eos_Pad_Term.Str_Term_And_Pad (R)), Buffer));
      Count
        (Fields,
         Within (Str_Eos_Pad_Term.Str_Term_Include_Type_Type.Value (Str_Eos_Pad_Term.Str_Term_Include (R)), Buffer));
   end Read_Str_Eos_Pad_Term;

   --  Parse Input and read the result; if the parse is valid, write the value into a target of twice the size
   --  plus 16 bytes and, if the writer succeeds, parse what was written, which has to be valid as well, and
   --  read that too.  Fixed_Size is True where every field of the description has a size of its own and the
   --  parse takes exactly that many bytes: then the writer has to succeed and to write as many bytes as were
   --  read.  Where a field is cut at a terminator or runs to the end of its window, the output can have another
   --  length (a terminator is added, a field is padded) and the writer may run out of room, which is not
   --  asserted against.
   generic
      type T is private;
      with procedure Parse (Buffer : Bytes; S : in out Stream; This : out T);
      with function Valid (This : T) return Boolean;
      with procedure Write (Buffer : Bytes; This : T; Target : in out Bytes; W : in out Kaitai.Writers.Writer);
      with procedure Read_All (Buffer : Bytes; This : T; Fields : in out Natural);
      Fixed_Size : Boolean;
   procedure Run_Write_Target (Input : Bytes; Fields : out Natural);

   procedure Run_Write_Target (Input : Bytes; Fields : out Natural) is
      S      : Stream := Open (Input);
      R      : T;
      Output : Bytes (1 .. 2 * Input'Length + 16) := (others => 0);
      W      : Kaitai.Writers.Writer;
   begin
      Fields := 0;
      Parse (Input, S, R);
      pragma Assert (Valid (R) = OK (S));
      if not Valid (R) then
         return;
      end if;
      Fields := 1;
      Read_All (Input, R, Fields);
      W := Kaitai.Writers.Open (Output);
      Write (Input, R, Output, W);
      if Fixed_Size then
         pragma Assert (Kaitai.Writers.OK (W));
         pragma Assert (Kaitai.Writers.Pos (W) = Pos (S));
      end if;
      if not Kaitai.Writers.OK (W) then
         return;
      end if;
      declare
         Written : Bytes renames Output (1 .. Kaitai.Writers.Pos (W));
         Again   : Stream := Open (Written);
         Second  : T;
      begin
         Parse (Written, Again, Second);
         pragma Assert (Valid (Second) = OK (Again));
         pragma Assert (Valid (Second));
         Read_All (Written, Second, Fields);
      end;
   end Run_Write_Target;

   procedure Run_Term_Struct is new
     Run_Write_Target (Term_Struct.T, Term_Struct.Parse, Term_Struct.Valid, Term_Struct.Write, Read_Term_Struct, False);
   procedure Run_Bytes_Pad_Term_Equal is new
     Run_Write_Target
       (Bytes_Pad_Term_Equal.T,
        Bytes_Pad_Term_Equal.Parse,
        Bytes_Pad_Term_Equal.Valid,
        Bytes_Pad_Term_Equal.Write,
        Read_Bytes_Pad_Term_Equal,
        True);
   procedure Run_Term_Strz4 is new
     Run_Write_Target (Term_Strz4.T, Term_Strz4.Parse, Term_Strz4.Valid, Term_Strz4.Write, Read_Term_Strz4, False);
   procedure Run_Bytes_Pad_Term is new
     Run_Write_Target
       (Bytes_Pad_Term.T,
        Bytes_Pad_Term.Parse,
        Bytes_Pad_Term.Valid,
        Bytes_Pad_Term.Write,
        Read_Bytes_Pad_Term,
        True);
   procedure Run_Str_Eos_Pad_Term is new
     Run_Write_Target
       (Str_Eos_Pad_Term.T,
        Str_Eos_Pad_Term.Parse,
        Str_Eos_Pad_Term.Valid,
        Str_Eos_Pad_Term.Write,
        Read_Str_Eos_Pad_Term,
        True);

   procedure Run_Switch_Bytearray is new
     Run_Parse_Only (Switch_Bytearray.T, Switch_Bytearray.Parse, Switch_Bytearray.Valid);

   procedure Run_Switch_Else_Only is new
     Run_Parse_Only (Switch_Else_Only.T, Switch_Else_Only.Parse, Switch_Else_Only.Valid);

   procedure Run_Valid_Switch is new Run_Parse_Only (Valid_Switch.T, Valid_Switch.Parse, Valid_Switch.Valid);

   procedure Run_Str_Literals_Latin1 is new
     Run_Parse_Only (Str_Literals_Latin1.T, Str_Literals_Latin1.Parse, Str_Literals_Latin1.Valid);

   procedure Run_Str_Literal_Encodings (Input : Bytes; Fields : out Natural) is
      S : Stream := Open (Input);
      R : Str_Literal_Encodings.T;
   begin
      Fields := 0;
      Str_Literal_Encodings.Parse (Input, S, R);
      pragma Assert (Str_Literal_Encodings.Valid (R) = OK (S));
      if Str_Literal_Encodings.Valid (R) then
         Fields := 1;
         Count (Fields, Str_Literal_Encodings.Latin1_Is_Pound (Input, R));
         Count (Fields, Str_Literal_Encodings.Utf8_Is_Pound (Input, R));
         Count (Fields, Str_Literal_Encodings.Utf16le_Is_Pound_Euro (Input, R));
         Count (Fields, Str_Literal_Encodings.Utf16be_Is_Grin (Input, R));
         Count (Fields, Str_Literal_Encodings.Utf16be_Is_Not_Grin (Input, R));
         Count (Fields, Str_Literal_Encodings.Ascii_Has_Newline (Input, R));
         Count (Fields, Str_Literal_Encodings.Grin_Length (R) = 1);
      end if;
   end Run_Str_Literal_Encodings;

   procedure Run_Expr_To_I_Trailing (Input : Bytes; Fields : out Natural) is
      S : Stream := Open (Input);
      R : Expr_To_I_Trailing.T;
   begin
      Fields := 0;
      Expr_To_I_Trailing.Parse (Input, S, R);
      pragma Assert (Expr_To_I_Trailing.Valid (R) = OK (S));
      if Expr_To_I_Trailing.Valid (R) then
         Fields := 1;
         Count (Fields, not Expr_To_I_Trailing.Has_To_I_R10 (R));
         Count (Fields, Expr_To_I_Trailing.To_I_R16 (R) = 16#9173ABC#);
         Count (Fields, not Expr_To_I_Trailing.Has_To_I_Garbage (R));
      end if;
   end Run_Expr_To_I_Trailing;

   procedure Run_Valid_Fail_Range_Str is new
     Run_Parse_Only (Valid_Fail_Range_Str.T, Valid_Fail_Range_Str.Parse, Valid_Fail_Range_Str.Valid);

   procedure Run_Str_Ordering (Input : Bytes; Fields : out Natural) is
      S : Stream := Open (Input);
      R : Str_Ordering.T;
   begin
      Fields := 0;
      Str_Ordering.Parse (Input, S, R);
      pragma Assert (Str_Ordering.Valid (R) = OK (S));
      if Str_Ordering.Valid (R) then
         Fields := 1;
         Count (Fields, Str_Ordering.A_Lt_B (Input, R));
         Count (Fields, Str_Ordering.A_Le_B (Input, R));
         Count (Fields, Str_Ordering.A_Gt_Pound (Input, R));
         Count (Fields, Str_Ordering.Pound_Ge_B (Input, R));
         Count (Fields, Str_Ordering.Literals (R));
      end if;
   end Run_Str_Ordering;

   procedure Run_Valid_Long is new Run_Parse_Only (Valid_Long.T, Valid_Long.Parse, Valid_Long.Valid);

   procedure Run_Yaml_Ints is new Run_Parse_Only (Yaml_Ints.T, Yaml_Ints.Parse, Yaml_Ints.Valid);

   procedure Run_Enum_Long_Range_U is new
     Run_Parse_Only (Enum_Long_Range_U.T, Enum_Long_Range_U.Parse, Enum_Long_Range_U.Valid);

   procedure Run_Foreign (Input : Bytes; Fields : out Natural) is
      S       : Stream := Open (Input);
      R       : Foreign.T;
      Frame   : Foreign.Frame_Type.T;
      Element : Timestamp.T;
      Storage : Bytes (3 .. 12) := (others => 0);
      Last    : Length;
      Outcome : Status_Kind;
   begin
      Fields := 0;
      Foreign.Parse (Input, S, R);
      pragma Assert (Foreign.Valid (R) = OK (S));
      if not Foreign.Valid (R) then
         return;
      end if;
      Fields := 1;
      Count (Fields, Timestamp.Seconds (Foreign.Stamp (R)) = 0);
      Foreign.Text (Input, R, Storage, Last, Outcome);
      pragma Assert ((Outcome = Success) = (Size (Foreign.Text_Raw (R)) <= Storage'Length));
      Count (Fields, Outcome = Success and then Last >= Storage'First);
      Foreign.Frame (Input, R, Storage, Frame, Outcome);
      pragma Assert (Foreign.Frame_Type.Valid (Frame) = (Outcome = Success));
      if Foreign.Frame_Type.Valid (Frame) then
         Count (Fields, Foreign.Frame_Type.A (Frame) = 0 or else Foreign.Frame_Type.B (Frame) = 0);
      end if;
      for I in 0 .. Foreign.Stamps_Count (R) - 1 loop
         Foreign.Get_Stamps (Input, R, I, Element);
         pragma Assert (Timestamp.Valid (Element));
         Count (Fields, Timestamp.Seconds (Element) = 0);
      end loop;
   end Run_Foreign;

   procedure Run (T : Target; Input : Bytes; Argument : U16; Fields : out Natural) is
   begin
      case T is
         when Showcase_Parser                  =>
            Run_Showcase (Input, Argument, Fields);

         when Extras_Parser                    =>
            Run_Extras (Input, Fields);

         when Write_Model_Parser               =>
            Run_Write_Model (Input, Argument, Fields);

         when Params_Def_Parser                =>
            Run_Params_Def (Input, Argument, Fields);

         when Outside_Parser                   =>
            Run_Outside (Input, Fields);

         when Hello_World_Parser               =>
            Run_Hello_World (Input, Fields);

         when Fixed_Struct_Parser              =>
            Run_Fixed_Struct (Input, Fields);

         when Bits_Simple_Parser               =>
            Run_Bits_Simple (Input, Fields);

         when Bits_Enum_Parser                 =>
            Run_Bits_Enum (Input, Fields);

         when Bits_In_Types_Parser             =>
            Run_Bits_In_Types (Input, Fields);

         when Bits_In_Repeat_Parser            =>
            Run_Bits_In_Repeat (Input, Fields);

         when Bits_After_Bytes_Parser          =>
            Run_Bits_After_Bytes (Input, Fields);

         when Bits_First_Type_Parser           =>
            Run_Bits_First_Type (Input, Fields);

         when Bits_Byte_Aligned_Parser         =>
            Run_Bits_Byte_Aligned (Input, Fields);

         when Term_Strz_Parser                 =>
            Run_Term_Strz (Input, Fields);

         when Repeat_N_Struct_Parser           =>
            Run_Repeat_N_Struct (Input, Fields);

         when Repeat_N_Empty_Parser            =>
            Run_Repeat_N_Empty (Input, Fields);

         when Repeat_Eos_U4_Parser             =>
            Run_Repeat_Eos_U4 (Input, Fields);

         when Repeat_Until_Complex_Parser      =>
            Run_Repeat_Until_Complex (Input, Fields);

         when Switch_Manual_Int_Parser         =>
            Run_Switch_Manual_Int (Input, Fields);

         when Enum_0_Parser                    =>
            Run_Enum_0 (Input, Fields);

         when If_Struct_Parser                 =>
            Run_If_Struct (Input, Fields);

         when Expr_1_Parser                    =>
            Run_Expr_1 (Input, Fields);

         when Instance_Std_Parser              =>
            Run_Instance_Std (Input, Fields);

         when Position_Abs_Parser              =>
            Run_Position_Abs (Input, Fields);

         when Str_Encodings_Parser             =>
            Run_Str_Encodings (Input, Fields);

         when Default_Endian_Expr_Is_Le_Parser =>
            Run_Default_Endian_Expr_Is_Le (Input, Fields);

         when Valid_Fail_Eq_Int_Parser         =>
            Run_Valid_Fail_Eq_Int (Input, Fields);

         when Imports0_Parser                  =>
            Run_Imports0 (Input, Fields);

         when Term_Struct_Parser               =>
            Run_Term_Struct (Input, Fields);

         when Bytes_Pad_Term_Equal_Parser      =>
            Run_Bytes_Pad_Term_Equal (Input, Fields);

         when Expr_Sizeof_Type_0_Parser        =>
            Run_Expr_Sizeof_Type_0 (Input, Fields);

         when Term_Strz4_Parser                =>
            Run_Term_Strz4 (Input, Fields);

         when Bytes_Pad_Term_Parser            =>
            Run_Bytes_Pad_Term (Input, Fields);

         when Str_Eos_Pad_Term_Parser          =>
            Run_Str_Eos_Pad_Term (Input, Fields);

         when Subscripts_Parser                =>
            Run_Subscripts (Input, Fields);

         when Valid_Fail_Repeat_Eq_Int_Parser  =>
            Run_Valid_Fail_Repeat_Eq_Int (Input, Fields);

         when Expr_Sizeof_Value_Sized_Parser   =>
            Run_Expr_Sizeof_Value_Sized (Input, Fields);

         when Switch_Bytearray_Parser          =>
            Run_Switch_Bytearray (Input, Fields);

         when Switch_Else_Only_Parser          =>
            Run_Switch_Else_Only (Input, Fields);

         when Valid_Switch_Parser              =>
            Run_Valid_Switch (Input, Fields);

         when Str_Literals_Latin1_Parser       =>
            Run_Str_Literals_Latin1 (Input, Fields);

         when Str_Literal_Encodings_Parser     =>
            Run_Str_Literal_Encodings (Input, Fields);

         when Expr_To_I_Trailing_Parser        =>
            Run_Expr_To_I_Trailing (Input, Fields);

         when Valid_Fail_Range_Str_Parser      =>
            Run_Valid_Fail_Range_Str (Input, Fields);

         when Str_Ordering_Parser              =>
            Run_Str_Ordering (Input, Fields);

         when Valid_Long_Parser                =>
            Run_Valid_Long (Input, Fields);

         when Yaml_Ints_Parser                 =>
            Run_Yaml_Ints (Input, Fields);

         when Enum_Long_Range_U_Parser         =>
            Run_Enum_Long_Range_U (Input, Fields);

         when Foreign_Parser                   =>
            Run_Foreign (Input, Fields);
      end case;
   end Run;

end Fuzz_Targets;
