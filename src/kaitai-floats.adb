with Ada.Unchecked_Conversion;

package body Kaitai.Floats
  with SPARK_Mode
is

   --  The bits of an infinity or a not-a-number are not a value of the
   --  floating point type.  Potentially_Invalid says so, and makes
   --  GNATprove require a validity check before the result is used.

   function Convert is new Ada.Unchecked_Conversion (U32, F32)with Potentially_Invalid;

   function Convert is new Ada.Unchecked_Conversion (U64, F64)with Potentially_Invalid;

   function To_F32 (Raw : U32) return F32 is
      Result : constant F32 := Convert (Raw)
      with Potentially_Invalid;
   begin
      return (if Result'Valid then Result else 0.0);
   end To_F32;

   function To_F64 (Raw : U64) return F64 is
      Result : constant F64 := Convert (Raw)
      with Potentially_Invalid;
   begin
      return (if Result'Valid then Result else 0.0);
   end To_F64;

end Kaitai.Floats;
