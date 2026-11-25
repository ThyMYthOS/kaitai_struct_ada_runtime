--  Derived by hand from generated/bench_bits_mixed.adb: the package is renamed and
--  the call of Kaitai.Streams.Align_To_Byte that begins Parse is removed.  Nothing else is changed.

package body Bench_Bits_Mixed_V2
  with SPARK_Mode
is

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
   begin
      Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 4, This.A);
      Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 4, This.B);
      Kaitai.Streams.Read_U1 (Buffer, S, This.C);
      Kaitai.Streams.Read_U2le (Buffer, S, This.D);
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse;

end Bench_Bits_Mixed_V2;
