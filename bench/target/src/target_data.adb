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
      Bench_Data.Fill_Term (Records, Work_Buffer (1 .. Records * Bench_Data.Term_Record_Max), Used);
   end Fill_Term;

   procedure Fill_Contents (Used : out Length) is
   begin
      Bench_Data.Fill_Contents (Records, Work_Buffer (1 .. Records * Bench_Data.Contents_Record_Size), Used);
   end Fill_Contents;

   procedure Fill_Substream (Used : out Length) is
   begin
      Bench_Data.Fill_Substream (Records, Work_Buffer (1 .. Records * Bench_Data.Substream_Record_Max), Used);
   end Fill_Substream;

   procedure Fill_Nested (Used : out Length) is
   begin
      Bench_Data.Fill_Nested (Records, Work_Buffer (1 .. Records * Bench_Data.Nested_Record_Size), Used);
   end Fill_Nested;

   procedure Fill_Fields (Used : out Length) is
   begin
      Bench_Data.Fill_Fields (Records, Work_Buffer (1 .. Records * Bench_Data.Fields_Record_Max), Used);
   end Fill_Fields;

   procedure Fill_Process (Used : out Length) is
   begin
      Bench_Data.Fill_Process (Records, Work_Buffer (1 .. Records * Bench_Data.Process_Record_Size), Used);
   end Fill_Process;

end Target_Data;
