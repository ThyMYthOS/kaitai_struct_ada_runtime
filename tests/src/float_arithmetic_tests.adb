with Kaitai.Float_Arithmetic; use Kaitai.Float_Arithmetic;
with Kaitai.Floats;           use Kaitai.Floats;
with Kaitai.Types;            use Kaitai.Types;
with Test_Support;            use Test_Support;

package body Float_Arithmetic_Tests is

   --  2**Exponent, for Exponent from -1074 to 1023, made from its bits
   function Pow2 (Exponent : Integer) return F64
   is (To_F64
         (if Exponent >= -1022 then Shift_Left (U64 (Exponent + 1023), 52) else Shift_Left (U64'(1), Exponent + 1074)));

   --  The largest number below 2**Exponent, for Exponent from -1021 to 1023
   function Below_Pow2 (Exponent : Integer) return F64
   is (To_F64 (Shift_Left (U64 (Exponent + 1023), 52) - 1));

   --  The finite number of a pattern of 64 bits: one that is not is made
   --  finite by clearing the lowest bit of the exponent
   function Finite_Number (Bits : U64) return F64
   is (To_F64 (if Is_Finite (Bits) then Bits else Bits and not 16#0010_0000_0000_0000#));

   --  True if the number is neither an infinity nor a not-a-number.  It is
   --  not written as a test of the number against itself and F64'Last alone
   --  so that the compiler cannot take a finite number for granted.
   function Is_Number (Value : F64) return Boolean
   is (Value - Value = 0.0 and then abs Value <= F64'Last);

   --  The numbers that matter: zero, one, the bounds in the functions and
   --  the limits of the type, each with both signs
   type Value_List is array (Positive range <>) of F64;

   function Special_Values return Value_List
   is ((0.0,
        1.0,
        -1.0,
        0.5,
        -0.5,
        3.0,
        -7.25,
        1.0E10,
        -1.0E-10,
        Pow2 (-1074),
        -Pow2 (-1074),
        Pow2 (-1022),
        -Pow2 (-1022),
        Below_Pow2 (1),
        Pow2 (-600),
        Pow2 (-171),
        -Pow2 (-1026),
        Pow2 (63),
        Pow2 (500),
        -Pow2 (500),
        Below_Pow2 (501),
        Pow2 (511),
        Pow2 (600),
        Pow2 (852),
        -Pow2 (852),
        Pow2 (1009),
        Pow2 (1010),
        Pow2 (1021),
        Pow2 (1022),
        -Pow2 (1022),
        Below_Pow2 (1023),
        Pow2 (1023),
        -Pow2 (1023),
        F64'Last,
        F64'First));

   --  A pseudo random sequence of 64 bit patterns
   function Next (State : U64) return U64
   is (State * 6_364_136_223_846_793_005 + 1_442_695_040_888_963_407);

   --  Count the operand pairs for which an operation that was declared
   --  defined has a result that is not a number.  Those are what the
   --  functions must never allow.
   procedure Test_Never_Overflows is
      Specials                                  : constant Value_List := Special_Values;
      Add_Wrong, Subtract_Wrong, Multiply_Wrong : Natural := 0;
      Add_Right, Multiply_Right                 : Natural := 0;
      State                                     : U64 := 1;

      procedure Try (Left, Right : F64) is
      begin
         if Add_OK (Left, Right) then
            Add_Right := Add_Right + 1;
            if not Is_Number (Add (Left, Right)) then
               Add_Wrong := Add_Wrong + 1;
            end if;
         end if;
         if Subtract_OK (Left, Right) and then not Is_Number (Subtract (Left, Right)) then
            Subtract_Wrong := Subtract_Wrong + 1;
         end if;
         if Multiply_OK (Left, Right) then
            Multiply_Right := Multiply_Right + 1;
            if not Is_Number (Multiply (Left, Right)) then
               Multiply_Wrong := Multiply_Wrong + 1;
            end if;
         end if;
      end Try;
   begin
      Group ("Float guards: sound");
      for L of Specials loop
         for R of Specials loop
            Try (L, R);
         end loop;
      end loop;
      --  The exponent of a random pattern is uniform, so that all magnitudes
      --  meet, and the mantissa is random
      for I in 1 .. 400 loop
         State := Next (State);
         declare
            Left : constant F64 := Finite_Number (State);
         begin
            State := Next (State);
            Try (Left, Finite_Number (State));
         end;
      end loop;
      --  Pairs of one magnitude, where a sum or a product is at the limit
      for I in 1 .. 80 loop
         State := Next (State);
         declare
            Left : constant F64 := Finite_Number (State);
         begin
            Try (Left, Left);
            Try (Left, -Left);
            Try (Left, 2.0);
            Try (Left, 0.5);
            Try (2.0, Left);
         end;
      end loop;
      Check (Add_Wrong = 0, "no sum is infinite");
      Check (Subtract_Wrong = 0, "no difference is infinite");
      Check (Multiply_Wrong = 0, "no product is infinite");
      --  The test is of no use if the functions never say yes
      Check (Add_Right > 500 and then Multiply_Right > 300, "the functions do say yes");
   end Test_Never_Overflows;

   --  What the functions accept, by the powers of two: 2**I and 2**J, and
   --  the numbers just below them, with all signs
   procedure Test_Accepts is
      Exponents                                                  : constant array (1 .. 26) of Integer :=
        (-1074,
         -1022,
         -1021,
         -1000,
         -600,
         -171,
         -1,
         0,
         1,
         2,
         63,
         300,
         499,
         500,
         501,
         512,
         513,
         511,
         600,
         851,
         852,
         853,
         1009,
         1010,
         1022,
         1023);
      Add_Missed, Multiply_Missed, Add_Allowed, Multiply_Allowed : Natural := 0;

      procedure Try (Left, Right : F64; I, J : Integer) is
      begin
         --  A sum or difference is accepted if the operands have opposite
         --  signs, and if both are at most 2**1022
         if I <= 1022 and then J <= 1022 and then (not Add_OK (Left, Right) or else not Subtract_OK (Left, Right)) then
            Add_Missed := Add_Missed + 1;
         end if;
         if (Left >= 0.0) /= (Right >= 0.0) and then not Add_OK (Left, Right) then
            Add_Missed := Add_Missed + 1;
         end if;
         if (Left >= 0.0) = (Right >= 0.0) and then not Subtract_OK (Left, Right) then
            Add_Missed := Add_Missed + 1;
         end if;
         --  A product is accepted if it is at most 2**500, which the
         --  exponents of the largest numbers below 2**I and 2**J show
         if I + J <= 500 and then not Multiply_OK (Left, Right) then
            Multiply_Missed := Multiply_Missed + 1;
         end if;
         --  Nothing that overflows is accepted
         if I + J >= 1024 and then Multiply_OK (Left, Right) then
            Multiply_Allowed := Multiply_Allowed + 1;
         end if;
         if I >= 1023 and then J >= 1023 and then (Left >= 0.0) = (Right >= 0.0) and then Add_OK (Left, Right) then
            Add_Allowed := Add_Allowed + 1;
         end if;
      end Try;
   begin
      Group ("Float guards: complete");
      for I of Exponents loop
         for J of Exponents loop
            --  Below a power of two the number is not the power, and the
            --  largest one below 2**I has the exponent I - 1 at the bound,
            --  which is how the bounds above are phrased
            Try (Pow2 (I), Pow2 (J), I, J);
            Try (-Pow2 (I), Pow2 (J), I, J);
            Try (Pow2 (I), -Pow2 (J), I, J);
            Try (-Pow2 (I), -Pow2 (J), I, J);
            if I >= -1021 and then J >= -1021 then
               Try (Below_Pow2 (I), Below_Pow2 (J), I, J);
               Try (-Below_Pow2 (I), Below_Pow2 (J), I, J);
            end if;
         end loop;
      end loop;
      Check (Add_Missed = 0, "sums and differences that are accepted");
      Check (Multiply_Missed = 0, "products that are accepted");
      Check (Add_Allowed = 0, "an overflowing sum is not accepted");
      Check (Multiply_Allowed = 0, "an overflowing product is not accepted");
      Check (Add_OK (1.0E308, -1.0E308) and then Add (1.0E308, -1.0E308) = 0.0, "huge numbers that cancel");
      Check (Add_OK (1.0E300, 1.0E300) and then Add (1.0E300, 1.0E300) = 2.0E300, "huge numbers, not enormous");
      Check (not Add_OK (F64'Last, 1.0), "an operand above 2**1022 with the same sign is not accepted");
      Check (not Add_OK (F64'Last, F64'Last), "the sum of two largest numbers");
      Check (not Subtract_OK (F64'Last, F64'First), "the difference of the extremes");
      Check (Multiply_OK (F64'Last, 1.0) and then Multiply_OK (F64'Last, -0.5), "a product of at most the factor");
      Check (not Multiply_OK (F64'Last, 2.0), "the product of the largest number and 2 overflows");
      Check (not Multiply_OK (1.0E200, 1.0E200), "1E200 times 1E200");
      Check (Multiply_OK (1.0E200, 1.0E60) and then Multiply (1.0E200, 1.0E60) > 9.9E259, "1E200 times 1E60");
      Check
        (Multiply_OK (1.0E150, 1.0E150) and then Multiply_OK (1.0E60, 1.0E200), "1E150 times 1E150, 1E60 times 1E200");
      Check (not Multiply_OK (1.0E200, 1.0E100) and then not Multiply_OK (1.0E160, 1.0E150), "refused: 1E200 * 1E100");
   end Test_Accepts;

   --  The values that a description would compute, also those of the tests
   --  of Kaitai Struct: floating_points, float_to_i and expr_ops_parens
   procedure Test_Values is
   begin
      Group ("Float operations");
      Check (Add (0.5, 1.0) = 1.5, "0.5 + 1");
      Check (abs (Add (0.25, 0.05) - 0.3) < 1.0E-15, "0.25 + 0.05");
      Check (Subtract (0.5, 1.0) = -0.5 and then Subtract (-0.0, 0.0) = 0.0, "subtraction");
      Check (Multiply (-1.5, 4.0) = -6.0 and then Multiply (0.1, 10.0) = 1.0, "multiplication");
      Check (-Pow2 (1023) < 0.0 and then -(-Pow2 (1023)) = Pow2 (1023) and then -Pow2 (-1074) < 0.0, "negation");
      Check (From_S64 (S64'First) = -9.223_372_036_854_775_808E18, "S64'First as a float");
      Check (From_S64 (S64'Last) = 9.223_372_036_854_775_808E18, "S64'Last rounds up to 2**63");
      Check (From_S64 (2**53 + 1) = 9_007_199_254_740_992.0, "a tie rounds to even, down");
      Check (From_S64 (2**53 + 3) = 9_007_199_254_740_996.0, "a tie rounds to even, up");
      Check (From_S64 (-(2**53) - 1) = -9_007_199_254_740_992.0, "a negative tie");
      Check (From_S64 (7) = 7.0 and then From_S64 (0) = 0.0, "small integers are exact");
      Check (From_F32 (0.5) = 0.5 and then From_F32 (F32'Last) = 3.402_823_466_385_288_6E38, "f4 widened");
      Check (From_F32 (0.1) = 0.100_000_001_490_116_119_384_765_625, "f4 0.1 is not 0.1");
      Check (From_F32 (To_F32 (1)) > 0.0 and then From_F32 (F32'First) < -3.4E38, "f4 limits");
      Check (Add (From_F32 (To_F32 (16#3F00_0000#)), From_S64 (1)) = 1.5, "an f4 and an integer");
      Check (Multiply (From_F32 (F32'Last), From_F32 (F32'Last)) > 1.0E77, "f4 times f4 exceeds the range of f4");
   end Test_Values;

   procedure Test_Truncate is
      Edge : constant F64 := Pow2 (63) - 1024.0;
   begin
      Group ("Float Truncate");
      Check (Truncate_OK (0.0) and then Truncate (0.0) = 0, "0");
      Check (Truncate (0.5) = 0 and then Truncate (-0.5) = 0, "plus and minus a half");
      Check (Truncate (1.234) = 1 and then Truncate (1.5) = 1 and then Truncate (1.9) = 1, "positive");
      Check (Truncate (-2.7) = -2 and then Truncate (-1.5) = -1 and then Truncate (-1.0) = -1, "negative");
      Check (Truncate (13.9) = 13 and then Truncate (9.0) = 9, "13.9 and 9");
      Check (Truncate (Add (6.28, 2.72)) = 9, "6.28 + 2.72");
      Check (Truncate (To_F64 (16#3FEF_FFFF_FFFF_FFFF#)) = 0, "the largest number below 1");
      Check (Truncate (To_F64 (16#BFEF_FFFF_FFFF_FFFF#)) = 0, "the smallest number above -1");
      Check (Truncate (Pow2 (-1074)) = 0 and then Truncate (-Pow2 (-1074)) = 0, "the smallest numbers");
      Check (Truncate (4_503_599_627_370_497.0) = 4_503_599_627_370_497, "2**52 + 1");
      Check (Truncate (4_503_599_627_370_496.5) = 4_503_599_627_370_496, "2**52 + 0.5 as it is stored");
      Check (Truncate (-4_503_599_627_370_495.5) = -4_503_599_627_370_495, "-(2**52 - 0.5)");
      Check (Truncate_OK (Edge) and then Truncate (Edge) = 9_223_372_036_854_774_784, "the largest number below 2**63");
      Check (Truncate_OK (-Pow2 (63)) and then Truncate (-Pow2 (63)) = S64'First, "-2**63 is S64'First");
      Check (not Truncate_OK (Pow2 (63)), "2**63 is not an S64");
      Check (not Truncate_OK (-Pow2 (63) - 2048.0), "the number below -2**63 is not an S64");
      Check (not Truncate_OK (F64'Last) and then not Truncate_OK (F64'First), "the extremes are not");
   end Test_Truncate;

   procedure Run is
   begin
      Test_Never_Overflows;
      Test_Accepts;
      Test_Values;
      Test_Truncate;
   end Run;

end Float_Arithmetic_Tests;
