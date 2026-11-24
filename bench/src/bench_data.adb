package body Bench_Data is

   --  Deterministic pseudo random numbers (xorshift32)
   procedure Next (State : in out U32; Value : out U32) is
      X : U32 := State;
   begin
      X := X xor Shift_Left (X, 13);
      X := X xor Shift_Right (X, 17);
      X := X xor Shift_Left (X, 5);
      State := X;
      Value := X;
   end Next;

   Initial_State : constant U32 := 16#2545_F491#;

   procedure Fill_Term (Records : Positive; Buffer : out Bytes; Used : out Length) is
      State : U32 := Initial_State;
      Sizes : U32;
      Seed  : U32;
      Pos   : Length := 1;

      --  A string of Count bytes that are not zero, and its terminator
      procedure Put_String (Count : Length; From : U32) is
      begin
         for J in 1 .. Count loop
            Buffer (Pos) := U8 (1 + (From + U32 (J)) mod 255);
            Pos := Pos + 1;
         end loop;
         Buffer (Pos) := 0;
         Pos := Pos + 1;
      end Put_String;
   begin
      for I in 1 .. Records loop
         Next (State, Sizes);
         Next (State, Seed);
         Put_String (Length (Sizes mod 13), Seed);
         Put_String (Length (Shift_Right (Sizes, 8) mod 13), Shift_Right (Seed, 3));
         Buffer (Pos) := U8 (Shift_Right (Sizes, 16) and 16#FF#);
         Buffer (Pos + 1) := U8 (Shift_Right (Sizes, 24));
         Pos := Pos + 2;
      end loop;
      Used := Pos - 1;
   end Fill_Term;

   procedure Fill_Contents (Records : Positive; Buffer : out Bytes; Used : out Length) is
      State : U32 := Initial_State;
      Value : U32;
      Pos   : Length := 1;
   begin
      for I in 1 .. Records loop
         Next (State, Value);
         for K in Length range 0 .. 3 loop
            Buffer (Pos + K) := Magic (Magic'First + K);
         end loop;
         Buffer (Pos + 4) := U8 (Value and 16#FF#);
         Buffer (Pos + 5) := U8 (Shift_Right (Value, 8) and 16#FF#);
         Buffer (Pos + 6) := U8 (Shift_Right (Value, 16) and 16#FF#);
         Buffer (Pos + 7) := U8 (Shift_Right (Value, 24));
         Pos := Pos + Contents_Record_Size;
      end loop;
      Used := Pos - 1;
   end Fill_Contents;

   procedure Fill_Substream (Records : Positive; Buffer : out Bytes; Used : out Length) is
      State : U32 := Initial_State;
      Value : U32;
      Seed  : U32;
      Size  : Length;
      Pos   : Length := 1;
   begin
      for I in 1 .. Records loop
         Next (State, Value);
         Next (State, Seed);
         Size := 4 + Length (Value mod 13);
         Buffer (Pos) := U8 (Size);
         for J in 1 .. Size loop
            Buffer (Pos + J) := U8 ((Shift_Right (Seed, 4) + U32 (J) * 37) and 16#FF#);
         end loop;
         Pos := Pos + 1 + Size;
      end loop;
      Used := Pos - 1;
   end Fill_Substream;

   procedure Fill_Nested (Records : Positive; Buffer : out Bytes; Used : out Length) is
      State : U32 := Initial_State;
      Value : U32;
      Pos   : Length := 1;
   begin
      for I in 1 .. Records loop
         Next (State, Value);
         Buffer (Pos) := U8 (Value and 16#FF#);
         Buffer (Pos + 1) := U8 (Shift_Right (Value, 8) and 16#FF#);
         Buffer (Pos + 2) := U8 (Shift_Right (Value, 16) and 16#FF#);
         Buffer (Pos + 3) := U8 (Shift_Right (Value, 24));
         Pos := Pos + Nested_Record_Size;
      end loop;
      Used := Pos - 1;
   end Fill_Nested;

end Bench_Data;
