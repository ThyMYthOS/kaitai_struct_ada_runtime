with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Test_Support;   use Test_Support;

package body Streams_Tests is

   Data : constant Bytes (11 .. 18) := (16#01#, 16#23#, 16#45#, 16#67#, 16#89#, 16#AB#, 16#CD#, 16#EF#);

   Ones : constant Bytes (1 .. 8) := (others => 16#FF#);

   Empty : constant Bytes (1 .. 0) := (others => 0);

   procedure Test_State is
      S : Stream := Open (Data);
      E : constant Stream := Open (Empty);
      D : Stream;
      V : U8;
   begin
      Group ("Streams state");
      Check (OK (S), "a new stream is OK");
      Check (Status (S) = Success, "a new stream has status Success");
      Check (Size (S) = 8, "size");
      Check (Pos (S) = 0, "position at the start");
      Check (Remaining (S) = 8, "remaining at the start");
      Check (not Is_EOF (S), "not at the end");
      Check (Next_Index (S) = 11, "next index is the first index of the buffer");
      Check (Is_Valid (S, Data), "valid for its buffer");

      Check (Size (E) = 0 and then Is_EOF (E) and then OK (E), "a stream over an empty buffer");
      Check (Is_Valid (E, Data), "an empty stream is valid for any buffer");
      Check (OK (D) and then Size (D) = 0 and then Is_EOF (D), "a stream that was never opened is empty");

      Read_U1 (Data, D, V);
      Check (not OK (D) and then V = 0, "reading from a stream that was never opened fails");

      for I in 1 .. 8 loop
         Read_U1 (Data, S, V);
      end loop;
      Check (OK (S) and then Is_EOF (S) and then Pos (S) = 8, "at the end after reading everything");
      Check (V = 16#EF#, "last byte read");
   end Test_State;

   procedure Test_Unsigned is
      S   : Stream := Open (Data);
      V8  : U8;
      V16 : U16;
      V32 : U32;
      V64 : U64;
   begin
      Group ("Streams unsigned");
      Read_U1 (Data, S, V8);
      Check (V8 = 16#01# and then Pos (S) = 1, "u1");
      Read_U2le (Data, S, V16);
      Check (V16 = 16#4523# and then Pos (S) = 3, "u2le");
      Read_U2be (Data, S, V16);
      Check (V16 = 16#6789# and then Pos (S) = 5, "u2be");
      Seek (S, 0);
      Read_U4le (Data, S, V32);
      Check (V32 = 16#6745_2301# and then Pos (S) = 4, "u4le");
      Read_U4be (Data, S, V32);
      Check (V32 = 16#89AB_CDEF# and then Is_EOF (S), "u4be");
      Seek (S, 0);
      Read_U8le (Data, S, V64);
      Check (V64 = 16#EFCD_AB89_6745_2301# and then Is_EOF (S), "u8le");
      Seek (S, 0);
      Read_U8be (Data, S, V64);
      Check (V64 = 16#0123_4567_89AB_CDEF# and then Is_EOF (S), "u8be");
      Check (OK (S), "still OK");

      Group ("Streams byte order as parameter");
      Seek (S, 0);
      Read_U2 (Data, S, Little_Endian, V16);
      Check (V16 = 16#2301#, "u2 little endian");
      Read_U2 (Data, S, Big_Endian, V16);
      Check (V16 = 16#4567#, "u2 big endian");
      Seek (S, 0);
      Read_U4 (Data, S, Little_Endian, V32);
      Check (V32 = 16#6745_2301#, "u4 little endian");
      Read_U4 (Data, S, Big_Endian, V32);
      Check (V32 = 16#89AB_CDEF#, "u4 big endian");
      Seek (S, 0);
      Read_U8 (Data, S, Little_Endian, V64);
      Check (V64 = 16#EFCD_AB89_6745_2301#, "u8 little endian");
      Seek (S, 0);
      Read_U8 (Data, S, Big_Endian, V64);
      Check (V64 = 16#0123_4567_89AB_CDEF#, "u8 big endian");
      Check (OK (S), "still OK");
   end Test_Unsigned;

   procedure Test_Signed is
      S   : Stream := Open (Ones);
      T   : Stream := Open (Data);
      V8  : S8;
      V16 : S16;
      V32 : S32;
      V64 : S64;
   begin
      Group ("Streams signed");
      Read_S1 (Ones, S, V8);
      Check (V8 = -1, "s1 of FF");
      Seek (S, 0);
      Read_S2le (Ones, S, V16);
      Check (V16 = -1, "s2le of FFFF");
      Read_S2be (Ones, S, V16);
      Check (V16 = -1, "s2be of FFFF");
      Seek (S, 0);
      Read_S4le (Ones, S, V32);
      Check (V32 = -1, "s4le of FFFFFFFF");
      Read_S4be (Ones, S, V32);
      Check (V32 = -1, "s4be of FFFFFFFF");
      Seek (S, 0);
      Read_S8le (Ones, S, V64);
      Check (V64 = -1, "s8le of all ones");
      Seek (S, 0);
      Read_S8be (Ones, S, V64);
      Check (V64 = -1, "s8be of all ones");

      Read_S1 (Data, T, V8);
      Check (V8 = 1, "s1 positive");
      Seek (T, 4);
      Read_S1 (Data, T, V8);
      Check (V8 = -119, "s1 of 89");
      Seek (T, 4);
      Read_S2be (Data, T, V16);
      Check (V16 = -30_293, "s2be of 89AB");
      Seek (T, 4);
      Read_S2le (Data, T, V16);
      Check (V16 = -21_623, "s2le of 89AB");
      Seek (T, 4);
      Read_S4be (Data, T, V32);
      Check (V32 = -1_985_229_329, "s4be of 89ABCDEF");
      Seek (T, 0);
      Read_S4be (Data, T, V32);
      Check (V32 = 19_088_743, "s4be positive");
      Seek (T, 0);
      Read_S8be (Data, T, V64);
      Check (V64 = 81_985_529_216_486_895, "s8be positive");
      Seek (T, 0);
      Read_S8le (Data, T, V64);
      Check (V64 = -1_167_088_121_787_636_991, "s8le negative");
      Seek (T, 4);
      Read_S2 (Data, T, Big_Endian, V16);
      Check (V16 = -30_293, "s2 big endian");
      Seek (T, 4);
      Read_S4 (Data, T, Little_Endian, V32);
      Check (V32 = -271_733_879, "s4 little endian");
      Seek (T, 0);
      Read_S8 (Data, T, Big_Endian, V64);
      Check (V64 = 81_985_529_216_486_895, "s8 big endian");
      Check (OK (S) and then OK (T), "still OK");
   end Test_Signed;

   procedure Test_Failure is
      S   : Stream := Open (Data);
      V8  : U8;
      V16 : U16;
      V32 : U32;
      V64 : U64;
      W64 : S64;
      D   : Slice;
   begin
      Group ("Streams failure");
      Seek (S, 6);
      Read_U4le (Data, S, V32);
      Check (not OK (S), "reading four bytes with two left fails");
      Check (Status (S) = End_Of_Stream, "status is End_Of_Stream");
      Check (V32 = 0, "a failed read delivers zero");
      Check (Pos (S) = 6, "a failed read does not move");

      --  Two bytes are left, but the stream has failed: nothing works any more
      Read_U1 (Data, S, V8);
      Check (V8 = 0 and then Pos (S) = 6, "u1 after a failure does nothing");
      Read_U2be (Data, S, V16);
      Check (V16 = 0 and then Pos (S) = 6, "u2 after a failure does nothing");
      Read_U8le (Data, S, V64);
      Check (V64 = 0, "u8 after a failure does nothing");
      Read_S8be (Data, S, W64);
      Check (W64 = 0, "s8 after a failure does nothing");
      Seek (S, 0);
      Check (Pos (S) = 6, "seek after a failure does nothing");
      Skip (S, 1);
      Check (Pos (S) = 6, "skip after a failure does nothing");
      Read_Bytes (S, 1, D);
      Check (Is_Empty (D) and then Pos (S) = 6, "bytes after a failure does nothing");
      Read_Bytes_Full (S, D);
      Check (Is_Empty (D) and then Pos (S) = 6, "bytes-full after a failure does nothing");
      Fail (S, Validation_Not_Equal);
      Check (Status (S) = End_Of_Stream, "the first failure is kept");
      Check (Is_Valid (S, Data), "a failed stream is still valid for its buffer");

      Group ("Streams failure at each width");
      S := Open (Data);
      Seek (S, 8);
      Read_U1 (Data, S, V8);
      Check (Status (S) = End_Of_Stream and then V8 = 0, "u1 at the end");
      S := Open (Data);
      Seek (S, 7);
      Read_U2le (Data, S, V16);
      Check (Status (S) = End_Of_Stream and then V16 = 0, "u2 with one byte left");
      S := Open (Data);
      Seek (S, 1);
      Read_U8be (Data, S, V64);
      Check (Status (S) = End_Of_Stream and then V64 = 0, "u8 with seven bytes left");
      S := Open (Empty);
      Read_U2le (Empty, S, V16);
      Check (Status (S) = End_Of_Stream and then V16 = 0, "u2 from an empty buffer");

      Group ("Streams Fail");
      S := Open (Data);
      Fail (S, Validation_Not_In_Enum);
      Check (not OK (S) and then Status (S) = Validation_Not_In_Enum, "Fail records the reason");
      Check (Pos (S) = 0 and then Size (S) = 8, "Fail leaves position and size");
      Read_U1 (Data, S, V8);
      Check (V8 = 0 and then Status (S) = Validation_Not_In_Enum, "a read after Fail keeps the reason");
   end Test_Failure;

   procedure Test_Positioning is
      S : Stream := Open (Data);
      V : U8;
   begin
      Group ("Streams positioning");
      Seek (S, 3);
      Check (Pos (S) = 3 and then Next_Index (S) = 14, "seek");
      Read_U1 (Data, S, V);
      Check (V = 16#67#, "read after seek");
      Seek (S, 8);
      Check (OK (S) and then Is_EOF (S), "seek to the end is allowed");
      Seek (S, 0);
      Check (Pos (S) = 0, "seek back to the start");
      Skip (S, 5);
      Check (Pos (S) = 5, "skip");
      Skip (S, 0);
      Check (Pos (S) = 5 and then OK (S), "skip nothing");
      Skip (S, 3);
      Check (Is_EOF (S) and then OK (S), "skip to the end");
      Skip (S, 1);
      Check (Status (S) = End_Of_Stream and then Pos (S) = 8, "skip beyond the end fails");

      S := Open (Data);
      Seek (S, 9);
      Check (Status (S) = End_Of_Stream and then Pos (S) = 0, "seek beyond the end fails");

      S := Open (Data);
      Skip (S, Length'Last);
      Check (Status (S) = End_Of_Stream and then Pos (S) = 0, "skip by the largest length fails");

      S := Open (Data);
      Advance (S, 8);
      Check (Is_EOF (S) and then OK (S), "advance");
   end Test_Positioning;

   procedure Test_Bytes is
      S : Stream := Open (Data);
      D : Slice;
   begin
      Group ("Streams bytes");
      Read_Bytes (S, 3, D);
      Check (D.First = 11 and then D.Last = 13, "first three bytes");
      Check (Within (D, Data), "the slice lies within the buffer");
      Check (Data (D.First .. D.Last) = (16#01#, 16#23#, 16#45#), "content through the slice");
      Read_Bytes (S, 0, D);
      Check (Is_Empty (D) and then OK (S) and then Pos (S) = 3, "no bytes");
      Read_Bytes (S, 5, D);
      Check (D.First = 14 and then D.Last = 18 and then Is_EOF (S), "the rest");
      Read_Bytes (S, 0, D);
      Check (Is_Empty (D) and then OK (S), "no bytes at the end");
      Read_Bytes (S, 1, D);
      Check (Is_Empty (D) and then Status (S) = End_Of_Stream, "one byte at the end fails");

      S := Open (Data);
      Read_Bytes (S, 9, D);
      Check (Is_Empty (D) and then Status (S) = End_Of_Stream and then Pos (S) = 0, "more bytes than there are");

      S := Open (Data);
      Read_Bytes (S, To_Length (U64'Last), D);
      Check (Is_Empty (D) and then Status (S) = End_Of_Stream, "a length no buffer can have");

      Group ("Streams bytes-full");
      S := Open (Data);
      Skip (S, 6);
      Read_Bytes_Full (S, D);
      Check (D.First = 17 and then D.Last = 18 and then Is_EOF (S), "the last two bytes");
      Read_Bytes_Full (S, D);
      Check (Is_Empty (D) and then OK (S), "nothing left is not a failure");
      S := Open (Empty);
      Read_Bytes_Full (S, D);
      Check (Is_Empty (D) and then OK (S), "empty buffer");
   end Test_Bytes;

   procedure Run is
   begin
      Test_State;
      Test_Unsigned;
      Test_Signed;
      Test_Failure;
      Test_Positioning;
      Test_Bytes;
   end Run;

end Streams_Tests;
