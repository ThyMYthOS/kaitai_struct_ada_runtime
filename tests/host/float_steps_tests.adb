with Float_Steps;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Sample_Data;
with Test_Support;   use Test_Support;

package body Float_Steps_Tests is

   --  The bytes of a float of 4 bytes, from its bits, and of a float of 8 bytes, little endian
   function F4 (Bits : U32) return Bytes
   is (1 => U8 (Bits mod 256), 2 => U8 (Bits / 256 mod 256), 3 => U8 (Bits / 65536 mod 256), 4 => U8 (Bits / 16777216));

   function F8 (Bits : U64) return Bytes
   is (1 => U8 (Bits mod 256),
       2 => U8 (Bits / 256 mod 256),
       3 => U8 (Bits / 65536 mod 256),
       4 => U8 (Bits / 16777216 mod 256),
       5 => U8 (Bits / 4294967296 mod 256),
       6 => U8 (Bits / 1099511627776 mod 256),
       7 => U8 (Bits / 281474976710656 mod 256),
       8 => U8 (Bits / 72057594037927936));

   --  The bytes of a text, and of one or two bytes
   function Text (Characters : String) return Bytes is
      Result : Bytes (1 .. Characters'Length);
   begin
      for I in Result'Range loop
         Result (I) := U8 (Character'Pos (Characters (Characters'First + Natural (I - 1))));
      end loop;
      return Result;
   end Text;

   function Pair (A, B : U8) return Bytes
   is (1 => A, 2 => B);

   function Single (A : U8) return Bytes
   is (1 => A);

   --  Floats of 4 bytes
   Zero         : constant U32 := 16#0000_0000#;
   Half         : constant U32 := 16#3F00_0000#;
   One          : constant U32 := 16#3F80_0000#;
   Two          : constant U32 := 16#4000_0000#;
   Two_Half     : constant U32 := 16#4020_0000#;
   Three        : constant U32 := 16#4040_0000#;
   Neg_One      : constant U32 := 16#BF80_0000#;
   Hundred_One  : constant U32 := 16#42CA_0000#;
   Huge         : constant U32 := 16#7149_F2CA#;   --  1E30
   Three_E9     : constant U32 := 16#4F32_D05E#;   --  3E9
   Plus_Inf     : constant U32 := 16#7F80_0000#;
   Not_A_Number : constant U32 := 16#7FC0_0000#;

   --  Floats of 8 bytes
   One8          : constant U64 := 16#3FF0_0000_0000_0000#;
   Quarter8      : constant U64 := 16#3FD0_0000_0000_0000#;
   Five8         : constant U64 := 16#4014_0000_0000_0000#;
   Five_Hundred8 : constant U64 := 16#407F_4000_0000_0000#;
   Plus_Inf8     : constant U64 := 16#7FF0_0000_0000_0000#;
   Not_A_Number8 : constant U64 := 16#7FF8_0000_0000_0000#;

   --  A record whose fields are all there, with the given scale, gain and count (the rest as in the sample)
   function Full (Scale : U32; Gain : U64; Count : U32 := Two) return Bytes
   is (F4 (Scale)
       & F8 (Gain)
       & Pair (7, 9)
       & Text ("ABCDEF")
       & F4 (Count)
       & Pair (10, 11)
       & F4 (One)
       & F4 (Two_Half)
       & Single (16#55#)
       & Text ("0123456789!?;"));

   --  A record where none of the optional fields is there: a scale of 0.5 and a gain of 0.25
   Sparse : constant Bytes :=
     F4 (Half) & F8 (Quarter8) & Single (7) & Text ("A") & F4 (Zero) & F4 (Three) & Text ("0123456789");

   procedure Run is
      use Float_Steps;
      Data : constant Bytes := Sample_Data.Float_Steps;
      S    : Stream := Open (Data);
      This : Float_Steps.T;

      --  Parses Input and tells why it failed
      function Failure (Input : Bytes) return Status_Kind is
         Local : Stream := Open (Input);
         Value : Float_Steps.T;
      begin
         Parse (Value, Input, Local);
         pragma Assert (Valid (Value) = OK (Local));
         return Status (Local);
      end Failure;
   begin
      Group ("examples float_steps");
      Parse (This, Data, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Mode (This) = 7, "the field before the first condition");
         Check (Has_Boost (This) and then Boost (This) = 9, "a condition on a float that holds");
         Check (Size (Label (This)) = 6, "a size computed from a float with to_i");
         Check (Weights_Count (This) = 2 and then Weights (This, Data, 1) = 11, "a count computed from a float");
         Check (Samples_Count (This) = 2, "a repetition that ends on a float");
         Check (Has_Trailer (This) and then Trailer (This) = 16#55#, "a condition that compares two computed values");
         Check (Size (Tail (This)) = 13, "a size that is computed from a float and a literal");
         Check (Has_Doubled_Scale (This) and then Doubled_Scale (This) = 6.0, "a value instance");
      end if;
      Check (Failure (Full (Three, Five8)) = Success, "the sample as the builder makes it");

      --  nothing is optional
      declare
         Value : Float_Steps.T;
         Local : Stream := Open (Sparse);
      begin
         Parse (Value, Sparse, Local);
         Check (Valid (Value), "a record without the optional fields parses");
         if Valid (Value) then
            Check (not Has_Boost (Value), "a scale of 0.5 is not above 1.0");
            Check (not Has_Trailer (Value), "0.5 is not above 1.5");
            Check (Size (Label (Value)) = 1, "a size of 1 from 2 * 0.5");
            Check (Weights_Count (Value) = 0, "a count of 0.5 is 0");
            Check (Samples_Count (Value) = 1, "the first sample ends the repetition");
            Check (Size (Tail (Value)) = 10, "a size of 10 from 0.5 + 10.0");
         end if;
      end;

      --  the limits of scale
      Check (Failure (Full (Neg_One, Five8)) = Validation_Less_Than, "a scale below 0");
      Check (Failure (Full (Hundred_One, One8)) = Validation_Greater_Than, "a scale above 100");
      Check
        (Failure (Full (Not_A_Number, One8)) = Validation_Less_Than, "a scale that is not a number is not at least 0");
      Check (Failure (Full (Plus_Inf, One8)) = Validation_Greater_Than, "an infinite scale is above 100");
      --  an expression of valid
      Check (Failure (Full (Three, Five_Hundred8)) = Validation_Expr, "gain * scale is above 1000");
      Check (Failure (Full (Three, Plus_Inf8)) = Arithmetic_Error, "an infinite gain has no product");
      Check (Failure (Full (Three, Not_A_Number8)) = Arithmetic_Error, "a gain that is not a number has no product");
      --  a count computed from a float
      Check (Failure (Full (Three, Five8, Count => Not_A_Number)) = Arithmetic_Error, "a count that is not a number");
      Check (Failure (Full (Three, Five8, Count => Huge)) = Arithmetic_Error, "a count of 1E30 is no integer");
      Check
        (Failure (Full (Three, Five8, Count => Three_E9)) = End_Of_Stream,
         "a count of 3E9 in a few bytes ends the data, and nothing is allocated for it");
      --  a repetition that does not end
      Check
        (Failure (F4 (Three) & F8 (Five8) & Pair (7, 9) & Text ("ABCDEF") & F4 (Zero) & F4 (One) & F4 (One))
         = End_Of_Stream,
         "a repetition whose end does not come ends with the data");
      --  a gain that is not above the scale: the trailer is not there, and the record is valid
      Check (Failure (Full (Three, One8)) = Success, "a gain of 1.0 and a scale of 3.0 are valid");
   end Run;

end Float_Steps_Tests;
