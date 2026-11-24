package body Target_Data is

   procedure Fill is
      State : U32 := 16#1234_5678#;
   begin
      for B of Buffer loop
         State := State * 1_664_525 + 1_013_904_223;
         B := U8 (Shift_Right (State, 24));
      end loop;
   end Fill;

end Target_Data;
