--  Operations on byte arrays that are given as slices of a buffer.  None of
--  them copies data; where the result is a byte array, it is a slice of the
--  same buffer.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Byte_Arrays
  with Pure, SPARK_Mode, Always_Terminates
is

   --  Index of the first byte of Item that equals Term, or Item.Last + 1 if
   --  there is none
   function Find (Buffer : Bytes; Item : Slice; Term : Byte) return Length
   with
     Pre  => Within (Item, Buffer),
     Post =>
       Find'Result in Item.First .. Item.Last + 1
       and then (for all I in Item.First .. Find'Result - 1 => Buffer (I) /= Term)
       and then (if Find'Result <= Item.Last then Buffer (Find'Result) = Term);

   --  Item up to the first byte that equals Term, with or without that
   --  byte; all of Item if there is none.  This is bytes_terminate of the
   --  Kaitai Struct stream API.
   function Terminate_At (Buffer : Bytes; Item : Slice; Term : Byte; Include : Boolean) return Slice
   with
     Pre  => Within (Item, Buffer),
     Post =>
       Within (Terminate_At'Result, Buffer)
       and then Terminate_At'Result.First = Item.First
       and then Terminate_At'Result.Last <= Item.Last
       and then Terminate_At'Result.Last
                = (if Find (Buffer, Item, Term) > Item.Last
                   then Item.Last
                   elsif Include
                   then Find (Buffer, Item, Term)
                   else Find (Buffer, Item, Term) - 1);

   --  Item without the bytes at its end that equal Pad.  This is
   --  bytes_strip_right of the Kaitai Struct stream API.
   function Strip_Right (Buffer : Bytes; Item : Slice; Pad : Byte) return Slice
   with
     Pre  => Within (Item, Buffer),
     Post =>
       Within (Strip_Right'Result, Buffer)
       and then Strip_Right'Result.First = Item.First
       and then Strip_Right'Result.Last <= Item.Last
       and then (for all I in Strip_Right'Result.Last + 1 .. Item.Last => Buffer (I) = Pad)
       and then (if not Is_Empty (Strip_Right'Result) then Buffer (Strip_Right'Result.Last) /= Pad);

   --  True if Item holds exactly the bytes of Expected
   function Equal (Buffer : Bytes; Item : Slice; Expected : Bytes) return Boolean
   with
     Pre  => Within (Item, Buffer),
     Post =>
       Equal'Result
       = (Size (Item) = Expected'Length
          and then (for all I in Item.First .. Item.Last => Buffer (I) = Expected (Expected'First + (I - Item.First))));

end Kaitai.Byte_Arrays;
