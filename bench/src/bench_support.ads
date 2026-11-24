--  Timing, memory statistics and input generation.

with Ada.Real_Time;
with Bench_Types;  use Bench_Types;
with Kaitai.Types; use Kaitai.Types;

package Bench_Support is

   --  Deterministic pseudo random numbers (xorshift64)
   type Random_State is private;
   function Seed (Value : U64) return Random_State;
   procedure Next (State : in out Random_State; Value : out U64);

   --  Input for the memory benchmark: Records times
   --     tag : u1,  len : u2le,  payload : len bytes (0 .. Max_Payload)
   function Generate_TLV (Records : Positive; Max_Payload : Natural) return Bytes_Access;

   --  Input for the stream benchmark: Records times 15 bytes
   --     a : u1,  b : u2le,  c : u4le,  d : u8be
   function Generate_Fixed (Records : Positive) return Bytes_Access;

   --  Resident set size of this process in KiB (Linux), 0 if unknown
   function RSS_KiB return Natural;

   type Stopwatch is private;
   function Start return Stopwatch;
   function Elapsed_NS (Watch : Stopwatch) return Long_Float;

   type Samples is array (Positive range <>) of Long_Float;
   function Minimum (Values : Samples) return Long_Float;
   function Median (Values : Samples) return Long_Float;

private

   type Random_State is new U64;

   type Stopwatch is new Ada.Real_Time.Time;

end Bench_Support;
