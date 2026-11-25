--  Derived by hand from generated/bench_bits_flat.adb: the package is renamed and
--  the call of Kaitai.Streams.Align_To_Byte that begins Parse is replaced by a test of Bits_Left (S) = 0 with the
--  reads in both branches.  Nothing else is changed.

package body Bench_Bits_Flat_V3
  with SPARK_Mode
is

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
   begin
      if Kaitai.Streams.Bits_Left (S) = 0 then
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 3, This.A);
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 5, This.B);
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 12, This.C);
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 12, This.D);
      else
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 3, This.A);
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 5, This.B);
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 12, This.C);
         Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 12, This.D);
      end if;
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse;

end Bench_Bits_Flat_V3;
