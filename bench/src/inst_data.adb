package body Inst_Data is

   procedure Put_U32 (Buffer : in out Bytes; Pos : in out Length; Value : U32) is
   begin
      for J in 0 .. 3 loop
         Buffer (Pos + Length (J)) := U8 (Shift_Right (Value, 8 * J) and 16#FF#);
      end loop;
      Pos := Pos + 4;
   end Put_U32;

   procedure Put_U16 (Buffer : in out Bytes; Pos : in out Length; Value : U32) is
   begin
      Buffer (Pos) := U8 (Value and 16#FF#);
      Buffer (Pos + 1) := U8 (Shift_Right (Value, 8) and 16#FF#);
      Pos := Pos + 2;
   end Put_U16;

   --  The 6 entries, of which only the last is the limit, 7
   procedure Put_Entries (Buffer : in out Bytes; Pos : in out Length; R : Natural) is
   begin
      for J in 0 .. 4 loop
         Put_U16 (Buffer, Pos, U32 (100 + (R + J) mod 50));
      end loop;
      Put_U16 (Buffer, Pos, 7);
   end Put_Entries;

   procedure Put_Header (Buffer : in out Bytes; Pos : in out Length) is
   begin
      Put_U16 (Buffer, Pos, 3);
      Put_U16 (Buffer, Pos, 7);
      Buffer (Pos) := 75;
      Buffer (Pos + 1) := 83;
      Pos := Pos + 2;
   end Put_Header;

   procedure Generate (L : Inst_Runs.Layout; Records : Positive; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      for R in 1 .. Records loop
         case L is
            when Inst_Runs.Int_L   =>
               for J in 0 .. 7 loop
                  Put_U32 (Buffer, Pos, U32 (R * 16 + J));
                  Put_U32 (Buffer, Pos, U32 (J * 3 + 1));
               end loop;
               Put_U32 (Buffer, Pos, 8);

            when Inst_Runs.User_L  =>
               for J in 0 .. 2 loop
                  Buffer (Pos) := U8 ((R + J) mod 256);
                  Pos := Pos + 1;
               end loop;
               Put_Entries (Buffer, Pos, R);
               Put_Header (Buffer, Pos);

            when Inst_Runs.Until_L =>
               Put_Entries (Buffer, Pos, R);
               Put_Header (Buffer, Pos);
         end case;
      end loop;
      Used := Pos - 1;
   end Generate;

end Inst_Data;
