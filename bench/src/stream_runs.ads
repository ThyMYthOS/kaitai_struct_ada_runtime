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

   --  Library operations against hand-written code that does the same job
   --  directly on the buffer with a plain index.  Each loop calls a parser
   --  for one record, as the generated code of a repeated field would; the
   --  formats are those of Bench_Data.
   --
   --  Zero-terminated strings: two of them and a u2le per record
   function Run_Term_Kaitai_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Term_Classic (Data : Bytes) return U64
   with No_Inline;

   --  A "contents" attribute of four bytes and a u4le per record
   function Run_Contents_Kaitai_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Contents_Classic (Data : Bytes) return U64
   with No_Inline;

   --  A u1 length and a body of that many bytes, which is parsed from a
   --  substream of its own and reads a u2le and a u1
   function Run_Substream_Kaitai_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Substream_Classic (Data : Bytes) return U64
   with No_Inline;

   --  What the local copy of the stream costs in small nested types: a
   --  record of four nested types of a single u1 each.  The parser of the
   --  record and that of the nested type copy the stream, only the first
   --  does, or neither does.
   function Run_Nested_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Nested_Outer_Only (Data : Bytes) return U64
   with No_Inline;
   function Run_Nested_Direct (Data : Bytes) return U64
   with No_Inline;

   --  Where the local copy of the stream starts to pay off: a record of N
   --  fields of u1, read by one parser that is called once per record,
   --  either on a local copy of the stream or through the parameter
   function Run_Fields1_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields1_Direct (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields2_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields2_Direct (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields3_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields3_Direct (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields4_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields4_Direct (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields8_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Fields8_Direct (Data : Bytes) return U64
   with No_Inline;

   --  A parser that reads no field itself but calls a nested parser four
   --  times; the nested parser reads two u1.  Both copy the stream, only the
   --  nested one does, or neither does.
   function Run_Calls_Both_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Calls_Inner_Local (Data : Bytes) return U64
   with No_Inline;
   function Run_Calls_Direct (Data : Bytes) return U64
   with No_Inline;

   --  Records of 64 bytes, each processed as a whole into a target array of
   --  64 bytes that lives in the package, by the library and by a plain
   --  loop; the checksum covers four bytes of the target
   function Run_Xor_One_Kaitai (Data : Bytes) return U64
   with No_Inline;
   function Run_Xor_One_Classic (Data : Bytes) return U64
   with No_Inline;
   function Run_Xor_Many_Kaitai (Data : Bytes) return U64
   with No_Inline;
   function Run_Xor_Many_Classic_Mod (Data : Bytes) return U64
   with No_Inline;
   function Run_Xor_Many_Classic_Counter (Data : Bytes) return U64
   with No_Inline;
   function Run_Rotate_Kaitai (Data : Bytes) return U64
   with No_Inline;
   function Run_Rotate_Classic (Data : Bytes) return U64
   with No_Inline;

   --  The variants of the library that read through the stream parameter,
   --  as generated code does, are Run_Term_Kaitai, Run_Contents_Kaitai and
   --  Run_Substream_Kaitai; those above with the suffix _Local copy the
   --  stream into a local variable instead
   function Run_Term_Kaitai (Data : Bytes) return U64
   with No_Inline;
   function Run_Contents_Kaitai (Data : Bytes) return U64
   with No_Inline;
   function Run_Substream_Kaitai (Data : Bytes) return U64
   with No_Inline;

   --  The cost of a returned status against a sticky one when a parser is
   --  called once per record: N fields of u1 read with the stream designs
   --  of Stream_Variants, to be compared with the Run_Fields<N>_Direct above
   function Run_Status1_Sticky (Data : Bytes) return U64
   with No_Inline;
   function Run_Status1_Returned (Data : Bytes) return U64
   with No_Inline;
   function Run_Status4_Sticky (Data : Bytes) return U64
   with No_Inline;
   function Run_Status4_Returned (Data : Bytes) return U64
   with No_Inline;
   function Run_Status8_Sticky (Data : Bytes) return U64
   with No_Inline;
   function Run_Status8_Returned (Data : Bytes) return U64
   with No_Inline;

end Stream_Runs;
