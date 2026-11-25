--  Integer arithmetic for the expressions of a description.  Expressions are
--  computed in S64, and what a parser reads decides the operands, so every
--  operation that can overflow comes with a function that tells whether it
--  would.  Generated code asks that function first and lets the stream fail
--  with Arithmetic_Error otherwise:
--
--     if Multiply_OK (A, B) then
--        Size := Multiply (A, B);
--     else
--        Fail (S, Arithmetic_Error);
--     end if;
--
--  Nothing here raises an exception, and a parser that respects the
--  preconditions is proven not to overflow.

with Kaitai.Decoding; use Kaitai.Decoding;
with Kaitai.Types;    use Kaitai.Types;

package Kaitai.Arithmetic
  with Pure, SPARK_Mode, Always_Terminates
is

   --  The functions whose names end in _OK tell whether the operation they
   --  stand for is defined: Add_OK (Left, Right) whether Left + Right is in
   --  S64, and so on.

   --  True if Left + Right does not overflow
   function Add_OK (Left, Right : S64) return Boolean
   is (if Right >= 0 then Left <= S64'Last - Right else Left >= S64'First - Right)
   with Inline;

   --  True if Left - Right does not overflow
   function Subtract_OK (Left, Right : S64) return Boolean
   is (if Right >= 0 then Left >= S64'First + Right else Left <= S64'Last + Right)
   with Inline;

   --  True if -Value does not overflow, which it does for S64'First only
   function Negate_OK (Value : S64) return Boolean
   is (Value /= S64'First)
   with Inline;

   --  Add_OK and the like are followed by the operator itself.  For a
   --  product there is Multiply: its precondition is all a parser has to
   --  show, and that the product does not overflow is proven here once.

   --  True if Left * Right does not overflow
   function Multiply_OK (Left, Right : S64) return Boolean
   with Inline;

   --  Left * Right
   function Multiply (Left, Right : S64) return S64
   with Inline, Pre => Multiply_OK (Left, Right);

   --  True if Divide (Left, Right) is defined: the divisor is not 0 and the
   --  quotient does not overflow, as it does for S64'First / -1
   function Divide_OK (Left, Right : S64) return Boolean
   is (Right /= 0 and then not (Left = S64'First and then Right = -1))
   with Inline;

   --  The "/" of the expression language for integers: the quotient
   --  rounded down, so that Divide (-7, 2) is -4.  This is what the tests
   --  of Kaitai Struct ask for, and it goes with Modulo: for a positive
   --  divisor, Divide (A, B) * B + Modulo (A, B) is A.
   function Divide (Left, Right : S64) return S64
   is (if Left rem Right /= 0 and then (Left < 0) /= (Right < 0) then Left / Right - 1 else Left / Right)
   with Inline, Pre => Divide_OK (Left, Right);

   --  True if Modulo can be used with this divisor, which has to be positive
   function Modulo_OK (Right : S64) return Boolean
   is (Right > 0)
   with Inline;

   --  The "%" of the expression language: never negative, so that
   --  Modulo (-5, 3) is 1.  It is only defined for a positive divisor.
   function Modulo (Left, Right : S64) return S64
   is (Left mod Right)
   with Inline, Pre => Modulo_OK (Right), Post => Modulo'Result in 0 .. Right - 1;

   --  True if Value can be used as an operand, which a u8 above the
   --  largest S64 cannot
   function Fits (Value : U64) return Boolean
   is (Value <= U64 (S64'Last))
   with Inline;

   --  The bitwise operators of the expression language.  They work on the
   --  two's complement of their operands, as in the other targets.

   --  Bit by bit and
   function Bit_And (Left, Right : S64) return S64
   is (To_S64 (U64'Mod (Left) and U64'Mod (Right)))
   with Inline;

   --  Bit by bit inclusive or
   function Bit_Or (Left, Right : S64) return S64
   is (To_S64 (U64'Mod (Left) or U64'Mod (Right)))
   with Inline;

   --  Bit by bit exclusive or
   function Bit_Xor (Left, Right : S64) return S64
   is (To_S64 (U64'Mod (Left) xor U64'Mod (Right)))
   with Inline;

   --  True if Amount is a valid shift distance, 0 to 63
   function Shift_OK (Amount : S64) return Boolean
   is (Amount in 0 .. 63)
   with Inline;

   --  The "<<" of the expression language.  Bits shifted out at the top
   --  are lost, as in Java and Go.
   function Bit_Shift_Left (Value, Amount : S64) return S64
   is (To_S64 (Shift_Left (U64'Mod (Value), Natural (Amount))))
   with Inline, Pre => Shift_OK (Amount);

   --  The ">>" of the expression language.  The sign is kept, so that the
   --  result is that of a division by a power of two rounded down.
   function Bit_Shift_Right (Value, Amount : S64) return S64
   is (To_S64 (Shift_Right_Arithmetic (U64'Mod (Value), Natural (Amount))))
   with Inline, Pre => Shift_OK (Amount);

private

   subtype Half is S64 range -2**31 .. 2**31 - 1;

   --  Two operands of 32 bits cannot overflow, which settles most cases
   --  without a division.  Otherwise the quotient of the bound and one
   --  operand limits the other; -1 is taken out first, because dividing
   --  the lower bound by it overflows itself.
   function Multiply_OK (Left, Right : S64) return Boolean
   is (if Left in Half and then Right in Half
       then True
       elsif Left = 0 or else Right = 0
       then True
       elsif Left = -1
       then Right /= S64'First
       elsif Right = -1
       then Left /= S64'First
       elsif Left > 0 and then Right > 0
       then Left <= S64'Last / Right
       elsif Left < 0 and then Right < 0
       then Left >= S64'Last / Right
       elsif Left > 0
       then Right >= S64'First / Left
       else Left >= S64'First / Right);

   function Multiply (Left, Right : S64) return S64
   is (Left * Right);

end Kaitai.Arithmetic;
