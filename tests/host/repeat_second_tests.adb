with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Repeat_Second;
with Test_Support;   use Test_Support;

package body Repeat_Second_Tests is

   procedure Run is
      use Repeat_Second;
      Three : constant Bytes (1 .. 4) := (3, 10, 20, 30);
      Two   : constant Bytes (1 .. 3) := (2, 7, 8);
      One   : constant Bytes (1 .. 2) := (1, 5);
      None  : constant Bytes (1 .. 1) := (1 => 0);
      Short : constant Bytes (1 .. 3) := (3, 10, 20);
      S     : Stream := Open (Three);
      This  : T;
   begin
      Group ("examples repeat_second");
      Parse (This, Three, S);
      Check (Valid (This) and then Is_EOF (S), "parses three elements");
      if Valid (This) then
         Check (Belongs_To (This, Three), "the kept element lies in the buffer");
         Check (Has_Second_A (This) and then Second_A (This) = 20, "recs[1].a of three");
      end if;

      S := Open (Two);
      Parse (This, Two, S);
      Check (Valid (This) and then Has_Second_A (This) and then Second_A (This) = 8, "recs[1].a of two, the last one");

      S := Open (One);
      Parse (This, One, S);
      Check (Valid (This) and then not Has_Second_A (This), "one element has no second");

      S := Open (None);
      Parse (This, None, S);
      Check (Valid (This) and then not Has_Second_A (This), "no element has no second");

      S := Open (Short);
      Parse (This, Short, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "the count is more than the data");
   end Run;

end Repeat_Second_Tests;
