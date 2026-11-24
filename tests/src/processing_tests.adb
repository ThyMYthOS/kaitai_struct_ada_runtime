with Kaitai.Arenas;     use Kaitai.Arenas;
with Kaitai.Processing; use Kaitai.Processing;
with Kaitai.Types;      use Kaitai.Types;
with Test_Support;      use Test_Support;

package body Processing_Tests is

   Source : constant Bytes (11 .. 17) := (16#00#, 16#FF#, 16#0F#, 16#A5#, 16#01#, 16#80#, 16#3C#);

   procedure Test_Xor is
      Target : Bytes (1 .. 7) := (others => 16#EE#);
      Small  : Bytes (1 .. 1) := (others => 16#EE#);
      None   : Bytes (1 .. 0);
   begin
      Group ("Processing.Xor_One");
      Xor_One (Source, 16#FF#, Target);
      Check (Target = (16#FF#, 16#00#, 16#F0#, 16#5A#, 16#FE#, 16#7F#, 16#C3#), "all bits flipped");
      Xor_One (Source, 0, Target);
      Check (Target = Source, "key zero changes nothing");
      Xor_One (Source (14 .. 14), 16#A5#, Small);
      Check (Small (1) = 0, "one byte with itself");
      Xor_One (Source (14 .. 13), 1, None);
      Check (None'Length = 0, "nothing to do");
      Xor_One (Source (12 .. 13), 16#0F#, Target (6 .. 7));
      Check (Target (6 .. 7) = (16#F0#, 16#00#) and then Target (5) = 1, "into a part of the target only");

      Group ("Processing.Xor_Many");
      Xor_Many (Source, (16#FF#, 16#0F#, 16#01#), Target);
      Check (Target = (16#FF#, 16#F0#, 16#0E#, 16#5A#, 16#0E#, 16#81#, 16#C3#), "the key is used again and again");
      Xor_Many (Source, (1 => 16#FF#), Target);
      Check (Target = (16#FF#, 16#00#, 16#F0#, 16#5A#, 16#FE#, 16#7F#, 16#C3#), "key of one byte");
      Xor_Many (Source (11 .. 12), (1, 2, 3, 4, 5), Target (1 .. 2));
      Check (Target (1 .. 2) = (16#01#, 16#FD#), "key longer than the data");
      Xor_Many (Source, Source, Target);
      Check (Target = (1 .. 7 => 0), "key as long as the data");
      Xor_Many (Source (14 .. 13), (1, 2), None);
      Check (None'Length = 0, "nothing to do");
      Xor_Many (Source (11 .. 16), Bytes'(20 => 1, 21 => 2), Target (2 .. 7));
      Check (Target (2 .. 7) = (16#01#, 16#FD#, 16#0E#, 16#A7#, 16#00#, 16#82#), "bounds that do not start at one");
   end Test_Xor;

   procedure Test_Rotate is
      Target : Bytes (1 .. 7) := (others => 16#EE#);
   begin
      Group ("Processing.Rotate_Left");
      Rotate_Left (Source, 1, Target);
      Check (Target = (16#00#, 16#FF#, 16#1E#, 16#4B#, 16#02#, 16#01#, 16#78#), "by one");
      Rotate_Left (Source, 4, Target);
      Check (Target = (16#00#, 16#FF#, 16#F0#, 16#5A#, 16#10#, 16#08#, 16#C3#), "by four");
      Rotate_Left (Source, 7, Target);
      Check (Target = (16#00#, 16#FF#, 16#87#, 16#D2#, 16#80#, 16#40#, 16#1E#), "by seven");
      Rotate_Left (Source, 0, Target);
      Check (Target = Source, "by zero");
      Rotate_Left (Source, 8, Target);
      Check (Target = Source, "by eight is by zero");
      Rotate_Left (Source, 9, Target);
      Check (Target (3) = 16#1E#, "by nine is by one");
      Rotate_Left (Source, 8 - 3, Target);
      Check (Target (4) = 16#B4# and then Target (5) = 16#20#, "to the right by three");
      Rotate_Left (Source, -1, Target);
      Check (Target (5) = 16#80# and then Target (6) = 16#40#, "a negative amount is to the right");
      Rotate_Left (Source, Integer'First, Target);
      Check (Target = Source, "the smallest amount is a multiple of eight");
      Rotate_Left (Source, Integer'Last, Target);
      Check (Target (5) = 16#80#, "the largest amount is seven modulo eight");
   end Test_Rotate;

   procedure Test_Arena is
      Storage : Bytes (101 .. 110) := (others => 16#EE#);
      A       : Arena := Open (Storage);
      Item    : Slice;
      Second  : Slice;
      OK      : Boolean;
      M       : Length;
   begin
      Group ("Arenas");
      Check (Capacity (A) = 10 and then Used (A) = 0 and then Available (A) = 10, "a new arena is empty");
      Check (Is_Empty (In_Use (A)), "nothing in use");
      Reserve (A, 4, Item, OK);
      Check (OK and then Item = (First => 101, Last => 104) and then Used (A) = 4, "first reservation");
      Reserve (A, 0, Second, OK);
      Check (OK and then Is_Empty (Second) and then Used (A) = 4, "nothing reserved");
      M := Mark (A);
      Store (Storage, A, Source (11 .. 15), Second, OK);
      Check (OK and then Second = (First => 105, Last => 109) and then Used (A) = 9, "stored after it");
      Check (Storage (105 .. 109) = Source (11 .. 15), "the bytes are there");
      Check (Storage (104) = 16#EE# and then Storage (110) = 16#EE#, "and nothing around them changed");
      Check (Holds (A, Item) and then Holds (A, Second), "both are held");
      Check (In_Use (A) = (First => 101, Last => 109), "in use");
      Reserve (A, 2, Item, OK);
      Check (not OK and then Is_Empty (Item) and then Used (A) = 9, "more than is left");
      Store (Storage, A, Source (11 .. 12), Item, OK);
      Check (not OK and then Storage (110) = 16#EE# and then Used (A) = 9, "stores nothing if it does not fit");
      Reserve (A, 1, Item, OK);
      Check (OK and then Item = (First => 110, Last => 110) and then Available (A) = 0, "the last byte");
      Reserve (A, 1, Item, OK);
      Check (not OK, "full");
      Reserve (A, Length'Last, Item, OK);
      Check (not OK and then Used (A) = 10, "the largest request");
      Release (A, M);
      Check (Used (A) = 4 and then not Holds (A, Second), "released down to the mark");
      Reserve (A, 6, Item, OK);
      Check (OK and then Item = (First => 105, Last => 110), "the released bytes are handed out again");
      Reset (A);
      Check (Used (A) = 0 and then Capacity (A) = 10, "reset");

      A := Open (Storage (104 .. 103));
      Check (Capacity (A) = 0, "storage without bytes");
      Reserve (A, 0, Item, OK);
      Check (OK and then Is_Empty (Item), "has room for nothing");
      Reserve (A, 1, Item, OK);
      Check (not OK, "and for nothing else");

      --  The way generated code uses an arena with a process routine
      A := Open (Storage);
      Reserve (A, Source'Length, Item, OK);
      if OK then
         Xor_One (Source, 16#FF#, Storage (Item.First .. Item.Last));
      end if;
      Check (OK and then Storage (101) = 16#FF# and then Storage (107) = 16#C3#, "result of a process routine");
   end Test_Arena;

   procedure Run is
   begin
      Test_Xor;
      Test_Rotate;
      Test_Arena;
   end Run;

end Processing_Tests;
