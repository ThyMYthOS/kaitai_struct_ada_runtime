with Kaitai.Decoding; use Kaitai.Decoding;
with Kaitai.Types;    use Kaitai.Types;
with Test_Support;    use Test_Support;

package body Decoding_Tests is

   --  The buffer does not start at index 1, to catch code that assumes so
   Data : constant Bytes (11 .. 18) := (16#01#, 16#23#, 16#45#, 16#67#, 16#89#, 16#AB#, 16#CD#, 16#EF#);

   procedure Run is
   begin
      Group ("Decoding.Has");
      Check (Has (Data, 11, 8), "whole buffer");
      Check (Has (Data, 18, 1), "last byte");
      Check (not Has (Data, 18, 2), "one byte too many");
      Check (not Has (Data, 10, 1), "before the buffer");
      Check (not Has (Data, 19, 1), "after the buffer");
      Check (Has (Data, 19, 0), "nothing after the buffer");
      Check (Has (Data, 5, 0), "nothing anywhere");

      Group ("Decoding unsigned");
      Check (U8_At (Data, 11) = 16#01#, "u1 first");
      Check (U8_At (Data, 18) = 16#EF#, "u1 last");
      Check (U16_LE (Data, 11) = 16#2301#, "u2le");
      Check (U16_BE (Data, 11) = 16#0123#, "u2be");
      Check (U16_LE (Data, 17) = 16#EFCD#, "u2le at the end");
      Check (U32_LE (Data, 11) = 16#6745_2301#, "u4le");
      Check (U32_BE (Data, 11) = 16#0123_4567#, "u4be");
      Check (U32_BE (Data, 15) = 16#89AB_CDEF#, "u4be at the end");
      Check (U64_LE (Data, 11) = 16#EFCD_AB89_6745_2301#, "u8le");
      Check (U64_BE (Data, 11) = 16#0123_4567_89AB_CDEF#, "u8be");

      Group ("Decoding signed");
      Check (To_S8 (0) = 0, "s1 zero");
      Check (To_S8 (16#7F#) = 127, "s1 largest");
      Check (To_S8 (16#80#) = -128, "s1 smallest");
      Check (To_S8 (16#FF#) = -1, "s1 minus one");
      Check (To_S16 (16#7FFF#) = 32_767, "s2 largest");
      Check (To_S16 (16#8000#) = -32_768, "s2 smallest");
      Check (To_S16 (16#FFFF#) = -1, "s2 minus one");
      Check (To_S32 (16#7FFF_FFFF#) = S32'Last, "s4 largest");
      Check (To_S32 (16#8000_0000#) = S32'First, "s4 smallest");
      Check (To_S32 (16#FFFF_FFFF#) = -1, "s4 minus one");
      Check (To_S64 (16#7FFF_FFFF_FFFF_FFFF#) = S64'Last, "s8 largest");
      Check (To_S64 (16#8000_0000_0000_0000#) = S64'First, "s8 smallest");
      Check (To_S64 (16#FFFF_FFFF_FFFF_FFFF#) = -1, "s8 minus one");
      Check (To_S64 (16#FFFF_FFFF_FFFF_FFFE#) = -2, "s8 minus two");

      Group ("Types.To_Length");
      Check (To_Length (0) = 0, "zero");
      Check (To_Length (1_000) = 1_000, "small value");
      Check (To_Length (U64'Last) = Length'Last, "too large is mapped to the largest length");
      Check (To_Length (U64 (Length'Last)) = Length'Last, "largest length");

      Group ("Types.Slice");
      Check (Is_Empty (Slice'(First => 1, Last => 0)), "default slice is empty");
      Check (Size (Slice'(First => 5, Last => 4)) = 0, "size of an empty slice");
      Check (Size (Slice'(First => 12, Last => 15)) = 4, "size");
      Check (Within ((First => 12, Last => 15), Data), "slice inside the buffer");
      Check (Within ((First => 11, Last => 18), Data), "slice over the whole buffer");
      Check (not Within ((First => 10, Last => 12), Data), "slice starting too early");
      Check (not Within ((First => 17, Last => 19), Data), "slice ending too late");
      Check (Within ((First => 40, Last => 39), Data), "an empty slice is within any buffer");
   end Run;

end Decoding_Tests;
