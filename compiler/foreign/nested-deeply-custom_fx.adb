with Custom_Fx_No_Args;

package body Nested.Deeply.Custom_Fx
  with SPARK_Mode
is

   procedure Decode
     (Source  : Kaitai.Types.Bytes;
      Key     : Kaitai.Types.S64;
      Target  : in out Kaitai.Types.Bytes;
      Last    : out Kaitai.Types.Length;
      Outcome : out Kaitai.Types.Status_Kind)
   is
      pragma Unreferenced (Key);
   begin
      Custom_Fx_No_Args.Decode (Source, Target, Last, Outcome);
   end Decode;

end Nested.Deeply.Custom_Fx;
