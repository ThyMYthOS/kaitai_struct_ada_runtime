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

   --  Index of the first unit of Item that equals Term, or Item.Last + 1 if
   --  there is none.  Item is taken as a sequence of units that are as long
   --  as Term, which is how the Kaitai Struct stream API looks for a
   --  terminator of several bytes: a UTF-16 string ends at a zero code
   --  unit, not at any two zero bytes.  Bytes at the end of Item that do
   --  not make a whole unit never match.
   function Find_Multi (Buffer : Bytes; Item : Slice; Term : Bytes) return Length
   with
     Pre  => Within (Item, Buffer) and then Term'Length > 0,
     Post =>
       Find_Multi'Result in Item.First .. Item.Last + 1
       and then (if Find_Multi'Result <= Item.Last
                 then
                   (Find_Multi'Result - Item.First) mod Term'Length = 0
                   and then Term'Length - 1 <= Item.Last - Find_Multi'Result
                   and then Equal
                              (Buffer,
                               (First => Find_Multi'Result, Last => Find_Multi'Result + (Term'Length - 1)),
                               Term));

   --  Item up to the first unit that equals Term, with or without that
   --  unit; all of Item if there is none.  This is bytes_terminate_multi of
   --  the Kaitai Struct stream API.
   function Terminate_At_Multi (Buffer : Bytes; Item : Slice; Term : Bytes; Include : Boolean) return Slice
   with
     Pre  => Within (Item, Buffer) and then Term'Length > 0,
     Post =>
       Within (Terminate_At_Multi'Result, Buffer)
       and then Terminate_At_Multi'Result.First = Item.First
       and then Terminate_At_Multi'Result.Last <= Item.Last
       and then Terminate_At_Multi'Result.Last
                = (if Find_Multi (Buffer, Item, Term) > Item.Last
                   then Item.Last
                   elsif Include
                   then Find_Multi (Buffer, Item, Term) + (Term'Length - 1)
                   else Find_Multi (Buffer, Item, Term) - 1);

   --  The smallest byte of Item; 255 if Item is empty
   function Min (Buffer : Bytes; Item : Slice) return Byte
   with
     Pre  => Within (Item, Buffer),
     Post =>
       (for all I in Item.First .. Item.Last => Min'Result <= Buffer (I))
       and then (if Is_Empty (Item)
                 then Min'Result = Byte'Last
                 else (for some I in Item.First .. Item.Last => Min'Result = Buffer (I)));

   --  The largest byte of Item; 0 if Item is empty
   function Max (Buffer : Bytes; Item : Slice) return Byte
   with
     Pre  => Within (Item, Buffer),
     Post =>
       (for all I in Item.First .. Item.Last => Max'Result >= Buffer (I))
       and then (if Is_Empty (Item)
                 then Max'Result = Byte'First
                 else (for some I in Item.First .. Item.Last => Max'Result = Buffer (I)));

   type Order is (Less, Same, Greater);

   --  Left compared with Right byte by byte, as Kaitai Struct orders byte
   --  arrays: the first byte that differs decides, and if there is none,
   --  the shorter array is the lesser one.
   function Compare (Left, Right : Bytes) return Order
   with
     Post =>
       (case Compare'Result is
          when Same    => Left'Length = Right'Length and then Common_Prefix (Left, Right, Left'Length),
          when Less    =>
            (for some K in 0 .. Length'Min (Left'Length, Right'Length) =>
               Common_Prefix (Left, Right, K)
               and then (if K < Length'Min (Left'Length, Right'Length)
                         then Left (Left'First + K) < Right (Right'First + K)
                         else Left'Length < Right'Length)),
          when Greater =>
            (for some K in 0 .. Length'Min (Left'Length, Right'Length) =>
               Common_Prefix (Left, Right, K)
               and then (if K < Length'Min (Left'Length, Right'Length)
                         then Left (Left'First + K) > Right (Right'First + K)
                         else Left'Length > Right'Length)));

   --  True if the first Count bytes of Left and Right are the same
   function Common_Prefix (Left, Right : Bytes; Count : Length) return Boolean
   is (for all I in 0 .. Count - 1 => Left (Left'First + I) = Right (Right'First + I))
   with Ghost, Pre => Count <= Left'Length and then Count <= Right'Length;

end Kaitai.Byte_Arrays;
