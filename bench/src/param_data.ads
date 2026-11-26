--  Input for the benchmarks of values that come in from outside (param_bench and its counterpart for the target).
--  A record is the part of a parent that the child needs, the number of children N, and N children; the formats are
--  formats/outside/bench_pstr.ksy, bench_puser.ksy and bench_pnav.ksy.  The generators are deterministic, so that the
--  host and the target program see the same bytes.

with Kaitai.Types; use Kaitai.Types;

package Param_Data is

   type Format is
     (Pstr,    --  a string of 4 bytes, N, N strings of 4 bytes of which about half equal the first
      Puser,   --  width and height (u2le), N, N times x, y and `height` bytes
      Pnav);   --  "foo|" or "bar|", N, N times a byte and, after "foo|", another byte

   --  The largest size of a record of Format with N children
   function Record_Max (F : Format; N : Positive) return Length
   is (case F is
         when Pstr  => 5 + 4 * Length (N),
         when Puser => 5 + 5 * Length (N),
         when Pnav  => 5 + 2 * Length (N));

   --  Fill Buffer with Records records of Format with N children each; Used is the number of bytes that are meant.
   --  Buffer has at least Records * Record_Max (F, N) bytes.
   procedure Fill (F : Format; Records : Positive; N : Positive; Buffer : out Bytes; Used : out Length)
   with Pre => Buffer'First = 1 and then Buffer'Length >= Length (Records) * Record_Max (F, N) and then N <= 255;

end Param_Data;
