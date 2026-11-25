--  Derived by hand from generated/bench_bits_le.adb: the package is renamed and
--  the call of Kaitai.Streams.Align_To_Byte that begins Parse is removed.  Nothing else is changed.

package body Bench_Bits_Le_V2
  with SPARK_Mode
is

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
   begin
      Kaitai.Streams.Read_Bits_Int_Le (Buffer, S, 3, This.A);
      Kaitai.Streams.Read_Bits_Int_Le (Buffer, S, 5, This.B);
      Kaitai.Streams.Read_Bits_Int_Le (Buffer, S, 12, This.C);
      Kaitai.Streams.Read_Bits_Int_Le (Buffer, S, 12, This.D);
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse;

end Bench_Bits_Le_V2;
