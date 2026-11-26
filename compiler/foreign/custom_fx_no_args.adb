package body Custom_Fx_No_Args
  with SPARK_Mode
is

   procedure Decode
     (Source  : Kaitai.Types.Bytes;
      Target  : in out Kaitai.Types.Bytes;
      Last    : out Kaitai.Types.Length;
      Outcome : out Kaitai.Types.Status_Kind)
   is
   begin
      if Target'Length < 2 or else Source'Length > Target'Length - 2 then
         Last := Target'First - 1;
         Outcome := Kaitai.Types.Capacity_Exceeded;
      else
         Last := Target'First + 1 + Kaitai.Types.Length (Source'Length);
         Outcome := Kaitai.Types.Success;
         Target (Target'First) := 16#5F#;
         for I in 1 .. Kaitai.Types.Length (Source'Length) loop
            Target (Target'First + I) := Source (Source'First + (I - 1));
         end loop;
         Target (Last) := 16#5F#;
      end if;
   end Decode;

end Custom_Fx_No_Args;
