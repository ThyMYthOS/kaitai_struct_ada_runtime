--  Ways to keep the integer arithmetic of an expression from overflowing.
--  Arith_Runs compares them with each other and with unguarded arithmetic.
--
--    Kaitai.Arithmetic  a function per operation tells whether it would
--                       overflow; the parser asks before it computes
--    Checked            a value carries a validity flag, the operators hand
--                       it on, and the parser looks at the flag at the end
--    Flagged            a procedure per operation with a flag that stays
--                       False once an operation has overflowed

with Kaitai.Types; use Kaitai.Types;

package Arith_Variants is

   package Checked is

      type Int is record
         Value : S64;
         Valid : Boolean;
      end record;

      function To_Int (Value : S64) return Int
      is (Value => Value, Valid => True)
      with Inline;

      function "+" (Left, Right : Int) return Int
      with Inline;

      function "-" (Left, Right : Int) return Int
      with Inline;

      function "*" (Left, Right : Int) return Int
      with Inline;

   end Checked;

   package Flagged is

      procedure Add (Left, Right : S64; Result : out S64; OK : in out Boolean)
      with Inline;

      procedure Subtract (Left, Right : S64; Result : out S64; OK : in out Boolean)
      with Inline;

      procedure Multiply (Left, Right : S64; Result : out S64; OK : in out Boolean)
      with Inline;

   end Flagged;

end Arith_Variants;
