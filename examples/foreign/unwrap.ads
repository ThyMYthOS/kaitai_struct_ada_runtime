with Kaitai.Types;

package Unwrap
  with SPARK_Mode, Always_Terminates
is
   --  The custom process `unwrap` of `foreign.ksy`, which has no arguments. This
   --  package is written by hand and keeps the contract that "Foreign code" in
   --  docs/codegen.md gives for a custom process; the parser of `foreign` is
   --  proven against this specification.

   use type Kaitai.Types.Length;
   use type Kaitai.Types.Status_Kind;

   --  Source without its first and its last byte, written to Target. A Source
   --  of less than two bytes is not accepted: Outcome is Illegal_Sequence then.
   --  @param Source The bytes to decode
   --  @param Target Where the result goes, from Target'First, which must be at least 1
   --  @param Last The index in Target of the last byte of the result, Target'First - 1 if Outcome is not Success
   --  @param Outcome Success, Capacity_Exceeded if Target is too small, Illegal_Sequence if Source has less than two
   --  bytes
   procedure Decode
     (Source  : Kaitai.Types.Bytes;
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
       and then (if Outcome = Kaitai.Types.Success
                 then Source'Length >= 2 and then Last - (Target'First - 1) = Source'Length - 2)
       and then (if Source'Length < 2 then Outcome = Kaitai.Types.Illegal_Sequence);

end Unwrap;
