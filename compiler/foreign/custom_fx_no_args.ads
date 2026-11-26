--  The custom process `custom_fx_no_args` of the Kaitai Struct tests
--  (formats/process_custom_no_args.ksy): the bytes between two underscores.
--  The contract is "Foreign code" in docs/codegen.md.

with Kaitai.Types;

package Custom_Fx_No_Args
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.Length;
   use type Kaitai.Types.Status_Kind;

   --  An underscore, Source, and an underscore, written to Target.  The
   --  result has two bytes more than Source.
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
       and then (if Outcome = Kaitai.Types.Success then Last - (Target'First - 1) = Source'Length + 2);

end Custom_Fx_No_Args;
