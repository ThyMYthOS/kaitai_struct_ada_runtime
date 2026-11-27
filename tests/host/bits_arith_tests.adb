with Bits_Arith;     use Bits_Arith;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Test_Support;   use Test_Support;

package body Bits_Arith_Tests is

   procedure Run is
      --  n = 9, m = 15, wide = 16#ABC#, pad = 5, huge = 2**63 - 1, last = 1
      Most  : constant Bytes (1 .. 11) := (16#9F#, 16#AB#, 16#C5#, others => 16#FF#);
      --  n = 15, m = 15, the same wide and pad, huge = 0, last = 0
      Large : constant Bytes (1 .. 11) := (16#FF#, 16#AB#, 16#C5#, others => 0);
      Short : constant Bytes (1 .. 10) := (others => 0);
      S     : Stream := Open (Most);
      This  : T;
   begin
      Group ("examples bits_arith");
      Parse (This, Most, S);
      Check (Valid (This) and then Is_EOF (S), "parses 11 bytes");
      if Valid (This) then
         Check
           (N (This) = 9 and then M (This) = 15 and then Wide (This) = 16#ABC# and then Pad (This) = 5, "the fields");
         Check (Huge (This) = 2**63 - 1 and then Last (This), "the 63 bits and the last one");
         Check (Has_Plus (This) and then Plus (This) = 10, "n + 1");
         Check (Has_Sum (This) and then Sum (This) = 24, "m + n");
         Check (Has_Scaled (This) and then Scaled (This) = 9_000_000_000_000, "n * 10**12");
         Check
           (Has_Big (This) and then Big (This) = 9_000_000_000_000_000_000,
            "n * 10**18 for n = 9, the largest that fits");
         Check (Has_Wide_X (This) and then Wide_X (This) = 2_748_001, "wide * 1000 + 1");
         Check (not Has_Huge_Plus (This), "2**63 - 1 + 1 is not defined");
      end if;

      S := Open (Large);
      Parse (This, Large, S);
      Check (Valid (This), "parses the second input");
      if Valid (This) then
         Check (Has_Plus (This) and then Plus (This) = 16, "15 + 1");
         Check (Has_Sum (This) and then Sum (This) = 30, "15 + 15");
         Check (Has_Scaled (This) and then Scaled (This) = 15_000_000_000_000, "15 * 10**12");
         Check (not Has_Big (This), "15 * 10**18 overflows and is not defined");
         Check (Has_Huge_Plus (This) and then Huge_Plus (This) = 1, "0 + 1");
      end if;

      S := Open (Short);
      Parse (This, Short, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "one byte short");
   end Run;

end Bits_Arith_Tests;
