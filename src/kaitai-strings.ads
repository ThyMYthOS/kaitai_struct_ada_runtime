--  What generated parsers need for strings.  A string is never copied: it is
--  a Slice of the input buffer, and its encoding is known when the parser is
--  generated.  The operations here look at the bytes of such a slice and
--  allocate nothing.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Strings
  with Pure, SPARK_Mode, Always_Terminates
is

   type Encoding is (US_ASCII, UTF_8, UTF_16LE, UTF_16BE, Single_Byte);
   --  Single_Byte stands for every encoding in which each byte is one
   --  character and every byte is accepted: ISO-8859-x, CP437, windows-125x
   --  and the like.

   --  True if the bytes of Item are well formed in Enc.
   --
   --  US_ASCII:     all bytes are below 128.
   --  UTF_8:        well formed as Table 3-7 of the Unicode Standard says: no
   --                overlong forms, no surrogates (U+D800 .. U+DFFF), nothing
   --                above U+10FFFF and no sequence that is cut off.
   --  UTF_16LE/BE:  an even number of bytes, every high surrogate is
   --                followed by a low surrogate and no low surrogate stands
   --                alone.
   --  Single_Byte:  always.
   function Is_Valid (Buffer : Bytes; Item : Slice; Enc : Encoding) return Boolean
   with
     Pre  => Within (Item, Buffer),
     Post =>
       (if Is_Empty (Item) or else Enc = Single_Byte then Is_Valid'Result)
       and then (if Enc = US_ASCII then Is_Valid'Result = (for all I in Item.First .. Item.Last => Buffer (I) < 128));

   --  The number of characters (code points) of Item: what `.length` of the
   --  expression language is.  A surrogate pair of UTF-16 counts as one.
   --  The function is total and counts malformed input as follows, so that
   --  the result for well formed input is the number of characters and
   --  Character_Count never exceeds the number of bytes:
   --
   --  US_ASCII, Single_Byte:  the number of bytes.
   --  UTF_8:               the number of bytes that are not continuation
   --                       bytes (10xxxxxx).
   --  UTF_16LE/BE:         the number of code units that are not low
   --                       surrogates; a last byte that is no whole unit is
   --                       ignored.
   function Character_Count (Buffer : Bytes; Item : Slice; Enc : Encoding) return Kaitai.Types.Length
   with
     Pre  => Within (Item, Buffer),
     Post =>
       Character_Count'Result <= Size (Item)
       and then (if Enc in US_ASCII | Single_Byte then Character_Count'Result = Size (Item))
       and then (if Enc in UTF_16LE | UTF_16BE then Character_Count'Result <= Size (Item) / 2);

   --  True if Item is a number in the sense of `.to_i (Base)` of the
   --  expression language, for a string in an encoding that includes ASCII:
   --  an optional sign ('-' or '+'), then at least one digit of Base and
   --  nothing else.  Base is in 2 .. 36, the letters a .. z and A .. Z count
   --  as 10 .. 35, and the value fits into S64, S64'First included.
   function To_Integer_OK (Buffer : Bytes; Item : Slice; Base : S64) return Boolean
   with
     Pre  => Within (Item, Buffer),
     Post => (if Is_Empty (Item) or else Base not in 2 .. 36 then not To_Integer_OK'Result);

   --  The number that Item stands for
   function To_Integer (Buffer : Bytes; Item : Slice; Base : S64) return S64
   with Pre => Within (Item, Buffer) and then To_Integer_OK (Buffer, Item, Base);

   --  `.to_s` of an integer: the decimal digits of Value, with a '-' in
   --  front if it is negative, are written to Target (Target'First .. Last).
   --  20 bytes always suffice.  The other bytes of Target are not changed.
   procedure Put_Integer (Value : S64; Target : in out Bytes; Last : out Kaitai.Types.Length)
   with
     Pre  => Target'Length >= 20,
     Post =>
       Last in Target'First .. Target'First + 19
       and then (if Value < 0 then Target (Target'First) = 45)
       and then (for all I in Target'First + (if Value < 0 then 1 else 0) .. Last => Target (I) in 48 .. 57)
       and then Last >= Target'First + (if Value < 0 then 1 else 0)
       and then (for all I in Last + 1 .. Target'Last => Target (I) = Target'Old (I))
       and then (if Value = 0 then Last = Target'First and then Target (Target'First) = 48);

   --  True if the bytes of Item are exactly the characters of Literal, each
   --  Character taken as one byte.  This compares a parsed string with a
   --  literal of the description without making a byte array of it.
   function Equal_Literal (Buffer : Bytes; Item : Slice; Literal : String) return Boolean
   with
     Pre  => Within (Item, Buffer),
     Post =>
       Equal_Literal'Result
       = (Size (Item) = Kaitai.Types.Length (Literal'Length)
          and then (for all I in Item.First .. Item.Last =>
                      Buffer (I) = Byte (Character'Pos (Literal (Literal'First + Integer (I - Item.First))))));

end Kaitai.Strings;
