with Kaitai.Arithmetic; use Kaitai.Arithmetic;
with Kaitai.Types;      use Kaitai.Types;
with Test_Support;      use Test_Support;

package body Arithmetic_Tests is

   --  Operands around every bound that matters: zero, the limits of S64,
   --  the limits of 32 bits, where Multiply_OK changes its method, and the
   --  square root of the largest S64
   Values : constant array (1 .. 27) of S64 :=
     (0,
      1,
      -1,
      2,
      -2,
      3,
      -3,
      7,
      -7,
      2**31 - 1,
      2**31,
      2**31 + 1,
      -2**31,
      -2**31 - 1,
      2**32,
      -2**32,
      3_037_000_499,
      3_037_000_500,
      -3_037_000_499,
      -3_037_000_500,
      2**62,
      -2**62,
      2**62 + 1,
      S64'Last,
      S64'Last - 1,
      S64'First,
      S64'First + 1);

   --  What the functions under test are compared with is computed in U64,
   --  in a way that has nothing in common with how they work

   function Magnitude (Value : S64) return U64
   is (if Value >= 0 then U64 (Value) elsif Value = S64'First then 2**63 else U64 (-Value));

   function Sum_Fits (Left, Right : S64) return Boolean is
      Wrapped : constant U64 := U64'Mod (Left) + U64'Mod (Right);
   begin
      --  A sum overflows if both operands have the sign the result lacks
      return (Left < 0) /= (Right < 0) or else (Wrapped >= 2**63) = (Left < 0);
   end Sum_Fits;

   function Difference_Fits (Left, Right : S64) return Boolean is
      Wrapped : constant U64 := U64'Mod (Left) - U64'Mod (Right);
   begin
      return (Left < 0) = (Right < 0) or else (Wrapped >= 2**63) = (Left < 0);
   end Difference_Fits;

   function Product_Fits (Left, Right : S64) return Boolean is
      Bound : constant U64 := (if (Left < 0) = (Right < 0) then 2**63 - 1 else 2**63);
   begin
      return Left = 0 or else Right = 0 or else Magnitude (Left) <= Bound / Magnitude (Right);
   end Product_Fits;

   procedure Test_Guards is
      Add_Wrong, Subtract_Wrong, Multiply_Wrong, Product_Wrong : Natural := 0;
   begin
      Group ("Arithmetic guards");
      for L of Values loop
         for R of Values loop
            if Add_OK (L, R) /= Sum_Fits (L, R) then
               Add_Wrong := Add_Wrong + 1;
            end if;
            if Subtract_OK (L, R) /= Difference_Fits (L, R) then
               Subtract_Wrong := Subtract_Wrong + 1;
            end if;
            if Multiply_OK (L, R) /= Product_Fits (L, R) then
               Multiply_Wrong := Multiply_Wrong + 1;
            elsif Multiply_OK (L, R) and then U64'Mod (Multiply (L, R)) /= U64'Mod (L) * U64'Mod (R) then
               Product_Wrong := Product_Wrong + 1;
            end if;
         end loop;
      end loop;
      Check (Add_Wrong = 0, "Add_OK for all pairs of operands");
      Check (Subtract_Wrong = 0, "Subtract_OK for all pairs of operands");
      Check (Multiply_Wrong = 0, "Multiply_OK for all pairs of operands");
      Check (Product_Wrong = 0, "Multiply for all pairs it is defined for");

      Check (Add_OK (S64'Last, 0) and then not Add_OK (S64'Last, 1), "sum at the upper bound");
      Check (Add_OK (S64'First, 0) and then not Add_OK (S64'First, -1), "sum at the lower bound");
      Check (Subtract_OK (S64'First, 0) and then not Subtract_OK (S64'First, 1), "difference at the lower bound");
      Check (Subtract_OK (-1, S64'Last) and then not Subtract_OK (0, S64'First), "difference of the bounds");
      Check (Multiply_OK (2**31, 2**31) and then not Multiply_OK (2**32, 2**31), "product of powers of two");
      Check (Multiply_OK (S64'First, 1) and then not Multiply_OK (S64'First, -1), "product with the lower bound");
      Check (Multiply_OK (-2**31, 2**32) and then not Multiply_OK (-2**31, -2**32), "the lower bound as a product");
      Check (Multiply (3_037_000_499, 3_037_000_499) = 9_223_372_030_926_249_001, "largest square");
      Check (Multiply (-7, 3) = -21 and then Multiply (-7, -3) = 21, "signs");
      Check (Negate_OK (S64'Last) and then not Negate_OK (S64'First), "negation");
      Check (Fits (0) and then Fits (2**63 - 1) and then not Fits (2**63) and then not Fits (U64'Last), "u8 operand");
   end Test_Guards;

   procedure Test_Division is
   begin
      Group ("Arithmetic division");
      Check (Divide (7, 2) = 3 and then Divide (-7, 2) = -4, "the quotient is rounded down");
      Check (Divide (7, -2) = -4 and then Divide (-7, -2) = 3, "also for a negative divisor");
      Check (Divide (6, 2) = 3 and then Divide (-6, 2) = -3 and then Divide (6, -2) = -3, "exact quotients");
      Check (Divide (-9837, 13) = -757 and then Divide (-52947, 13) = -4073, "the values of the Kaitai Struct tests");
      Check (Divide (-1, S64'Last) = -1 and then Divide (1, S64'First) = -1, "the smallest fractions");
      Check (Divide (S64'First, 1) = S64'First and then Divide (S64'Last, -1) = -S64'Last, "bounds");
      Check (Divide (S64'First, 2) = -2**62 and then Divide (S64'First + 1, 2) = -2**62, "near the lower bound");
      Check (Divide (S64'First, S64'Last) = -2 and then Divide (S64'Last, S64'First) = -1, "the bounds by each other");
      declare
         Wrong : Natural := 0;
      begin
         --  With a positive divisor the quotient and Modulo make up the
         --  dividend; computed in U64, since the product can leave S64
         for L of Values loop
            for R of Values loop
               if R > 0 and then U64'Mod (Divide (L, R)) * U64'Mod (R) + U64'Mod (Modulo (L, R)) /= U64'Mod (L) then
                  Wrong := Wrong + 1;
               end if;
            end loop;
         end loop;
         Check (Wrong = 0, "quotient times divisor plus Modulo is the dividend");
      end;
      Check (not Divide_OK (1, 0) and then not Divide_OK (0, 0), "no division by zero");
      Check (not Divide_OK (S64'First, -1) and then Divide_OK (S64'First + 1, -1), "the one quotient that overflows");
      Check (Modulo (5, 3) = 2 and then Modulo (-5, 3) = 1, "modulo is never negative");
      Check (Modulo (-3, 3) = 0 and then Modulo (0, 3) = 0 and then Modulo (-1, 3) = 2, "modulo around zero");
      Check (Modulo (S64'First, S64'Last) = S64'Last - 1, "modulo of the bounds");
      Check (Modulo (S64'First, 1) = 0 and then Modulo (S64'Last, 1) = 0, "modulo one");
      Check (Modulo_OK (1) and then not Modulo_OK (0) and then not Modulo_OK (-3), "only a positive divisor");
   end Test_Division;

   procedure Test_Bits is
   begin
      Group ("Arithmetic bit operations");
      Check (Bit_And (16#F0F0#, 16#FF00#) = 16#F000#, "and");
      Check (Bit_Or (16#F0F0#, 16#FF00#) = 16#FFF0#, "or");
      Check (Bit_Xor (16#F0F0#, 16#FF00#) = 16#0FF0#, "xor");
      Check (Bit_And (-1, 16#1234#) = 16#1234#, "minus one has all bits set");
      Check (Bit_Or (S64'First, S64'Last) = -1, "the bounds together are all bits");
      Check (Bit_Xor (-1, S64'Last) = S64'First, "xor up to the sign");
      Check (Bit_And (-2, -3) = -4, "and of negative operands");
      Check (Bit_Shift_Left (1, 0) = 1 and then Bit_Shift_Left (1, 10) = 1024, "shift to the left");
      Check (Bit_Shift_Left (1, 62) = 2**62 and then Bit_Shift_Left (1, 63) = S64'First, "into the sign");
      Check (Bit_Shift_Left (-1, 4) = -16 and then Bit_Shift_Left (3, 63) = S64'First, "bits shifted out are lost");
      Check (Bit_Shift_Right (1024, 10) = 1 and then Bit_Shift_Right (1023, 10) = 0, "shift to the right");
      Check (Bit_Shift_Right (-16, 4) = -1 and then Bit_Shift_Right (-17, 4) = -2, "rounds down for a negative value");
      Check (Bit_Shift_Right (S64'First, 63) = -1 and then Bit_Shift_Right (S64'Last, 63) = 0, "by the largest amount");
      Check (Shift_OK (0) and then Shift_OK (63) and then not Shift_OK (64) and then not Shift_OK (-1), "amounts");
   end Test_Bits;

   procedure Run is
   begin
      Test_Guards;
      Test_Division;
      Test_Bits;
   end Run;

end Arithmetic_Tests;
