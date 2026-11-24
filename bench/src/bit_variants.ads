--  A hand-written bit field reader to hold the library against.  It keeps
--  the bits left over from the last byte in the stream, as the Kaitai Struct
--  runtime libraries for other languages do, and follows the one for Go.

with Kaitai.Types; use Kaitai.Types;

package Bit_Variants is

   type Stream is record
      Pos       : Length;        --  next byte to read
      Last      : Length;        --  last readable byte
      Bits      : U64 := 0;      --  bits left over, right aligned
      Bits_Left : Natural := 0;  --  how many of them
      Failed    : Boolean := False;
   end record;

   function Open (Data : Bytes) return Stream
   is (Pos => Data'First, Last => Data'Last, Bits => 0, Bits_Left => 0, Failed => False);

   --  Drop the bits left over
   procedure Align (S : in out Stream)
   with Inline;

   procedure Read_Bits_Be (Data : Bytes; S : in out Stream; Count : Positive; Value : out U64)
   with Inline, Pre => Count <= 64;

   procedure Read_Bits_Le (Data : Bytes; S : in out Stream; Count : Positive; Value : out U64)
   with Inline, Pre => Count <= 64;

end Bit_Variants;
