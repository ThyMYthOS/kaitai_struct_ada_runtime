with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Repeat_Bits_Use;
with Repeat_Bits_Valid;
with Test_Support;   use Test_Support;

package body Repeat_Bits_Use_Tests is

   procedure Run is
      use Repeat_Bits_Use;
      --  lead 1, flags 0 0 1, head 101, nibbles 1 2 3, three bits of padding, tail 0x77
      Data    : constant Bytes (1 .. 4) := (16#9A#, 16#24#, 16#60#, 16#77#);
      --  Nothing in it ends the flags: the loop takes every bit, the 7 of the byte that the lead began and 8 for each
      --  of the next 3 bytes, and then the turn that finds the end of the data, 8 * 3 + 8 turns in all
      Zeros   : constant Bytes (1 .. 4) := (others => 0);
      --  lead 1, flags 1, head 000, nibbles 15 (`_ + nibbles.first` is 30 at once), tail 0x55
      Largest : constant Bytes (1 .. 3) := (16#C7#, 16#F8#, 16#55#);
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
         Check (Has_First_Plus (This) and then First_Plus (This) = 2, "nibbles.first + 1");
         Check (Has_Mixed (This) and then Mixed (This) = 3001, "nibbles.last * 1000 + nibbles.first");
      end if;

      --  The largest value of a nibble, where the arithmetic on it has no room to spare in 4 bits
      S := Open (Largest);
      Parse (This, Largest, S);
      Check (Valid (This) and then Is_EOF (S), "parses the largest nibbles");
      if Valid (This) then
         Check (Nibbles_Count (This) = 1, "nibbles end at 15 + 15 = 30");
         Get_Nibbles (This, Largest, 0, Element);
         Check (Element = 15, "largest nibble");
         Check (Has_First_Plus (This) and then First_Plus (This) = 16, "15 + 1");
         Check (Has_Mixed (This) and then Mixed (This) = 15_015, "15 * 1000 + 15");
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

      --  examples repeat_bits_valid: the nibbles 1 2 3 12 are valid, 13 is not
      declare
         Good    : constant Bytes (1 .. 2) := (16#12#, 16#3C#);
         Too_Big : constant Bytes (1 .. 2) := (16#12#, 16#3D#);
         Short   : constant Bytes (1 .. 1) := (1 => 16#12#);
         V       : Repeat_Bits_Valid.T;
         Item    : Repeat_Bits_Valid.Bits_Element;
      begin
         Group ("examples repeat_bits_valid");
         S := Open (Good);
         Repeat_Bits_Valid.Parse (V, Good, S);
         Check (Repeat_Bits_Valid.Valid (V) and then Is_EOF (S), "four nibbles up to 12");
         if Repeat_Bits_Valid.Valid (V) then
            Check (Repeat_Bits_Valid.Bits_Count (V) = 4, "four elements");
            Repeat_Bits_Valid.Get_Bits (V, Good, 3, Item);
            Check (Item = 12, "the last nibble, the largest that is valid");
         end if;
         S := Open (Too_Big);
         Repeat_Bits_Valid.Parse (V, Too_Big, S);
         Check
           (not Repeat_Bits_Valid.Valid (V) and then Status (S) = Validation_Greater_Than,
            "a nibble of 13 is not valid");
         S := Open (Short);
         Repeat_Bits_Valid.Parse (V, Short, S);
         Check (not Repeat_Bits_Valid.Valid (V) and then Status (S) = End_Of_Stream, "the count is more than the data");
      end;
   end Run;

end Repeat_Bits_Use_Tests;
