with Kaitai.Decoding; use Kaitai.Decoding;
with Kaitai.Streams;  use Kaitai.Streams;
with Kaitai.Types;    use Kaitai.Types;
with Repeat_Elements;
with Test_Support;    use Test_Support;

package body Repeat_Elements_Tests is

   procedure Run is
      use Repeat_Elements;
      Data  : constant Bytes (1 .. 24) :=
        (16#03#,
         16#0A#,
         16#00#,
         16#14#,
         16#00#,
         16#1E#,
         16#00#,
         16#05#,
         16#01#,
         16#07#,
         16#02#,
         16#00#,
         16#03#,
         16#61#,
         16#62#,
         16#00#,
         16#63#,
         16#00#,
         16#09#,
         16#02#,
         16#FF#,
         16#FE#,
         16#00#,
         16#03#);
      Wrong : constant Bytes (1 .. 24) :=
        (16#03#,
         16#0A#,
         16#00#,
         16#14#,
         16#00#,
         16#1E#,
         16#00#,
         16#05#,
         16#01#,
         16#07#,
         16#02#,
         16#00#,
         16#03#,
         16#61#,
         16#62#,
         16#00#,
         16#63#,
         16#00#,
         16#09#,
         16#08#,
         16#FF#,
         16#FE#,
         16#00#,
         16#03#);
      None  : constant Bytes (1 .. 12) :=
        (16#00#, 16#00#, 16#00#, 16#61#, 16#00#, 16#62#, 16#00#, 16#01#, 16#00#, 16#01#, 16#00#, 16#02#);
      S     : Stream := Open (Data);
      This  : Repeat_Elements.T;
   begin
      Group ("Decoding.Min_Element and Max_Element");
      declare
         --  Elements: 1, 0x80 (-128 as s1), 0xFF (-1 as s1), 0x7F, then 0xFF 0xFE (two s2be: -2) in the last two bytes
         Items : constant Bytes (21 .. 26) := (16#01#, 16#80#, 16#FF#, 16#7F#, 16#FF#, 16#FE#);
         Whole : constant Slice := (First => 21, Last => 26);
         Four  : constant Slice := (First => 21, Last => 24);
         Pair  : constant Slice := (First => 25, Last => 26);
      begin
         Check (Elements_OK (Items, Whole, 1, True) and then not Elements_OK (Items, Whole, 4, True), "elements fit");
         Check
           (not Elements_OK (Items, Whole, 8, False) and then not Elements_OK (Items, (First => 3, Last => 2), 1, True),
            "no elements");
         Check (Min_Element (Items, Four, 1, True, Little_Endian) = -128, "s1 min");
         Check (Max_Element (Items, Four, 1, True, Little_Endian) = 127, "s1 max");
         Check (Min_Element (Items, Four, 1, False, Little_Endian) = 1, "u1 min");
         Check (Max_Element (Items, Four, 1, False, Little_Endian) = 255, "u1 max");
         Check (Min_Element (Items, Pair, 2, True, Big_Endian) = -2, "one element is min and max");
         Check (Max_Element (Items, Pair, 2, True, Big_Endian) = -2, "one element is max");
         Check (Min_Element (Items, Whole, 2, False, Little_Endian) = 16#7FFF#, "u2le min");
         Check (Max_Element (Items, Whole, 2, False, Little_Endian) = 16#FEFF#, "u2le max");
         Check (Element (Items, 21, 4, False, Big_Endian) = 16#0180_FF7F#, "u4be");
         Check (Element (Items, 23, 4, True, Little_Endian) = -16_809_985, "s4le");
      end;

      Group ("examples repeat_elements");
      Parse (This, Data, S);
      Check (Valid (This) and then Is_EOF (S), "parses all 24 bytes");
      if Valid (This) then
         Check (Belongs_To (This, Data), "the kept elements lie in the buffer");
         Check (Has_First_Num (This, Data) and then First_Num (This, Data) = 10, "nums.first");
         Check (Has_Last_Num (This, Data) and then Last_Num (This, Data) = 30, "nums.last");
         Check (Has_Second_Num (This, Data) and then Second_Num (This, Data) = 20, "nums[1]");
         Check (Has_First_Rec (This) and then Rec_Type.Tag (First_Rec (This)) = 5, "recs.first, a value of a type");
         Check (Has_Last_Tag (This) and then Last_Tag (This) = 0, "recs.last.tag");
         Check (Has_W_Last_Len (This, Data) and then W_Last_Len (This, Data) = 1, "words.last.length");
         Check (Has_Second_Word_Len (This, Data) and then Second_Word_Len (This, Data) = 1, "words[1].length");
         Check (Has_Min_Num (This, Data) and then Min_Num (This, Data) = 10, "nums.min");
         Check (Has_Max_Num (This, Data) and then Max_Num (This, Data) = 30, "nums.max");
         Check (Has_Min_Signed (This, Data) and then Min_Signed (This, Data) = -2, "signed.min, s2be");
         Check (Has_Max_Signed (This, Data) and then Max_Signed (This, Data) = 3, "signed.max, s2be");
         Check (Has_Last_Signed (This, Data) and then Last_Signed (This, Data) = 3, "signed.last");
         Check (More_Count (This) = 2, "the loop over more ends at 2 = words.first.length + recs.last.tag");
      end if;

      --  The last element does not end the loop of `more`
      S := Open (Wrong);
      Parse (This, Wrong, S);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "no element equals the sum");

      --  No elements in nums: the expressions that need one have no value
      S := Open (None);
      Parse (This, None, S);
      Check (Valid (This), "parses with an empty nums");
      if Valid (This) then
         Check
           (not Has_First_Num (This, None)
            and then not Has_Last_Num (This, None)
            and then not Has_Min_Num (This, None)
            and then not Has_Second_Num (This, None),
            "nums is empty");
      end if;
   end Run;

end Repeat_Elements_Tests;
