package body Target_Data is

   procedure Fill is
      State : U32 := 16#1234_5678#;
   begin
      for B of Buffer loop
         State := State * 1_664_525 + 1_013_904_223;
         B := U8 (Shift_Right (State, 24));
      end loop;
   end Fill;

   procedure Fill_Term (Used : out Length) is
   begin
      Bench_Data.Fill_Term (Records, Term_Buffer, Used);
   end Fill_Term;

   procedure Fill_Contents (Used : out Length) is
   begin
      Bench_Data.Fill_Contents (Records, Contents_Buffer, Used);
   end Fill_Contents;

   procedure Fill_Substream (Used : out Length) is
   begin
      Bench_Data.Fill_Substream (Records, Substream_Buffer, Used);
   end Fill_Substream;

   procedure Fill_Nested (Used : out Length) is
   begin
      Bench_Data.Fill_Nested (Records, Nested_Buffer, Used);
   end Fill_Nested;

end Target_Data;
