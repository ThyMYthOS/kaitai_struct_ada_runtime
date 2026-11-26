--  The custom process `my_custom_fx(key, flag, some_bytes)` of the Kaitai Struct
--  tests (formats/process_custom.ksy, formats/process_term_struct.ksy): every
--  byte plus the key, or minus the key if the flag is false, modulo 256.
--  The other targets have this class under spec/ in the tests repository.
--  The contract is "Foreign code" in docs/codegen.md.

with Kaitai.Types;

package My_Custom_Fx
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.Length;
   use type Kaitai.Types.Status_Kind;

   --  Source with Key added to every byte if Flag is true, subtracted from
   --  every byte if it is false, modulo 256, written to Target.  Some_Bytes
   --  is not used.  The result has as many bytes as Source.
   procedure Decode
     (Source     : Kaitai.Types.Bytes;
      Key        : Kaitai.Types.S64;
      Flag       : Boolean;
      Some_Bytes : Kaitai.Types.Bytes;
      Target     : in out Kaitai.Types.Bytes;
      Last       : out Kaitai.Types.Length;
      Outcome    : out Kaitai.Types.Status_Kind)
   with
     Global => null,
     Pre    => Target'First >= 1,
     Post   =>
       Last >= Target'First - 1
       and then Last - (Target'First - 1) <= Kaitai.Types.Length (Target'Length)
       and then (if Outcome /= Kaitai.Types.Success then Last = Target'First - 1)
       and then (if Outcome = Kaitai.Types.Success then Last - (Target'First - 1) = Source'Length)
       and then (if Source'Length > Target'Length then Outcome = Kaitai.Types.Capacity_Exceeded);

end My_Custom_Fx;
