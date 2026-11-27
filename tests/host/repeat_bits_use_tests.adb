with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Repeat_Bits_Use;
with Test_Support;   use Test_Support;

package body Repeat_Bits_Use_Tests is

   procedure Run is
      use Repeat_Bits_Use;
      --  lead 1, flags 0 0 1, head 101, nibbles 1 2 3, three bits of padding, tail 0x77
      Data    : constant Bytes (1 .. 4) := (16#9A#, 16#24#, 16#60#, 16#77#);
      --  Nothing in it ends the flags: the loop takes every bit, the 7 of the byte that the lead began and 8 for each
      --  of the next 3 bytes, and then the turn that finds the end of the data, 8 * 3 + 8 turns in all
      Zeros   : constant Bytes (1 .. 4) := (others => 0);
      --  lead 1, flags 1, head 000, nibbles 0 0 and 3 bits left, which no nibble 3 ends
      No_End  : constant Bytes (1 .. 2) := (16#C0#, 16#00#);
      --  as Data, but the stream ends in the middle of the third nibble
      Cut     : constant Bytes (1 .. 2) := (16#9A#, 16#24#);
      Long    : constant Bytes (1 .. 5000) := (1 => 16#C0#, others => 0);
      Element : U64;
      Flag    : Boolean;
      S       : Stream := Open (Data);
      This    : T;
   begin
      Group ("examples repeat_bits_use");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses all 4 bytes");
      if Valid (This) then
         Check
           (Lead (This) and then Head (This) = 5 and then Tail (This) = 16#77#, "the fields around the repetitions");
         Check (Flags_Count (This) = 3, "flags end at the first true bit");
         Get_Flags (This, Data, 2, Flag);
         Check (Flag, "the last flag");
         Check (Nibbles_Count (This) = 3, "nibbles end at 3");
         Get_Nibbles (This, Data, 0, Element);
         Check (Element = 1, "first nibble");
         Get_Nibbles (This, Data, 2, Element);
         Check (Element = 3, "last nibble");
      end if;

      S := Open (Zeros);
      Parse (This, Zeros, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "no true flag: the stream ends first");

      S := Open (No_End);
      Parse (This, No_End, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "no nibble 3: the stream ends first");

      S := Open (Cut);
      Parse (This, Cut, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "the stream ends within an element");

      S := Open (Long);
      Parse (This, Long, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "5000 bytes of zeros after the flags");
   end Run;

end Repeat_Bits_Use_Tests;
