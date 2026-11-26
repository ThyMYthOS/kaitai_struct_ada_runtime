package body My_Custom_Fx
  with SPARK_Mode
is

   procedure Decode
     (Source     : Kaitai.Types.Bytes;
      Key        : Kaitai.Types.S64;
      Flag       : Boolean;
      Some_Bytes : Kaitai.Types.Bytes;
      Target     : in out Kaitai.Types.Bytes;
      Last       : out Kaitai.Types.Length;
      Outcome    : out Kaitai.Types.Status_Kind)
   is
      pragma Unreferenced (Some_Bytes);
      use type Kaitai.Types.S64;
      use type Kaitai.Types.U8;

      --  What is added to every byte, from 0 to 255
      Offset : constant Kaitai.Types.U8 :=
        (if Flag then Kaitai.Types.U8 (Key mod 256) else Kaitai.Types.U8 ((256 - Key mod 256) mod 256));
   begin
      if Source'Length > Target'Length then
         Last := Target'First - 1;
         Outcome := Kaitai.Types.Capacity_Exceeded;
      else
         Last := Target'First - 1 + Kaitai.Types.Length (Source'Length);
         Outcome := Kaitai.Types.Success;
         for I in Target'First .. Last loop
            Target (I) := Source (Source'First + (I - Target'First)) + Offset;
         end loop;
      end if;
   end Decode;

end My_Custom_Fx;
