package body Term_Strz
  with SPARK_Mode
is

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
      L : Stream := S;
   begin
      Read_Bytes_Term
        (Buffer, L, Term => 16#7C#, Include => False, Consume => True, EOS_Error => True, Data => This.S1);
      Read_Bytes_Term
        (Buffer, L, Term => 16#7C#, Include => False, Consume => False, EOS_Error => True, Data => This.S2);
      Read_Bytes_Term (Buffer, L, Term => 16#40#, Include => True, Consume => True, EOS_Error => True, Data => This.S3);
      This.Is_Valid := OK (L);
      S := L;
   end Parse;

end Term_Strz;
