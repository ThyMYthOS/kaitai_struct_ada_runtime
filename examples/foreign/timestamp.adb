package body Timestamp
  with SPARK_Mode
is

   procedure Parse
     (This : out T; Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Rate : Kaitai.Types.S64)
   is
      Seconds : Kaitai.Types.U32;
   begin
      Kaitai.Streams.Read_U4be (Buffer, S, Seconds);
      if Rate < 1 then
         Kaitai.Streams.Fail (S, Kaitai.Types.Arithmetic_Error);
      end if;
      This := (Is_Valid => Kaitai.Streams.OK (S), Seconds => Seconds, Rate => Rate);
   end Parse;

end Timestamp;
