package body Bit_Variants is

   procedure Align (S : in out Stream) is
   begin
      S.Bits := 0;
      S.Bits_Left := 0;
   end Align;

   procedure Read_Bits_Be (Data : Bytes; S : in out Stream; Count : Positive; Value : out U64) is
      Needed : constant Integer := Count - S.Bits_Left;
      Left   : constant Natural := (-Needed) mod 8;
   begin
      Value := 0;
      if S.Failed then
         return;
      end if;

      if Needed > 0 then
         declare
            Whole : constant Length := Length ((Needed - 1) / 8 + 1);
            Fresh : U64 := 0;
         begin
            if Whole - 1 > S.Last - S.Pos then
               S.Failed := True;
               return;
            end if;
            for I in 0 .. Whole - 1 loop
               Fresh := Shift_Left (Fresh, 8) or U64 (Data (S.Pos + I));
            end loop;
            S.Pos := S.Pos + Whole;
            Value := Shift_Right (Fresh, Left) or (if Needed < 64 then Shift_Left (S.Bits, Needed) else 0);
            S.Bits := Fresh;
         end;
      else
         Value := Shift_Right (S.Bits, -Needed);
      end if;

      S.Bits_Left := Left;
      S.Bits := S.Bits and (Shift_Left (1, Left) - 1);
   end Read_Bits_Be;

   procedure Read_Bits_Le (Data : Bytes; S : in out Stream; Count : Positive; Value : out U64) is
      Needed : constant Integer := Count - S.Bits_Left;
   begin
      Value := 0;
      if S.Failed then
         return;
      end if;

      if Needed > 0 then
         declare
            Whole : constant Length := Length ((Needed - 1) / 8 + 1);
            Fresh : U64 := 0;
         begin
            if Whole - 1 > S.Last - S.Pos then
               S.Failed := True;
               return;
            end if;
            for I in 0 .. Whole - 1 loop
               Fresh := Fresh or Shift_Left (U64 (Data (S.Pos + I)), Natural (I) * 8);
            end loop;
            S.Pos := S.Pos + Whole;
            Value := Shift_Left (Fresh, S.Bits_Left) or S.Bits;
            S.Bits := (if Needed < 64 then Shift_Right (Fresh, Needed) else 0);
         end;
      else
         Value := S.Bits;
         S.Bits := Shift_Right (S.Bits, Count);
      end if;

      S.Bits_Left := (-Needed) mod 8;
      if Count < 64 then
         Value := Value and (Shift_Left (1, Count) - 1);
      end if;
   end Read_Bits_Le;

end Bit_Variants;
