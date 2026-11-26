package body Acme.Scramble
  with SPARK_Mode
is

   procedure Decode
     (Source  : Kaitai.Types.Bytes;
      Key     : Kaitai.Types.S64;
      Strong  : Boolean;
      Mask    : Kaitai.Types.Bytes;
      Target  : in out Kaitai.Types.Bytes;
      Last    : out Kaitai.Types.Length;
      Outcome : out Kaitai.Types.Status_Kind)
   is
      use type Kaitai.Types.S64;
      use type Kaitai.Types.U8;

      --  The low byte of the key, or none
      Low : constant Kaitai.Types.U8 := (if Strong then Kaitai.Types.U8 (Key mod 256) else 0);

      --  Index of the byte of Mask for the current byte of Source
      K : Kaitai.Types.Index;
   begin
      if Mask'Length = 0 then
         Last := Target'First - 1;
         Outcome := Kaitai.Types.Arithmetic_Error;
      elsif Source'Length > Target'Length then
         Last := Target'First - 1;
         Outcome := Kaitai.Types.Capacity_Exceeded;
      else
         Last := Target'First - 1 + Kaitai.Types.Length (Source'Length);
         Outcome := Kaitai.Types.Success;
         K := Mask'First;
         for I in Target'First .. Last loop
            Target (I) := Source (Source'First + (I - Target'First)) xor Mask (K) xor Low;
            pragma Loop_Invariant (K in Mask'Range);
            K := (if K = Mask'Last then Mask'First else K + 1);
         end loop;
      end if;
   end Decode;

end Acme.Scramble;
