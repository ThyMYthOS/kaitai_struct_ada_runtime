--  The parsers that Fuzz_Main feeds, each with inputs to start from and a
--  procedure that parses an input.  For the first two it also reads
--  everything from the result, and for the third it writes the result and
--  compares it with the input; for the others it only parses, which still
--  runs every check and contract of the parser.

with Kaitai.Types; use Kaitai.Types;

package Fuzz_Targets is

   type Target is
     (Showcase_Parser,
      Extras_Parser,
      Write_Model_Parser,
      Hello_World_Parser,
      Fixed_Struct_Parser,
      Bits_Simple_Parser,
      Bits_Enum_Parser,
      Bits_Byte_Aligned_Parser,
      Term_Strz_Parser,
      Repeat_N_Struct_Parser,
      Repeat_Eos_U4_Parser,
      Repeat_Until_Complex_Parser,
      Switch_Manual_Int_Parser,
      Enum_0_Parser,
      If_Struct_Parser,
      Expr_1_Parser,
      Instance_Std_Parser,
      Position_Abs_Parser,
      Str_Encodings_Parser,
      Default_Endian_Expr_Is_Le_Parser,
      Valid_Fail_Eq_Int_Parser,
      Params_Def_Parser,
      Imports0_Parser,
      Term_Struct_Parser,
      Bytes_Pad_Term_Equal_Parser,
      Expr_Sizeof_Type_0_Parser,
      Term_Strz4_Parser,
      Bytes_Pad_Term_Parser,
      Str_Eos_Pad_Term_Parser,
      Subscripts_Parser,
      Valid_Fail_Repeat_Eq_Int_Parser,
      Expr_Sizeof_Value_Sized_Parser,
      Switch_Bytearray_Parser,
      Switch_Else_Only_Parser);

   --  An input the parser accepts.  Round selects one where there are
   --  several.
   function Seed (T : Target; Round : Positive) return Bytes;

   --  Parse Input and read every field, element and instance of the
   --  result.  Fields is the number of values read, 0 if the parser did
   --  not accept the input.  Argument is used where a parser has a
   --  parameter.
   procedure Run (T : Target; Input : Bytes; Argument : U16; Fields : out Natural);

end Fuzz_Targets;
