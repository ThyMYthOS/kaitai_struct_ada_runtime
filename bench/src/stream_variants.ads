--  Alternative designs for the byte stream, reduced to what is needed to
--  compare their cost: reading u1, u2le, u4le and u8be with end-of-stream
--  detection.
--
--    Cursor_Sticky  : stream is a cursor record, the buffer is passed to
--                     every read, a failed read sets a sticky flag
--    Pointer_Sticky : stream holds a pointer to the buffer, sticky flag
--    Cursor_Status  : as Cursor_Sticky, but every read reports success
--                     through an out parameter that the caller checks
--    Cursor_Raise   : as Cursor_Sticky, but a failed read raises
--    Decoding       : no stream; the caller checks the size of a whole
--                     block once and then decodes at fixed offsets

with Kaitai.Types; use Kaitai.Types;

package Stream_Variants is

   package Cursor_Sticky is

      type Stream is record
         Pos    : Length;   --  next byte to read
         Last   : Length;   --  last readable byte
         Failed : Boolean := False;
      end record;

      function Open (Data : Bytes) return Stream
      is (Pos => Data'First, Last => Data'Last, Failed => False);

      procedure Read_U1 (Data : Bytes; S : in out Stream; V : out U8)
      with Inline;
      procedure Read_U2le (Data : Bytes; S : in out Stream; V : out U16)
      with Inline;
      procedure Read_U4le (Data : Bytes; S : in out Stream; V : out U32)
      with Inline;
      procedure Read_U8be (Data : Bytes; S : in out Stream; V : out U64)
      with Inline;

   end Cursor_Sticky;

   package Pointer_Sticky is

      type Bytes_View is access constant Bytes;

      type Stream is record
         Data   : Bytes_View;
         Pos    : Length;
         Last   : Length;
         Failed : Boolean := False;
      end record;

      procedure Read_U1 (S : in out Stream; V : out U8)
      with Inline;
      procedure Read_U2le (S : in out Stream; V : out U16)
      with Inline;
      procedure Read_U4le (S : in out Stream; V : out U32)
      with Inline;
      procedure Read_U8be (S : in out Stream; V : out U64)
      with Inline;

   end Pointer_Sticky;

   package Cursor_Status is

      type Stream is record
         Pos  : Length;
         Last : Length;
      end record;

      function Open (Data : Bytes) return Stream
      is (Pos => Data'First, Last => Data'Last);

      procedure Read_U1 (Data : Bytes; S : in out Stream; V : out U8; OK : out Boolean)
      with Inline;
      procedure Read_U2le (Data : Bytes; S : in out Stream; V : out U16; OK : out Boolean)
      with Inline;
      procedure Read_U4le (Data : Bytes; S : in out Stream; V : out U32; OK : out Boolean)
      with Inline;
      procedure Read_U8be (Data : Bytes; S : in out Stream; V : out U64; OK : out Boolean)
      with Inline;

   end Cursor_Status;

   package Cursor_Raise is

      End_Of_Stream : exception;

      type Stream is record
         Pos  : Length;
         Last : Length;
      end record;

      function Open (Data : Bytes) return Stream
      is (Pos => Data'First, Last => Data'Last);

      procedure Read_U1 (Data : Bytes; S : in out Stream; V : out U8)
      with Inline;
      procedure Read_U2le (Data : Bytes; S : in out Stream; V : out U16)
      with Inline;
      procedure Read_U4le (Data : Bytes; S : in out Stream; V : out U32)
      with Inline;
      procedure Read_U8be (Data : Bytes; S : in out Stream; V : out U64)
      with Inline;

   end Cursor_Raise;

   package Decoding is

      function U16_LE (Data : Bytes; From : Length) return U16
      with Inline, Pre => From >= Data'First and then From + 1 <= Data'Last;
      function U32_LE (Data : Bytes; From : Length) return U32
      with Inline, Pre => From >= Data'First and then From + 3 <= Data'Last;
      function U64_BE (Data : Bytes; From : Length) return U64
      with Inline, Pre => From >= Data'First and then From + 7 <= Data'Last;

   end Decoding;

end Stream_Variants;
