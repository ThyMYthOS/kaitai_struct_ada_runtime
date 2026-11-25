--  Derived by hand from generated/bench_bits_nested.adb: the package is renamed and
--  the call of Kaitai.Streams.Align_To_Byte that begins Parse is replaced by a test of Bits_Left (S) = 0 with the
--  reads in both branches.  Nothing else is changed.

package body Bench_Bits_Nested_V3
  with SPARK_Mode
is

   package body Inner_Type is

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      begin
         if Kaitai.Streams.Bits_Left (S) = 0 then
            Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 4, This.X);
            Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 4, This.Y);
            Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 8, This.Z);
         else
            Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 4, This.X);
            Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 4, This.Y);
            Kaitai.Streams.Read_Bits_Int_Be (Buffer, S, 8, This.Z);
         end if;
         This.Is_Valid := Kaitai.Streams.OK (S);
      end Parse;

   end Inner_Type;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
   begin
      Kaitai.Streams.Read_U1 (Buffer, S, This.A);
      Inner_Type.Parse (Buffer, S, This.B);
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse;

end Bench_Bits_Nested_V3;
