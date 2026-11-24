--  Floating point numbers.
--
--  The stream delivers f4 and f8 as the 32 or 64 bits they are stored in,
--  read with the operations for u4 and u8.  The functions here turn those
--  bits into a value of a floating point type.  That is only possible for
--  finite numbers: Ada has no values for infinity and not-a-number, and
--  SPARK requires that none arises.  A parser therefore asks Is_Finite
--  first and treats anything else as it sees fit.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Floats
  with Pure, SPARK_Mode
is

   subtype F32 is Float;
   subtype F64 is Long_Float;

   pragma Compile_Time_Error (F32'Size /= 32 or else F32'Machine_Mantissa /= 24, "Float is not IEEE 754 binary32");
   pragma Compile_Time_Error (F64'Size /= 64 or else F64'Machine_Mantissa /= 53, "Long_Float is not IEEE 754 binary64");

   --  True unless the exponent bits are all ones, which encodes infinity
   --  and not-a-number
   function Is_Finite (Raw : U32) return Boolean
   is ((Raw and 16#7F80_0000#) /= 16#7F80_0000#);

   function Is_Finite (Raw : U64) return Boolean
   is ((Raw and 16#7FF0_0000_0000_0000#) /= 16#7FF0_0000_0000_0000#);

   function To_F32 (Raw : U32) return F32
   with Inline, Pre => Is_Finite (Raw);

   function To_F64 (Raw : U64) return F64
   with Inline, Pre => Is_Finite (Raw);

end Kaitai.Floats;
