--  The parsing loops measured by the stream benchmarks, one per stream
--  design.  Each parses fixed 15-byte records (u1, u2le, u4le, u8be) until
--  the data is exhausted and returns a checksum over all fields.
--
--  Each loop is a procedure of its own that gets the stream as a parameter
--  and is not inlined, as a parser generated from a format description
--  would be: it knows neither the bounds of the data nor the state of the
--  stream at compile time.

with Kaitai.Types;    use Kaitai.Types;
with Stream_Variants; use Stream_Variants;

package Stream_Runs is

   function Mix (Sum : U64; A : U8; B : U16; C : U32; D : U64) return U64
   with Inline_Always;

   function Run_Cursor_Sticky (Data : Bytes) return U64
   with No_Inline;
   function Run_Pointer_Sticky (Data : not null Pointer_Sticky.Bytes_View) return U64
   with No_Inline;
   function Run_Cursor_Status (Data : Bytes) return U64
   with No_Inline;
   function Run_Block_Check (Data : Bytes) return U64
   with No_Inline;

   --  The same two loops written against the library: reading field by
   --  field from a Kaitai.Streams.Stream, and with one check per record
   --  followed by Kaitai.Decoding at fixed offsets

   function Run_Kaitai (Data : Bytes) return U64
   with No_Inline;
   function Run_Kaitai_Block (Data : Bytes) return U64
   with No_Inline;

   --  As Run_Kaitai, but the parser copies the stream it is given into a
   --  local variable, works on that and copies it back at the end

   function Run_Kaitai_Local (Data : Bytes) return U64
   with No_Inline;

   --  Bit fields: records of four fields of 3, 13, 4 and 12 bits, read with
   --  the hand-written reader of Bit_Variants and with the library, in both
   --  bit orders

   function Run_Bits_Classic_Be (Data : Bytes) return U64
   with No_Inline;
   function Run_Bits_Classic_Le (Data : Bytes) return U64
   with No_Inline;
   function Run_Kaitai_Bits_Be (Data : Bytes) return U64
   with No_Inline;
   function Run_Kaitai_Bits_Le (Data : Bytes) return U64
   with No_Inline;

end Stream_Runs;
