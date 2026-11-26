with Ada.Unchecked_Conversion;
with Kaitai.Float_Arithmetic; use Kaitai.Float_Arithmetic;
with Kaitai.Floats;           use Kaitai.Floats;
with Kaitai.Streams;          use Kaitai.Streams;

package body Float_Runs is

   function Bits is new Ada.Unchecked_Conversion (F64, U64);

   procedure Prepare (Data : in out Bytes) is
      First : Length := Data'First;
   begin
      while Data'Last - First >= 14 loop
         declare
            X_Exponent : constant U16 := 1003 + (U16 (Data (First)) rem 40);
            Y_Exponent : constant U16 := 107 + (U16 (Data (First + 12)) rem 40);
         begin
            --  The 11 bits after the sign of an f8, and the 8 of an f4
            Data (First + 7) := (Data (First + 7) and 16#80#) or U8 (X_Exponent / 16);
            Data (First + 6) := (Data (First + 6) and 16#0F#) or U8 ((X_Exponent and 15) * 16);
            Data (First + 11) := (Data (First + 11) and 16#80#) or U8 (Y_Exponent / 2);
            Data (First + 10) := (Data (First + 10) and 16#7F#) or U8 ((Y_Exponent and 1) * 128);
         end;
         First := First + 15;
      end loop;
   end Prepare;

   type Record_Type is record
      X : U64;
      Y : U32;
      N : U16;
      K : U8;
   end record;

   procedure Parse (Data : Bytes; S : in out Stream; This : out Record_Type)
   with No_Inline;

   procedure Parse (Data : Bytes; S : in out Stream; This : out Record_Type) is
   begin
      Read_U8le (Data, S, This.X);
      Read_U4le (Data, S, This.Y);
      Read_U2le (Data, S, This.N);
      Read_U1 (Data, S, This.K);
   end Parse;

   function Mix (Sum : U64; Value : F64) return U64
   is (Sum * 31 + Bits (Value))
   with Inline_Always;

   function Mix (Sum : U64; Value : S64) return U64
   is (Sum * 31 + U64'Mod (Value))
   with Inline_Always;

   --  The to_i of x, as a person would write it without the library
   function Plain_To_I (Value : F64) return S64
   is (if Value >= 0.0 then S64 (F64'Floor (Value)) else S64 (F64'Ceiling (Value)))
   with Inline_Always;

   function Run_Nop (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         Sum := Mix (Sum, X);
      end loop;
      return Sum;
   end Run_Nop;

   function Run_Add_Plain (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         Sum := Mix (Sum, X + W);
      end loop;
      return Sum;
   end Run_Add_Plain;

   function Run_Add_Guarded (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         if Add_OK (X, W) then
            Sum := Mix (Sum, Add (X, W));
         else
            exit;
         end if;
      end loop;
      return Sum;
   end Run_Add_Guarded;

   function Run_Add_Lit_Plain (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         Sum := Mix (Sum, X + 0.05);
      end loop;
      return Sum;
   end Run_Add_Lit_Plain;

   function Run_Add_Lit_Guarded (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         if Add_OK (X, 0.05) then
            Sum := Mix (Sum, Add (X, 0.05));
         else
            exit;
         end if;
      end loop;
      return Sum;
   end Run_Add_Lit_Guarded;

   function Run_Sub_Plain (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         Sum := Mix (Sum, X - W);
      end loop;
      return Sum;
   end Run_Sub_Plain;

   function Run_Sub_Guarded (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         if Subtract_OK (X, W) then
            Sum := Mix (Sum, Subtract (X, W));
         else
            exit;
         end if;
      end loop;
      return Sum;
   end Run_Sub_Guarded;

   function Run_Mul_Plain (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         Sum := Mix (Sum, X * W);
      end loop;
      return Sum;
   end Run_Mul_Plain;

   function Run_Mul_Guarded (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         if Multiply_OK (X, W) then
            Sum := Mix (Sum, Multiply (X, W));
         else
            exit;
         end if;
      end loop;
      return Sum;
   end Run_Mul_Guarded;

   function Run_To_I_Plain (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         Sum := Mix (Sum, Plain_To_I (X));
      end loop;
      return Sum;
   end Run_To_I_Plain;

   function Run_To_I_Guarded (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         if Truncate_OK (X) then
            Sum := Mix (Sum, Truncate (X));
         else
            exit;
         end if;
      end loop;
      return Sum;
   end Run_To_I_Guarded;

   function Run_Expr_Plain (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         Sum := Mix (Sum, X + 0.05);
         Sum := Mix (Sum, X * W);
         Sum := Mix (Sum, W * W + 1.0);
         Sum := Mix (Sum, Plain_To_I (X));
      end loop;
      return Sum;
   end Run_Expr_Plain;

   function Run_Expr_Guarded (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         if Add_OK (X, 0.05)
           and then Multiply_OK (X, W)
           and then Multiply_OK (W, W)
           and then Add_OK (Multiply (W, W), 1.0)
           and then Truncate_OK (X)
         then
            Sum := Mix (Sum, Add (X, 0.05));
            Sum := Mix (Sum, Multiply (X, W));
            Sum := Mix (Sum, Add (Multiply (W, W), 1.0));
            Sum := Mix (Sum, Truncate (X));
         else
            exit;
         end if;
      end loop;
      return Sum;
   end Run_Expr_Guarded;

   function Run_Expr_Guarded_Where_Needed (Data : Bytes) return U64 is
      S    : Stream := Open (Data);
      This : Record_Type;
      Sum  : U64 := 0;
      X, W : F64;
   begin
      while not Is_EOF (S) loop
         Parse (Data, S, This);
         exit when not OK (S) or else not Is_Finite (This.X) or else not Is_Finite (This.Y);
         X := To_F64 (This.X);
         W := From_F32 (To_F32 (This.Y));
         Sum := Mix (Mix (Sum, X), W);
         --  W is an f4 converted, 3.4E38 at most, so that W * W + 1.0 cannot
         --  overflow and is not asked
         if Add_OK (X, 0.05) and then Multiply_OK (X, W) and then Truncate_OK (X) then
            Sum := Mix (Sum, Add (X, 0.05));
            Sum := Mix (Sum, Multiply (X, W));
            Sum := Mix (Sum, W * W + 1.0);
            Sum := Mix (Sum, Truncate (X));
         else
            exit;
         end if;
      end loop;
      return Sum;
   end Run_Expr_Guarded_Where_Needed;

end Float_Runs;
