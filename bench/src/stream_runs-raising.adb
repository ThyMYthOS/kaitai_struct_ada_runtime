package body Stream_Runs.Raising is

   procedure Parse_Cursor_Raise (Data : Bytes; S : in out Cursor_Raise.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Cursor_Raise (Data : Bytes; S : in out Cursor_Raise.Stream; Sum : in out U64) is
      use Cursor_Raise;
      A : U8;
      B : U16;
      C : U32;
      D : U64;
   begin
      loop
         Read_U1 (Data, S, A);
         Read_U2le (Data, S, B);
         Read_U4le (Data, S, C);
         Read_U8be (Data, S, D);
         Sum := Mix (Sum, A, B, C, D);
      end loop;
   exception
      --  Handled here: Sum is passed by copy and would be lost if the
      --  exception left this procedure
      when Cursor_Raise.End_Of_Stream =>
         null;
   end Parse_Cursor_Raise;

   function Run_Cursor_Raise (Data : Bytes) return U64 is
      S   : Cursor_Raise.Stream := Cursor_Raise.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Cursor_Raise (Data, S, Sum);
      return Sum;
   end Run_Cursor_Raise;

end Stream_Runs.Raising;
