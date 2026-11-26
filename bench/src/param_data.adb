package body Param_Data is

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

   Initial_State : constant U32 := 16#1B87_3593#;

   procedure Fill (F : Format; Records : Positive; N : Positive; Buffer : out Bytes; Used : out Length) is
      State : U32 := Initial_State;
      Value : U32;
      Pos   : Length := 1;

      procedure Put (Item : U8) is
      begin
         Buffer (Pos) := Item;
         Pos := Pos + 1;
      end Put;

      --  A random letter from "a" to "d"
      procedure Put_Letter is
      begin
         Next (State, Value);
         Put (16#61# + U8 (Shift_Right (Value, 20) mod 4));
      end Put_Letter;
   begin
      for R in 1 .. Records loop
         case F is
            when Pstr  =>
               declare
                  Key  : U32;
                  Same : Boolean;
               begin
                  Next (State, Key);
                  for J in 0 .. 3 loop
                     Put (16#61# + U8 (Shift_Right (Key, 4 * J) mod 4));
                  end loop;
                  Put (U8 (N));
                  for I in 1 .. N loop
                     Next (State, Value);
                     Same := (Value and 1) = 0;
                     if Same then
                        for J in 0 .. 3 loop
                           Put (16#61# + U8 (Shift_Right (Key, 4 * J) mod 4));
                        end loop;
                     else
                        for J in 0 .. 3 loop
                           Put_Letter;
                        end loop;
                     end if;
                  end loop;
               end;

            when Puser =>
               declare
                  Width  : U16;
                  Height : U16;
               begin
                  Next (State, Value);
                  Width := 8 + U16 (Shift_Right (Value, 8) mod 16);
                  Height := U16 (Shift_Right (Value, 16) mod 4);
                  Put (U8 (Width and 16#FF#));
                  Put (U8 (Shift_Right (Width, 8)));
                  Put (U8 (Height and 16#FF#));
                  Put (U8 (Shift_Right (Height, 8)));
                  Put (U8 (N));
                  for I in 1 .. N loop
                     Next (State, Value);
                     Put (U8 (Value mod 16));
                     Put (U8 (Shift_Right (Value, 4) mod 16));
                     for J in 1 .. Height loop
                        Put (U8 (Shift_Right (Value, 8 + Natural (J) * 2) mod 256));
                     end loop;
                  end loop;
               end;

            when Pnav  =>
               declare
                  Foo : Boolean;
               begin
                  Next (State, Value);
                  Foo := (Value and 1) = 0;
                  if Foo then
                     Put (16#66#);
                     Put (16#6F#);
                     Put (16#6F#);
                  else
                     Put (16#62#);
                     Put (16#61#);
                     Put (16#72#);
                  end if;
                  Put (16#7C#);
                  Put (U8 (N));
                  for I in 1 .. N loop
                     Next (State, Value);
                     Put (U8 (Shift_Right (Value, 8) mod 256));
                     if Foo then
                        Put (U8 (Shift_Right (Value, 16) mod 256));
                     end if;
                  end loop;
               end;
         end case;
      end loop;
      Used := Pos - 1;
   end Fill;

end Param_Data;
