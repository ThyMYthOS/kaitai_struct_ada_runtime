with Arith_Variants;
with Kaitai.Arithmetic; use Kaitai.Arithmetic;
with Kaitai.Decoding;
with Kaitai.Streams;    use Kaitai.Streams;

package body Arith_Runs is

   procedure Prepare (Data : in out Bytes) is
      First : Length := Data'First;
   begin
      while Data'Last - First >= 14 loop
         Data (First + 7 .. First + 9) := [others => 0];
         First := First + 15;
      end loop;
   end Prepare;

   function Mix (Sum : U64; X, Y : S64) return U64
   is (Sum * 31 + U64'Mod (X) + U64'Mod (Y));

   procedure Parse_Plain (Data : Bytes; S : in out Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Plain (Data : Bytes; S : in out Stream; Sum : in out U64) is
      L    : Stream := S;
      A    : U8;
      B    : U16;
      C    : U32;
      D    : U64;
      E    : S64;
      X, Y : S64;
   begin
      loop
         Read_U1 (Data, L, A);
         Read_U2le (Data, L, B);
         Read_U4le (Data, L, C);
         Read_U8be (Data, L, D);
         exit when not OK (L);
         E := Kaitai.Decoding.To_S64 (D);
         X := S64 (C) * S64 (B) + S64 (A) - 7;
         Y := E * S64 (B) + S64 (C);
         Sum := Mix (Sum, X, Y);
      end loop;
      S := L;
   end Parse_Plain;

   function Run_Plain (Data : Bytes) return U64 is
      S   : Stream := Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Plain (Data, S, Sum);
      return Sum;
   end Run_Plain;

   procedure Parse_Guarded (Data : Bytes; S : in out Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Guarded (Data : Bytes; S : in out Stream; Sum : in out U64) is
      L    : Stream := S;
      A    : U8;
      B    : U16;
      C    : U32;
      D    : U64;
      E    : S64;
      X, Y : S64;
   begin
      loop
         Read_U1 (Data, L, A);
         Read_U2le (Data, L, B);
         Read_U4le (Data, L, C);
         Read_U8be (Data, L, D);
         exit when not OK (L);
         E := Kaitai.Decoding.To_S64 (D);
         if Multiply_OK (S64 (C), S64 (B))
           and then Add_OK (Multiply (S64 (C), S64 (B)), S64 (A))
           and then Subtract_OK (Multiply (S64 (C), S64 (B)) + S64 (A), 7)
         then
            X := Multiply (S64 (C), S64 (B)) + S64 (A) - 7;
         else
            Fail (L, Arithmetic_Error);
            exit;
         end if;
         if Multiply_OK (E, S64 (B)) and then Add_OK (Multiply (E, S64 (B)), S64 (C)) then
            Y := Multiply (E, S64 (B)) + S64 (C);
         else
            Fail (L, Arithmetic_Error);
            exit;
         end if;
         Sum := Mix (Sum, X, Y);
      end loop;
      S := L;
   end Parse_Guarded;

   function Run_Guarded (Data : Bytes) return U64 is
      S   : Stream := Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Guarded (Data, S, Sum);
      return Sum;
   end Run_Guarded;

   procedure Parse_Guarded_Where_Needed (Data : Bytes; S : in out Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Guarded_Where_Needed (Data : Bytes; S : in out Stream; Sum : in out U64) is
      L    : Stream := S;
      A    : U8;
      B    : U16;
      C    : U32;
      D    : U64;
      E    : S64;
      X, Y : S64;
   begin
      loop
         Read_U1 (Data, L, A);
         Read_U2le (Data, L, B);
         Read_U4le (Data, L, C);
         Read_U8be (Data, L, D);
         exit when not OK (L);
         E := Kaitai.Decoding.To_S64 (D);
         X := S64 (C) * S64 (B) + S64 (A) - 7;
         if Multiply_OK (E, S64 (B)) and then Add_OK (Multiply (E, S64 (B)), S64 (C)) then
            Y := Multiply (E, S64 (B)) + S64 (C);
         else
            Fail (L, Arithmetic_Error);
            exit;
         end if;
         Sum := Mix (Sum, X, Y);
      end loop;
      S := L;
   end Parse_Guarded_Where_Needed;

   function Run_Guarded_Where_Needed (Data : Bytes) return U64 is
      S   : Stream := Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Guarded_Where_Needed (Data, S, Sum);
      return Sum;
   end Run_Guarded_Where_Needed;

   procedure Parse_Checked (Data : Bytes; S : in out Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Checked (Data : Bytes; S : in out Stream; Sum : in out U64) is
      use Arith_Variants.Checked;
      L    : Stream := S;
      A    : U8;
      B    : U16;
      C    : U32;
      D    : U64;
      E    : S64;
      X, Y : Int;
   begin
      loop
         Read_U1 (Data, L, A);
         Read_U2le (Data, L, B);
         Read_U4le (Data, L, C);
         Read_U8be (Data, L, D);
         exit when not OK (L);
         E := Kaitai.Decoding.To_S64 (D);
         X := To_Int (S64 (C)) * To_Int (S64 (B)) + To_Int (S64 (A)) - To_Int (7);
         Y := To_Int (E) * To_Int (S64 (B)) + To_Int (S64 (C));
         if not (X.Valid and then Y.Valid) then
            Fail (L, Arithmetic_Error);
            exit;
         end if;
         Sum := Mix (Sum, X.Value, Y.Value);
      end loop;
      S := L;
   end Parse_Checked;

   function Run_Checked (Data : Bytes) return U64 is
      S   : Stream := Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Checked (Data, S, Sum);
      return Sum;
   end Run_Checked;

   procedure Parse_Flagged (Data : Bytes; S : in out Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Flagged (Data : Bytes; S : in out Stream; Sum : in out U64) is
      use Arith_Variants.Flagged;
      L      : Stream := S;
      A      : U8;
      B      : U16;
      C      : U32;
      D      : U64;
      E      : S64;
      T1, T2 : S64;
      X, Y   : S64;
      Fine   : Boolean;
   begin
      loop
         Read_U1 (Data, L, A);
         Read_U2le (Data, L, B);
         Read_U4le (Data, L, C);
         Read_U8be (Data, L, D);
         exit when not OK (L);
         E := Kaitai.Decoding.To_S64 (D);
         Fine := True;
         Multiply (S64 (C), S64 (B), T1, Fine);
         Add (T1, S64 (A), T2, Fine);
         Subtract (T2, 7, X, Fine);
         Multiply (E, S64 (B), T1, Fine);
         Add (T1, S64 (C), Y, Fine);
         if not Fine then
            Fail (L, Arithmetic_Error);
            exit;
         end if;
         Sum := Mix (Sum, X, Y);
      end loop;
      S := L;
   end Parse_Flagged;

   function Run_Flagged (Data : Bytes) return U64 is
      S   : Stream := Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Flagged (Data, S, Sum);
      return Sum;
   end Run_Flagged;

end Arith_Runs;
