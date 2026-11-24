package body Stream_Variants is

   package body Decoding is

      function U16_LE (Data : Bytes; From : Length) return U16
      is (U16 (Data (From)) or Shift_Left (U16 (Data (From + 1)), 8));

      function U32_LE (Data : Bytes; From : Length) return U32
      is (U32 (Data (From))
          or Shift_Left (U32 (Data (From + 1)), 8)
          or Shift_Left (U32 (Data (From + 2)), 16)
          or Shift_Left (U32 (Data (From + 3)), 24));

      function U64_BE (Data : Bytes; From : Length) return U64
      is (Shift_Left (U64 (Data (From)), 56)
          or Shift_Left (U64 (Data (From + 1)), 48)
          or Shift_Left (U64 (Data (From + 2)), 40)
          or Shift_Left (U64 (Data (From + 3)), 32)
          or Shift_Left (U64 (Data (From + 4)), 24)
          or Shift_Left (U64 (Data (From + 5)), 16)
          or Shift_Left (U64 (Data (From + 6)), 8)
          or U64 (Data (From + 7)));

   end Decoding;

   use Decoding;

   package body Cursor_Sticky is

      procedure Read_U1 (Data : Bytes; S : in out Stream; V : out U8) is
      begin
         if S.Failed or else S.Pos > S.Last then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := Data (S.Pos);
         S.Pos := S.Pos + 1;
      end Read_U1;

      procedure Read_U2le (Data : Bytes; S : in out Stream; V : out U16) is
      begin
         if S.Failed or else S.Last - S.Pos < 1 then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := U16_LE (Data, S.Pos);
         S.Pos := S.Pos + 2;
      end Read_U2le;

      procedure Read_U4le (Data : Bytes; S : in out Stream; V : out U32) is
      begin
         if S.Failed or else S.Last - S.Pos < 3 then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := U32_LE (Data, S.Pos);
         S.Pos := S.Pos + 4;
      end Read_U4le;

      procedure Read_U8be (Data : Bytes; S : in out Stream; V : out U64) is
      begin
         if S.Failed or else S.Last - S.Pos < 7 then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := U64_BE (Data, S.Pos);
         S.Pos := S.Pos + 8;
      end Read_U8be;

   end Cursor_Sticky;

   package body Pointer_Sticky is

      procedure Read_U1 (S : in out Stream; V : out U8) is
      begin
         if S.Failed or else S.Pos > S.Last then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := S.Data (S.Pos);
         S.Pos := S.Pos + 1;
      end Read_U1;

      procedure Read_U2le (S : in out Stream; V : out U16) is
      begin
         if S.Failed or else S.Last - S.Pos < 1 then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := U16_LE (S.Data.all, S.Pos);
         S.Pos := S.Pos + 2;
      end Read_U2le;

      procedure Read_U4le (S : in out Stream; V : out U32) is
      begin
         if S.Failed or else S.Last - S.Pos < 3 then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := U32_LE (S.Data.all, S.Pos);
         S.Pos := S.Pos + 4;
      end Read_U4le;

      procedure Read_U8be (S : in out Stream; V : out U64) is
      begin
         if S.Failed or else S.Last - S.Pos < 7 then
            S.Failed := True;
            V := 0;
            return;
         end if;
         V := U64_BE (S.Data.all, S.Pos);
         S.Pos := S.Pos + 8;
      end Read_U8be;

   end Pointer_Sticky;

   package body Cursor_Status is

      procedure Read_U1 (Data : Bytes; S : in out Stream; V : out U8; OK : out Boolean) is
      begin
         if S.Pos > S.Last then
            OK := False;
            V := 0;
            return;
         end if;
         V := Data (S.Pos);
         S.Pos := S.Pos + 1;
         OK := True;
      end Read_U1;

      procedure Read_U2le (Data : Bytes; S : in out Stream; V : out U16; OK : out Boolean) is
      begin
         if S.Last - S.Pos < 1 then
            OK := False;
            V := 0;
            return;
         end if;
         V := U16_LE (Data, S.Pos);
         S.Pos := S.Pos + 2;
         OK := True;
      end Read_U2le;

      procedure Read_U4le (Data : Bytes; S : in out Stream; V : out U32; OK : out Boolean) is
      begin
         if S.Last - S.Pos < 3 then
            OK := False;
            V := 0;
            return;
         end if;
         V := U32_LE (Data, S.Pos);
         S.Pos := S.Pos + 4;
         OK := True;
      end Read_U4le;

      procedure Read_U8be (Data : Bytes; S : in out Stream; V : out U64; OK : out Boolean) is
      begin
         if S.Last - S.Pos < 7 then
            OK := False;
            V := 0;
            return;
         end if;
         V := U64_BE (Data, S.Pos);
         S.Pos := S.Pos + 8;
         OK := True;
      end Read_U8be;

   end Cursor_Status;

   package body Cursor_Raise is

      procedure Read_U1 (Data : Bytes; S : in out Stream; V : out U8) is
      begin
         if S.Pos > S.Last then
            raise End_Of_Stream;
         end if;
         V := Data (S.Pos);
         S.Pos := S.Pos + 1;
      end Read_U1;

      procedure Read_U2le (Data : Bytes; S : in out Stream; V : out U16) is
      begin
         if S.Last - S.Pos < 1 then
            raise End_Of_Stream;
         end if;
         V := U16_LE (Data, S.Pos);
         S.Pos := S.Pos + 2;
      end Read_U2le;

      procedure Read_U4le (Data : Bytes; S : in out Stream; V : out U32) is
      begin
         if S.Last - S.Pos < 3 then
            raise End_Of_Stream;
         end if;
         V := U32_LE (Data, S.Pos);
         S.Pos := S.Pos + 4;
      end Read_U4le;

      procedure Read_U8be (Data : Bytes; S : in out Stream; V : out U64) is
      begin
         if S.Last - S.Pos < 7 then
            raise End_Of_Stream;
         end if;
         V := U64_BE (Data, S.Pos);
         S.Pos := S.Pos + 8;
      end Read_U8be;

   end Cursor_Raise;

end Stream_Variants;
