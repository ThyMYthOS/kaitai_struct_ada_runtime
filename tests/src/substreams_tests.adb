with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Test_Support;   use Test_Support;

package body Substreams_Tests is

   --                                   5   6   7    8   9  10   11  12  13   14
   Data : constant Bytes (5 .. 14) := (70, 79, 79, 124, 66, 65, 124, 66, 90, 64);

   procedure Test_Term is
      S : Stream := Open (Data);
      D : Slice;
      V : U8;
   begin
      Group ("Streams terminated bytes");
      Read_Bytes_Term (Data, S, 124, Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (D = (First => 5, Last => 7) and then Pos (S) = 4, "up to the terminator, which is consumed");
      Read_Bytes_Term (Data, S, 124, Include => False, Consume => False, EOS_Error => True, Data => D);
      Check (D = (First => 9, Last => 10) and then Pos (S) = 6, "the terminator is left in the stream");
      Read_U1 (Data, S, V);
      Check (V = 124, "and is read next");
      Seek (S, 6);
      Read_Bytes_Term (Data, S, 64, Include => True, Consume => True, EOS_Error => True, Data => D);
      Check (D = (First => 11, Last => 14) and then Is_EOF (S), "the terminator is part of the result");
      Check (OK (S), "still OK");

      S := Open (Data);
      Read_Bytes_Term (Data, S, 70, Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (Is_Empty (D) and then Pos (S) = 1 and then OK (S), "terminator first: nothing, consumed");
      Read_Bytes_Term (Data, S, 79, Include => True, Consume => False, EOS_Error => True, Data => D);
      Check (D = (First => 6, Last => 6) and then Pos (S) = 1, "included but not consumed");

      S := Open (Data);
      Read_Bytes_Term (Data, S, 99, Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (Status (S) = End_Of_Stream and then Is_Empty (D) and then Pos (S) = 0, "no terminator is a failure");
      S := Open (Data);
      Seek (S, 7);
      Read_Bytes_Term (Data, S, 99, Include => False, Consume => True, EOS_Error => False, Data => D);
      Check (OK (S) and then D = (First => 12, Last => 14) and then Is_EOF (S), "or the rest, if that is allowed");
      Read_Bytes_Term (Data, S, 99, Include => False, Consume => True, EOS_Error => False, Data => D);
      Check (OK (S) and then Is_Empty (D), "nothing left, allowed");
      Read_Bytes_Term (Data, S, 99, Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (Status (S) = End_Of_Stream, "nothing left, not allowed");
      Read_Bytes_Term (Data, S, 124, Include => False, Consume => True, EOS_Error => False, Data => D);
      Check (Is_Empty (D) and then Status (S) = End_Of_Stream, "after a failure nothing happens");
   end Test_Term;

   --                                   3  4  5   6  7  8   9  10 11 12 13 14
   Wide : constant Bytes (3 .. 14) := (65, 0, 0, 66, 0, 0, 67, 0, 0, 0, 9, 9);

   procedure Test_Term_Multi is
      S : Stream := Open (Wide);
      D : Slice;
      B : U64;
   begin
      Group ("Streams terminated bytes, long terminator");
      Read_Bytes_Term_Multi (Wide, S, (0, 0), Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (D = (First => 3, Last => 6) and then Pos (S) = 6, "two zeros across units are not the terminator");
      Read_Bytes_Term_Multi (Wide, S, (0, 0), Include => True, Consume => False, EOS_Error => True, Data => D);
      Check (D = (First => 9, Last => 12) and then Pos (S) = 8, "included but not consumed");
      Read_Bytes_Term_Multi (Wide, S, (0, 0), Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (Is_Empty (D) and then Pos (S) = 10 and then OK (S), "terminator first: nothing, consumed");
      Read_Bytes_Term_Multi (Wide, S, (0, 0), Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (Status (S) = End_Of_Stream and then Is_Empty (D) and then Pos (S) = 10, "no terminator is a failure");
      Read_Bytes_Term_Multi (Wide, S, (9, 9), Include => False, Consume => True, EOS_Error => False, Data => D);
      Check (Is_Empty (D) and then Status (S) = End_Of_Stream, "after a failure nothing happens");

      S := Open (Wide);
      Seek (S, 10);
      Read_Bytes_Term_Multi (Wide, S, (0, 0), Include => False, Consume => True, EOS_Error => False, Data => D);
      Check (OK (S) and then D = (First => 13, Last => 14) and then Is_EOF (S), "or the rest, if that is allowed");
      Read_Bytes_Term_Multi (Wide, S, (0, 0), Include => False, Consume => True, EOS_Error => False, Data => D);
      Check (OK (S) and then Is_Empty (D), "nothing left, allowed");

      S := Open (Wide);
      Seek (S, 9);
      Read_Bytes_Term_Multi (Wide, S, (9, 9), Include => False, Consume => True, EOS_Error => False, Data => D);
      Check (OK (S) and then D = (First => 12, Last => 14) and then Is_EOF (S), "a unit cut off at the end is data");
      S := Open (Wide);
      Seek (S, 9);
      Read_Bytes_Term_Multi (Wide, S, (9, 9), Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (Status (S) = End_Of_Stream and then Pos (S) = 9, "or a failure");

      S := Open (Wide);
      Seek (S, 10);
      Read_Bytes_Term_Multi (Wide, S, (9, 9), Include => True, Consume => True, EOS_Error => True, Data => D);
      Check (OK (S) and then D = (First => 13, Last => 14) and then Is_EOF (S), "terminator at the very end");

      S := Open (Wide);
      Read_Bytes_Term_Multi (Wide, S, (67, 0, 0), Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (D = (First => 3, Last => 8) and then Pos (S) = 9, "terminator of three bytes");

      S := Open (Wide);
      Read_Bits_Int_Be (Wide, S, 3, B);
      Read_Bytes_Term_Multi (Wide, S, (0, 0), Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (B = 2 and then Is_Empty (D) and then Pos (S) = 3, "units start at the next whole byte");
      Check (Bits_Left (S) = 0, "and the unread bits are dropped");
   end Test_Term_Multi;

   procedure Test_Contents is
      S : Stream := Open (Data);
   begin
      Group ("Streams contents");
      Read_Contents (Data, S, (70, 79, 79));
      Check (OK (S) and then Pos (S) = 3, "matching contents");
      Read_Contents (Data, S, (1 .. 0 => 0));
      Check (OK (S) and then Pos (S) = 3, "empty contents");
      Read_Contents (Data, S, (124, 66, 66));
      Check (Status (S) = Validation_Not_Equal, "contents that differ");
      Check (Pos (S) = 6, "the bytes were read");
      S := Open (Data);
      Seek (S, 8);
      Read_Contents (Data, S, (90, 64, 0));
      Check (Status (S) = End_Of_Stream and then Pos (S) = 8, "contents beyond the end");
   end Test_Contents;

   procedure Test_Substream is
      S   : Stream := Open (Data);
      Sub : Stream;
      V   : U8;
      W   : U16;
      D   : Slice;
   begin
      Group ("Streams substream");
      Skip (S, 1);
      Substream (Data, S, 3, Sub);
      Check (OK (S) and then Pos (S) = 4, "the parent moves past the substream");
      Check (OK (Sub) and then Size (Sub) = 3 and then Pos (Sub) = 0, "the substream covers the bytes");
      Check (Is_Valid (Sub, Data) and then Next_Index (Sub) = 6, "it refers to the same buffer");
      Read_U1 (Data, Sub, V);
      Check (V = 79, "read from the substream");
      Read_Bytes_Full (Sub, D);
      Check (D = (First => 7, Last => 8) and then Is_EOF (Sub), "the rest of the substream ends where it ends");
      Read_U1 (Data, Sub, V);
      Check (Status (Sub) = End_Of_Stream, "the substream cannot read beyond its end");
      Check (OK (S), "which does not concern the parent");
      Join (S, Sub);
      Check (Status (S) = End_Of_Stream and then Pos (S) = 4, "until it is told");

      S := Open (Data);
      Substream (Data, S, 0, Sub);
      Check (OK (S) and then OK (Sub) and then Size (Sub) = 0 and then Pos (S) = 0, "empty substream");
      Substream (Data, S, 10, Sub);
      Check (OK (Sub) and then Size (Sub) = 10 and then Is_EOF (S), "substream over everything");
      Seek (Sub, 8);
      Read_U2le (Data, Sub, W);
      Check (W = 16#405A#, "seek within the substream");
      Join (S, Sub);
      Check (OK (S), "joining a good substream changes nothing");

      S := Open (Data);
      Skip (S, 8);
      Substream (Data, S, 3, Sub);
      Check (Status (S) = End_Of_Stream and then Pos (S) = 8, "a substream beyond the end fails");
      Check (not OK (Sub) and then Size (Sub) = 0, "and is empty and failed itself");
      Read_U1 (Data, Sub, V);
      Check (V = 0, "reading from it does nothing");

      S := Open (Data);
      Fail (S, Validation_Expr);
      Substream (Data, S, 1, Sub);
      Check (Status (Sub) = Validation_Expr, "a substream of a failed stream has failed for the same reason");
      S := Open (Data);
      Fail (S, Validation_Expr);
      Sub := Open (Data);
      Fail (Sub, Limit_Exceeded);
      Join (S, Sub);
      Check (Status (S) = Validation_Expr, "join keeps the first failure");
   end Test_Substream;

   procedure Test_Elements is
      S    : Stream := Open (Data);
      From : Stream;
      D    : Slice;
      V    : U8;
   begin
      Group ("Streams elements of a fixed size");
      Read_Elements (S, Count => 2, Element_Size => 3, Data => D);
      Check (OK (S) and then D = (First => 5, Last => 10) and then Pos (S) = 6, "two elements of three bytes");
      Read_Elements (S, Count => 0, Element_Size => 3, Data => D);
      Check (OK (S) and then Is_Empty (D) and then D.First = 11 and then Pos (S) = 6, "no element");
      Read_Elements (S, Count => 4, Element_Size => 1, Data => D);
      Check (OK (S) and then D = (First => 11, Last => 14) and then Is_EOF (S), "exactly what is left");
      Read_Elements (S, Count => 1, Element_Size => 1, Data => D);
      Check (Status (S) = End_Of_Stream and then Is_Empty (D), "one more than is left");

      S := Open (Data);
      Read_Elements (S, Count => 3, Element_Size => 4, Data => D);
      Check (Status (S) = End_Of_Stream and then Pos (S) = 0, "the last element is incomplete");
      S := Open (Data);
      Read_Elements (S, Count => Length'Last, Element_Size => Length'Last, Data => D);
      Check (Status (S) = End_Of_Stream and then Is_Empty (D), "a count and a size beyond every buffer");
      S := Open (Data);
      Read_Elements (S, Count => Length'Last / 2 + 1, Element_Size => 2, Data => D);
      Check (Status (S) = End_Of_Stream and then Is_Empty (D), "a product that does not fit a length");

      S := Open (Data);
      Read_Elements_Full (S, Element_Size => 5, Data => D);
      Check (OK (S) and then D = (First => 5, Last => 14) and then Is_EOF (S), "all that is left, in whole elements");
      Read_Elements_Full (S, Element_Size => 5, Data => D);
      Check (OK (S) and then Is_Empty (D), "nothing left is no element");
      S := Open (Data);
      Read_Elements_Full (S, Element_Size => 3, Data => D);
      Check (Status (S) = End_Of_Stream and then Is_Empty (D) and then Pos (S) = 0, "the rest is no whole element");
      S := Open (Data);
      Skip (S, 4);
      Read_Elements_Full (S, Element_Size => 2, Data => D);
      Check (OK (S) and then D = (First => 9, Last => 14), "from the current position");
      Read_Elements_Full (S, Element_Size => 2, Data => D);
      Fail (S, Validation_Expr);
      Read_Elements_Full (S, Element_Size => 1, Data => D);
      Check (Status (S) = Validation_Expr and then Is_Empty (D), "after a failure nothing happens");

      Group ("Streams bytes between two positions");
      S := Open (Data);
      Skip (S, 2);
      From := S;
      Check (Is_Empty (Between (From, S)) and then Between (From, S).First = 7, "nothing read yet");
      Read_U1 (Data, S, V);
      Read_U1 (Data, S, V);
      Check (Between (From, S) = (First => 7, Last => 8) and then V = 124, "two bytes read");
      Skip (S, 6);
      Check (Between (From, S) = (First => 7, Last => 14), "up to the end");

      Group ("Sizes and counts from expressions");
      Check (To_Size (0) = 0 and then To_Size (17) = 17, "a size");
      Check (To_Size (-1) = Length'Last and then To_Size (S64'First) = Length'Last, "a negative size cannot be read");
      Check (To_Size (S64'Last) = Length'Last, "the largest size cannot be read either");
      Check (To_Count (0) = 0 and then To_Count (17) = 17, "a count");
      Check (To_Count (-1) = 0 and then To_Count (S64'First) = 0, "a negative count means no element");
      Check (To_Count (S64'Last) = Length'Last, "the largest count");
   end Test_Elements;

   procedure Run is
   begin
      Test_Elements;
      Test_Term;
      Test_Term_Multi;
      Test_Contents;
      Test_Substream;
   end Run;

end Substreams_Tests;
