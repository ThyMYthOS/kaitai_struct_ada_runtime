--  Root of the Kaitai Struct runtime library for Ada and SPARK.
--
--  The library is what code generated from .ksy descriptions is built on.
--  Its core is written in SPARK, uses neither heap nor exceptions nor the
--  secondary stack, and all its run-time checks are proven absent.

package Kaitai
  with Pure, SPARK_Mode
is

   --  Version of the Kaitai Struct runtime API this library implements, in
   --  the encoding the other runtime libraries use: for version x.y.z the
   --  decimal number xxxyyyzzz.  This is 0.11.0.
   API_Version : constant := 11_000;

end Kaitai;
