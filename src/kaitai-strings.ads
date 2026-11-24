--  What generated parsers need for strings.  A string is never copied: it is
--  a Slice of the input buffer, and its encoding is known when the parser is
--  generated.  The operations here look at the bytes of such a slice and
--  allocate nothing.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Strings
  with Pure, SPARK_Mode, Always_Terminates
is

   type Encoding is (US_ASCII, UTF_8, UTF_16LE, UTF_16BE, UTF_32LE, UTF_32BE, Single_Byte);
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
   --  UTF_32LE/BE:  a multiple of four bytes, and every unit is at most
   --                U+10FFFF and no surrogate (U+D800 .. U+DFFF).
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
   --  UTF_32LE/BE:         the number of whole units (a quarter of the
   --                       bytes, rounded down); bytes at the end that are
   --                       no whole unit are ignored.
   function Character_Count (Buffer : Bytes; Item : Slice; Enc : Encoding) return Kaitai.Types.Length
   with
     Pre  => Within (Item, Buffer),
     Post =>
       Character_Count'Result <= Size (Item)
       and then (if Enc in US_ASCII | Single_Byte then Character_Count'Result = Size (Item))
       and then (if Enc in UTF_16LE | UTF_16BE then Character_Count'Result <= Size (Item) / 2)
       and then (if Enc in UTF_32LE | UTF_32BE then Character_Count'Result = Size (Item) / 4);

   --  An upper bound of the number of bytes that Item has in UTF-8, which
   --  depends on the size of Item and on Enc only: one byte of UTF-8 per
   --  byte for US_ASCII, UTF_8 and UTF_32LE/BE (a character of four bytes
   --  needs at most four), one and a half for UTF_16LE/BE, two for
   --  Single_Byte.  A buffer that big always suffices for To_UTF_8.  The
   --  result is Length'Last if the bound does not fit into a Length.
   function Max_UTF_8_Size (Item : Slice; Enc : Encoding) return Kaitai.Types.Length
   is (case Enc is
         when US_ASCII | UTF_8 | UTF_32LE | UTF_32BE => Size (Item),
         when UTF_16LE | UTF_16BE                    =>
           (if Size (Item) > Length'Last / 2 then Length'Last else Size (Item) + Size (Item) / 2),
         when Single_Byte                            =>
           (if Size (Item) > Length'Last / 2 then Length'Last else 2 * Size (Item)));

   --  The number of bytes that Item has in UTF-8, as To_UTF_8 writes it.
   --  It is 0 if Item is not valid in Enc, which is also what To_UTF_8
   --  writes then.  The result never exceeds Max_UTF_8_Size.
   function UTF_8_Size (Buffer : Bytes; Item : Slice; Enc : Encoding) return Kaitai.Types.Length
   with
     Pre  => Within (Item, Buffer),
     Post =>
       UTF_8_Size'Result <= Max_UTF_8_Size (Item, Enc)
       and then (if not Is_Valid (Buffer, Item, Enc) then UTF_8_Size'Result = 0);

   --  Write Item as UTF-8 to Target (Target'First .. Last), so that a caller
   --  gets one representation whatever the encoding, and nothing is
   --  allocated.
   --
   --  OK is False, and Last is Target'First - 1, if Item is not valid in Enc
   --  (the caller reports Illegal_Sequence) or if Target is too small; the
   --  contents of Target are then of no use.  On success the bytes of Target
   --  after Last are unchanged.  A Target of at least Max_UTF_8_Size (Item,
   --  Enc) bytes is never too small (proved).  Neither is one of UTF_8_Size
   --  bytes, which the tests check.
   --
   --  Target may be empty; then its Last is Target'First - 1 as usual (the
   --  precondition rules out the odd bounds that an empty array can have).
   --
   --  US_ASCII and UTF_8 are copied, UTF_16 and UTF_32 are converted.  For
   --  Single_Byte the bytes 0 .. 127 are copied and the bytes 128 .. 255 are
   --  taken as ISO-8859-1, that is as the characters U+0080 .. U+00FF.  That
   --  is exact for ISO-8859-1 and wrong for the other single byte encodings
   --  (CP437, windows-1252 and the like) in the positions that they use
   --  differently, because the library has no tables for them.
   procedure To_UTF_8
     (Buffer : Bytes;
      Item   : Slice;
      Enc    : Encoding;
      Target : in out Bytes;
      Last   : out Kaitai.Types.Length;
      OK     : out Boolean)
   with
     Pre  => Within (Item, Buffer) and then Target'First >= 1 and then Target'Last >= Target'First - 1,
     Post =>
       Last in Target'First - 1 .. Target'Last
       and then (if not OK then Last = Target'First - 1)
       and then (if OK then Is_Valid (Buffer, Item, Enc))
       and then (if OK then (for all I in Last + 1 .. Target'Last => Target (I) = Target'Old (I)))
       and then (if OK and then Enc in US_ASCII | UTF_8 then Last + 1 - Target'First = Size (Item))
       and then (if Is_Valid (Buffer, Item, Enc) and then Max_UTF_8_Size (Item, Enc) <= Target'Length then OK);

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
