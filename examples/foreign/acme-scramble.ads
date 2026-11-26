with Kaitai.Types;

package Acme.Scramble
  with SPARK_Mode, Always_Terminates
is
   --  The custom process `acme.scramble(key, strong, mask)` of `foreign.ksy`. This
   --  package is written by hand and keeps the contract that "Foreign code" in
   --  docs/codegen.md gives for a custom process; the parser of `foreign` is
   --  proven against this specification.

   use type Kaitai.Types.Length;
   use type Kaitai.Types.Status_Kind;

   --  Every byte of Source combined by exclusive or with a byte of Mask, which
   --  is used from its start again whenever its end is reached, and with the
   --  low byte of Key if Strong is true. The result has as many bytes as Source.
   --  A Mask without bytes is not accepted: Outcome is Arithmetic_Error then.
   --  @param Source The bytes to decode
   --  @param Key The key, any integer; only its low 8 bits are used
   --  @param Strong Whether the key is used at all
   --  @param Mask The bytes to combine with, at least one
   --  @param Target Where the result goes, from Target'First, which must be at least 1
   --  @param Last The index in Target of the last byte of the result, Target'First - 1 if Outcome is not Success
   --  @param Outcome Success, Capacity_Exceeded if Target is too small, Arithmetic_Error if Mask has no bytes
   procedure Decode
     (Source  : Kaitai.Types.Bytes;
      Key     : Kaitai.Types.S64;
      Strong  : Boolean;
      Mask    : Kaitai.Types.Bytes;
      Target  : in out Kaitai.Types.Bytes;
      Last    : out Kaitai.Types.Length;
      Outcome : out Kaitai.Types.Status_Kind)
   with
     Global => null,
     Pre    => Target'First >= 1,
     Post   =>
       Last >= Target'First - 1
       and then Last - (Target'First - 1) <= Kaitai.Types.Length (Target'Length)
       and then (if Outcome /= Kaitai.Types.Success then Last = Target'First - 1)
       and then (if Outcome = Kaitai.Types.Success then Last - (Target'First - 1) = Source'Length)
       and then (if Mask'Length = 0 then Outcome = Kaitai.Types.Arithmetic_Error)
       and then (if Mask'Length > 0 and then Source'Length > Target'Length
                 then Outcome = Kaitai.Types.Capacity_Exceeded);

end Acme.Scramble;
