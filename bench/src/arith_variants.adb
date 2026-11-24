with Kaitai.Arithmetic; use Kaitai.Arithmetic;

package body Arith_Variants is

   package body Checked is

      function "+" (Left, Right : Int) return Int is
      begin
         if Left.Valid and then Right.Valid and then Add_OK (Left.Value, Right.Value) then
            return (Value => Left.Value + Right.Value, Valid => True);
         else
            return (Value => 0, Valid => False);
         end if;
      end "+";

      function "-" (Left, Right : Int) return Int is
      begin
         if Left.Valid and then Right.Valid and then Subtract_OK (Left.Value, Right.Value) then
            return (Value => Left.Value - Right.Value, Valid => True);
         else
            return (Value => 0, Valid => False);
         end if;
      end "-";

      function "*" (Left, Right : Int) return Int is
      begin
         if Left.Valid and then Right.Valid and then Multiply_OK (Left.Value, Right.Value) then
            return (Value => Multiply (Left.Value, Right.Value), Valid => True);
         else
            return (Value => 0, Valid => False);
         end if;
      end "*";

   end Checked;

   package body Flagged is

      procedure Add (Left, Right : S64; Result : out S64; OK : in out Boolean) is
      begin
         if OK and then Add_OK (Left, Right) then
            Result := Left + Right;
         else
            Result := 0;
            OK := False;
         end if;
      end Add;

      procedure Subtract (Left, Right : S64; Result : out S64; OK : in out Boolean) is
      begin
         if OK and then Subtract_OK (Left, Right) then
            Result := Left - Right;
         else
            Result := 0;
            OK := False;
         end if;
      end Subtract;

      procedure Multiply (Left, Right : S64; Result : out S64; OK : in out Boolean) is
      begin
         if OK and then Multiply_OK (Left, Right) then
            Result := Kaitai.Arithmetic.Multiply (Left, Right);
         else
            Result := 0;
            OK := False;
         end if;
      end Multiply;

   end Flagged;

end Arith_Variants;
