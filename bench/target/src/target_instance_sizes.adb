with Ada.Text_IO;
with Bench_Inst_Int_D1;
with Bench_Inst_Int_D2;
with Bench_Inst_Until_D1;
with Bench_Inst_Until_D2;
with Bench_Inst_User_D1;
with Bench_Inst_User_D2;

--  Prints the size in bits of the value of each variant of instance_bench, which the host program prints as well

procedure Target_Instance_Sizes is
   procedure Put (Name : String; Bits : Natural) is
   begin
      Ada.Text_IO.Put_Line ("SIZE " & Name & Natural'Image (Bits));
   end Put;
begin
   Put ("int_d1", Bench_Inst_Int_D1.T'Object_Size);
   Put ("int_d2", Bench_Inst_Int_D2.T'Object_Size);
   Put ("user_d1", Bench_Inst_User_D1.T'Object_Size);
   Put ("user_d2", Bench_Inst_User_D2.T'Object_Size);
   Put ("until_d1", Bench_Inst_Until_D1.T'Object_Size);
   Put ("until_d2", Bench_Inst_Until_D2.T'Object_Size);
   Ada.Text_IO.Put_Line ("DONE");
   loop
      null;
   end loop;
end Target_Instance_Sizes;
