package body Unwrap
  with SPARK_Mode
is

   procedure Decode
     (Source  : Kaitai.Types.Bytes;
      Target  : in out Kaitai.Types.Bytes;
      Last    : out Kaitai.Types.Length;
      Outcome : out Kaitai.Types.Status_Kind) is
   begin
      if Source'Length < 2 then
         Last := Target'First - 1;
         Outcome := Kaitai.Types.Illegal_Sequence;
      elsif Source'Length - 2 > Target'Length then
         Last := Target'First - 1;
         Outcome := Kaitai.Types.Capacity_Exceeded;
      else
         Last := Target'First - 1 + Kaitai.Types.Length (Source'Length - 2);
         Outcome := Kaitai.Types.Success;
         for I in Target'First .. Last loop
            Target (I) := Source (Source'First + 1 + (I - Target'First));
         end loop;
      end if;
   end Decode;

end Unwrap;
