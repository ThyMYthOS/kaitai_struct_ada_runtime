package body Bits_Simple
  with SPARK_Mode
is

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
      L   : Stream := S;
      Bit : U64;
   begin
      --  The fields of a type start at a byte boundary
      Align_To_Byte (L);
      Read_Bits_Int_Be (Buffer, L, 8, This.Byte_1);
      Read_Bits_Int_Be (Buffer, L, 8, This.Byte_2);
      Read_Bits_Int_Be (Buffer, L, 1, Bit);
      This.Bits_A := Bit /= 0;
      Read_Bits_Int_Be (Buffer, L, 3, This.Bits_B);
      Read_Bits_Int_Be (Buffer, L, 4, This.Bits_C);
      Read_Bits_Int_Be (Buffer, L, 10, This.Large_Bits_1);
      Read_Bits_Int_Be (Buffer, L, 3, This.Spacer);
      Read_Bits_Int_Be (Buffer, L, 11, This.Large_Bits_2);
      Read_S2be (Buffer, L, This.Normal_S2);
      Read_Bits_Int_Be (Buffer, L, 24, This.Byte_8_9_10);
      Read_Bits_Int_Be (Buffer, L, 32, This.Byte_11_To_14);
      Read_Bits_Int_Be (Buffer, L, 40, This.Byte_15_To_19);
      Read_Bits_Int_Be (Buffer, L, 64, This.Byte_20_To_27);

      This.Is_Valid := OK (L);
      S := L;
   end Parse;

end Bits_Simple;
