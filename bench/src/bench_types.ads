--  What the benchmarks need beyond the types of the library, which they use
--  so that the hand-written stream designs and the library are measured on
--  the same data.

with Kaitai.Types;

package Bench_Types is

   type Bytes_Access is access Kaitai.Types.Bytes;

end Bench_Types;
