--  Floating point arithmetic for the expressions of a description.  It is
--  the counterpart of Kaitai.Arithmetic for the numbers of Kaitai.Floats,
--  and works the same way: every operation that can leave the range of the
--  type comes with a function that tells whether it would, and generated
--  code asks that function first and lets the stream fail with
--  Arithmetic_Error otherwise.
--
--  All arithmetic is in F64, a binary64 number.  A value of f4 is widened to
--  it, an integer is converted to it, and the result of an expression is
--  an F64.  Other targets deliver an infinity or a not-a-number when an
--  operation overflows or has no result, and go on computing with it.  An
--  expression here has no value then, as one with an integer overflow has
--  none, so that no infinity and no not-a-number ever exists.  Underflow is
--  not an error: a result too small for a normal number is a denormal
--  number or zero, as in IEEE 754.
--
--  Division is not here.  A quotient is finite only if a condition on both
--  operands holds that GNATprove does not prove at level 1 with a margin
--  that a shared machine can rely on, so the backend keeps rejecting it.
--
--  The arithmetic is in binary64 for the operands of f4 too, as in the
--  Python target.  The Java, C++, C# and Go targets compute an f4 with an
--  integer or with another f4 in binary32, so that the results of such an
--  expression can differ from these in the last bits.
--
--  GNATprove has to show for every operation that its result is finite, and
--  it can do so at level 1 only if the condition compares the operands with
--  constants.  The functions whose names end in _OK are therefore stricter
--  than the exact condition for operands of immense magnitude, and each
--  says which.  They accept every operation whose operands are at most
--  2**500 in magnitude, about 3.27E150; what they refuse although the
--  result would be finite has an operand above that.

with Kaitai.Floats; use Kaitai.Floats;
with Kaitai.Types;  use Kaitai.Types;

package Kaitai.Float_Arithmetic
  with Pure, SPARK_Mode, Always_Terminates
is

   --  Largest magnitude of an operand for which a sum or difference cannot
   --  leave the range, 2**1022
   Add_Limit : constant := 2.0**1022;

   --  Largest magnitude of both operands for which a product cannot leave the
   --  range, 2**500, about 3.27E150
   Multiply_Limit : constant := 2.0**500;

   --  The conversions into F64.  Their results lie in subtypes that say how
   --  large they can be, so that an operation on them can be shown not to
   --  overflow from the types alone, without asking Add_OK and the like.

   --  The numbers that an f4 can be, of at most 3.4028234663852886E+38 in
   --  magnitude
   subtype F32_Operand is F64 range -3.4028234663852886E+38 .. 3.4028234663852886E+38;

   --  The numbers that an integer of S64 can become, of at most 2**63 in
   --  magnitude
   subtype S64_Operand is F64 range -2.0**63 .. 2.0**63;

   --  The value of an f4 as an F64, which is the same number
   function From_F32 (Value : F32) return F32_Operand
   is (F64 (Value))
   with Inline;

   --  The integer as an F64.  Above 2**53 an integer is not always a number
   --  of F64, and the nearest one is taken, the one with the even mantissa if
   --  two are equally near, as Python and Java do for the conversion that an
   --  expression with an integer and a float makes.
   function From_S64 (Value : S64) return S64_Operand
   is (F64 (Value))
   with Inline;

   --  The functions whose names end in _OK tell whether the operation they
   --  stand for is defined: Add_OK (Left, Right) whether Left + Right is a
   --  finite number, and so on.

   --  True if Left + Right is finite.  It is true if the operands have
   --  opposite signs, and if both have a magnitude of at most Add_Limit, which
   --  is 2**1022, about 4.49E307.  It is false if they have the same sign and
   --  one is larger, although the sum can still be finite then.
   function Add_OK (Left, Right : F64) return Boolean
   is ((abs Left <= Add_Limit and then abs Right <= Add_Limit) or else (Left >= 0.0) /= (Right >= 0.0))
   with Inline;

   --  Left + Right
   function Add (Left, Right : F64) return F64
   is (Left + Right)
   with Inline, Pre => Add_OK (Left, Right), Post => Add'Result = Left + Right;

   --  True if Left - Right is finite: Add_OK for the negated right operand
   function Subtract_OK (Left, Right : F64) return Boolean
   is ((abs Left <= Add_Limit and then abs Right <= Add_Limit) or else (Left >= 0.0) = (Right >= 0.0))
   with Inline;

   --  Left - Right
   function Subtract (Left, Right : F64) return F64
   is (Left - Right)
   with Inline, Pre => Subtract_OK (Left, Right), Post => Subtract'Result = Left - Right;

   --  True if Left * Right is finite.  It is true if one operand has a
   --  magnitude of at most 1, or if the magnitudes are at most 2**500 and
   --  2**500 (3.3E150 each), 2**900 and 2**100 (8.5E270 and 1.3E30), or
   --  2**700 and 2**300 (5.2E210 and 2.0E90), in either order.  It is false
   --  otherwise, although the product can still be finite: 1E200 * 1E100
   --  (the operands are above 2**700 and 2**300) and 1E160 * 1E150 are
   --  refused, 1E200 * 1E60 and 1E150 * 1E150 are accepted.  Every
   --  product of at most 2**500 in magnitude is accepted.
   function Multiply_OK (Left, Right : F64) return Boolean
   is (abs Left <= 1.0
       or else abs Right <= 1.0
       or else (abs Left <= Multiply_Limit and then abs Right <= Multiply_Limit)
       or else (abs Left <= 2.0**900 and then abs Right <= 2.0**100)
       or else (abs Right <= 2.0**900 and then abs Left <= 2.0**100)
       or else (abs Left <= 2.0**700 and then abs Right <= 2.0**300)
       or else (abs Right <= 2.0**700 and then abs Left <= 2.0**300))
   with Inline;

   --  Left * Right
   function Multiply (Left, Right : F64) return F64
   is (Left * Right)
   with Inline, Pre => Multiply_OK (Left, Right), Post => Multiply'Result = Left * Right;

   --  True if the number can be converted by Truncate: the integer part of it
   --  is in S64
   function Truncate_OK (Value : F64) return Boolean
   is (Value >= -2.0**63 and then Value < 2.0**63)
   with Inline;

   --  The to_i of the expression language: the integer part of the number,
   --  which is the number with the places after the point cut off, so that
   --  Truncate (-2.7) is -2 and Truncate (1.9) is 1
   function Truncate (Value : F64) return S64
   is (if Value >= 0.0 then S64 (F64'Floor (Value)) else S64 (F64'Ceiling (Value)))
   with Inline, Pre => Truncate_OK (Value);

end Kaitai.Float_Arithmetic;
