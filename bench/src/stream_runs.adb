with Bench_Data;
with Bit_Variants;
with Kaitai.Decoding;
with Kaitai.Processing;
with Kaitai.Streams;

package body Stream_Runs is

   function Mix (Sum : U64; A : U8; B : U16; C : U32; D : U64) return U64
   is (Sum * 31 + U64 (A) + U64 (B) + U64 (C) + D);

   procedure Parse_Cursor_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Cursor_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Sum : in out U64) is
      use Cursor_Sticky;
      A : U8;
      B : U16;
      C : U32;
      D : U64;
   begin
      loop
         Read_U1 (Data, S, A);
         Read_U2le (Data, S, B);
         Read_U4le (Data, S, C);
         Read_U8be (Data, S, D);
         exit when S.Failed;
         Sum := Mix (Sum, A, B, C, D);
      end loop;
   end Parse_Cursor_Sticky;

   function Run_Cursor_Sticky (Data : Bytes) return U64 is
      S   : Cursor_Sticky.Stream := Cursor_Sticky.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Cursor_Sticky (Data, S, Sum);
      return Sum;
   end Run_Cursor_Sticky;

   procedure Parse_Pointer_Sticky (S : in out Pointer_Sticky.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Pointer_Sticky (S : in out Pointer_Sticky.Stream; Sum : in out U64) is
      use Pointer_Sticky;
      A : U8;
      B : U16;
      C : U32;
      D : U64;
   begin
      loop
         Read_U1 (S, A);
         Read_U2le (S, B);
         Read_U4le (S, C);
         Read_U8be (S, D);
         exit when S.Failed;
         Sum := Mix (Sum, A, B, C, D);
      end loop;
   end Parse_Pointer_Sticky;

   function Run_Pointer_Sticky (Data : not null Pointer_Sticky.Bytes_View) return U64 is
      S   : Pointer_Sticky.Stream := (Data => Data, Pos => Data'First, Last => Data'Last, Failed => False);
      Sum : U64 := 0;
   begin
      Parse_Pointer_Sticky (S, Sum);
      return Sum;
   end Run_Pointer_Sticky;

   procedure Parse_Cursor_Status (Data : Bytes; S : in out Cursor_Status.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Cursor_Status (Data : Bytes; S : in out Cursor_Status.Stream; Sum : in out U64) is
      use Cursor_Status;
      A  : U8;
      B  : U16;
      C  : U32;
      D  : U64;
      OK : Boolean;
   begin
      loop
         Read_U1 (Data, S, A, OK);
         exit when not OK;
         Read_U2le (Data, S, B, OK);
         exit when not OK;
         Read_U4le (Data, S, C, OK);
         exit when not OK;
         Read_U8be (Data, S, D, OK);
         exit when not OK;
         Sum := Mix (Sum, A, B, C, D);
      end loop;
   end Parse_Cursor_Status;

   function Run_Cursor_Status (Data : Bytes) return U64 is
      S   : Cursor_Status.Stream := Cursor_Status.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Cursor_Status (Data, S, Sum);
      return Sum;
   end Run_Cursor_Status;

   procedure Parse_Block_Check (Data : Bytes; Pos : in out Length; Sum : in out U64)
   with No_Inline;

   procedure Parse_Block_Check (Data : Bytes; Pos : in out Length; Sum : in out U64) is
      use Decoding;
   begin
      while Data'Last - Pos >= 14 loop
         Sum := Mix (Sum, Data (Pos), U16_LE (Data, Pos + 1), U32_LE (Data, Pos + 3), U64_BE (Data, Pos + 7));
         Pos := Pos + 15;
      end loop;
   end Parse_Block_Check;

   function Run_Block_Check (Data : Bytes) return U64 is
      Pos : Length := Data'First;
      Sum : U64 := 0;
   begin
      Parse_Block_Check (Data, Pos, Sum);
      return Sum;
   end Run_Block_Check;

   procedure Parse_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64) is
      use Kaitai.Streams;
      A : U8;
      B : U16;
      C : U32;
      D : U64;
   begin
      loop
         Read_U1 (Data, S, A);
         Read_U2le (Data, S, B);
         Read_U4le (Data, S, C);
         Read_U8be (Data, S, D);
         exit when not OK (S);
         Sum := Mix (Sum, A, B, C, D);
      end loop;
   end Parse_Kaitai;

   function Run_Kaitai (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Kaitai (Data, S, Sum);
      return Sum;
   end Run_Kaitai;

   procedure Parse_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64) is
      use Kaitai.Streams;
      L : Stream := S;
      A : U8;
      B : U16;
      C : U32;
      D : U64;
   begin
      loop
         Read_U1 (Data, L, A);
         Read_U2le (Data, L, B);
         Read_U4le (Data, L, C);
         Read_U8be (Data, L, D);
         exit when not OK (L);
         Sum := Mix (Sum, A, B, C, D);
      end loop;
      S := L;
   end Parse_Kaitai_Local;

   function Run_Kaitai_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Kaitai_Local (Data, S, Sum);
      return Sum;
   end Run_Kaitai_Local;

   procedure Parse_Kaitai_Block (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Kaitai_Block (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64) is
      use Kaitai.Decoding;
      use Kaitai.Streams;
      From : Length;
   begin
      while Remaining (S) >= 15 loop
         From := Next_Index (S);
         Sum :=
           Mix (Sum, U8_At (Data, From), U16_LE (Data, From + 1), U32_LE (Data, From + 3), U64_BE (Data, From + 7));
         Advance (S, 15);
      end loop;
   end Parse_Kaitai_Block;

   function Run_Kaitai_Block (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Kaitai_Block (Data, S, Sum);
      return Sum;
   end Run_Kaitai_Block;

   procedure Parse_Bits_Classic_Be (Data : Bytes; S : in out Bit_Variants.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Bits_Classic_Be (Data : Bytes; S : in out Bit_Variants.Stream; Sum : in out U64) is
      use Bit_Variants;
      A : U64;
      B : U64;
      C : U64;
      D : U64;
   begin
      loop
         --  A record starts at a byte boundary; generated code states that
         Align (S);
         Read_Bits_Be (Data, S, 3, A);
         Read_Bits_Be (Data, S, 13, B);
         Read_Bits_Be (Data, S, 4, C);
         Read_Bits_Be (Data, S, 12, D);
         exit when S.Failed;
         Sum := Sum * 31 + A + B + C + D;
      end loop;
   end Parse_Bits_Classic_Be;

   function Run_Bits_Classic_Be (Data : Bytes) return U64 is
      S   : Bit_Variants.Stream := Bit_Variants.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Bits_Classic_Be (Data, S, Sum);
      return Sum;
   end Run_Bits_Classic_Be;

   procedure Parse_Bits_Classic_Le (Data : Bytes; S : in out Bit_Variants.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Bits_Classic_Le (Data : Bytes; S : in out Bit_Variants.Stream; Sum : in out U64) is
      use Bit_Variants;
      A : U64;
      B : U64;
      C : U64;
      D : U64;
   begin
      loop
         --  A record starts at a byte boundary; generated code states that
         Align (S);
         Read_Bits_Le (Data, S, 3, A);
         Read_Bits_Le (Data, S, 13, B);
         Read_Bits_Le (Data, S, 4, C);
         Read_Bits_Le (Data, S, 12, D);
         exit when S.Failed;
         Sum := Sum * 31 + A + B + C + D;
      end loop;
   end Parse_Bits_Classic_Le;

   function Run_Bits_Classic_Le (Data : Bytes) return U64 is
      S   : Bit_Variants.Stream := Bit_Variants.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Bits_Classic_Le (Data, S, Sum);
      return Sum;
   end Run_Bits_Classic_Le;

   procedure Parse_Kaitai_Bits_Be (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Kaitai_Bits_Be (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64) is
      use Kaitai.Streams;
      A : U64;
      B : U64;
      C : U64;
      D : U64;
   begin
      loop
         --  A record starts at a byte boundary; generated code states that
         Align_To_Byte (S);
         Read_Bits_Int_Be (Data, S, 3, A);
         Read_Bits_Int_Be (Data, S, 13, B);
         Read_Bits_Int_Be (Data, S, 4, C);
         Read_Bits_Int_Be (Data, S, 12, D);
         exit when not OK (S);
         Sum := Sum * 31 + A + B + C + D;
      end loop;
   end Parse_Kaitai_Bits_Be;

   function Run_Kaitai_Bits_Be (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Kaitai_Bits_Be (Data, S, Sum);
      return Sum;
   end Run_Kaitai_Bits_Be;

   procedure Parse_Kaitai_Bits_Le (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64)
   with No_Inline;

   procedure Parse_Kaitai_Bits_Le (Data : Bytes; S : in out Kaitai.Streams.Stream; Sum : in out U64) is
      use Kaitai.Streams;
      A : U64;
      B : U64;
      C : U64;
      D : U64;
   begin
      loop
         --  A record starts at a byte boundary; generated code states that
         Align_To_Byte (S);
         Read_Bits_Int_Le (Data, S, 3, A);
         Read_Bits_Int_Le (Data, S, 13, B);
         Read_Bits_Int_Le (Data, S, 4, C);
         Read_Bits_Int_Le (Data, S, 12, D);
         exit when not OK (S);
         Sum := Sum * 31 + A + B + C + D;
      end loop;
   end Parse_Kaitai_Bits_Le;

   function Run_Kaitai_Bits_Le (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Sum : U64 := 0;
   begin
      Parse_Kaitai_Bits_Le (Data, S, Sum);
      return Sum;
   end Run_Kaitai_Bits_Le;

   ---------------------------------------------------------------------
   --  Zero-terminated strings
   ---------------------------------------------------------------------

   type Term_Record is record
      S1 : Slice;
      S2 : Slice;
      N  : U16 := 0;
   end record;

   function Term_Mix (Sum : U64; This : Term_Record) return U64
   is (Sum * 31 + U64 (Size (This.S1)) + U64 (Size (This.S2)) + U64 (This.N))
   with Inline_Always;

   procedure Parse_Term_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Term_Record)
   with No_Inline;

   procedure Parse_Term_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Term_Record) is
      use Kaitai.Streams;
      L : Stream := S;
   begin
      Read_Bytes_Term (Data, L, 0, Include => False, Consume => True, EOS_Error => True, Data => This.S1);
      Read_Bytes_Term (Data, L, 0, Include => False, Consume => True, EOS_Error => True, Data => This.S2);
      Read_U2le (Data, L, This.N);
      S := L;
   end Parse_Term_Kaitai_Local;

   function Run_Term_Kaitai_Local (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Term_Record;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Term_Kaitai_Local (Data, S, This);
         exit when not Kaitai.Streams.OK (S);
         Sum := Term_Mix (Sum, This);
      end loop;
      return Sum;
   end Run_Term_Kaitai_Local;

   procedure Parse_Term_Classic (Data : Bytes; Pos : in out Length; This : out Term_Record; OK : out Boolean)
   with No_Inline;

   procedure Parse_Term_Classic (Data : Bytes; Pos : in out Length; This : out Term_Record; OK : out Boolean) is
      use Decoding;
      I     : Length := Pos;
      Start : Length;
   begin
      Start := I;
      while I <= Data'Last and then Data (I) /= 0 loop
         I := I + 1;
      end loop;
      if I > Data'Last then
         OK := False;
         return;
      end if;
      This.S1 := (First => Start, Last => I - 1);
      I := I + 1;

      Start := I;
      while I <= Data'Last and then Data (I) /= 0 loop
         I := I + 1;
      end loop;
      if I > Data'Last then
         OK := False;
         return;
      end if;
      This.S2 := (First => Start, Last => I - 1);
      I := I + 1;

      if Data'Last - I < 1 then
         OK := False;
         return;
      end if;
      This.N := U16_LE (Data, I);
      Pos := I + 2;
      OK := True;
   end Parse_Term_Classic;

   function Run_Term_Classic (Data : Bytes) return U64 is
      Pos  : Length := Data'First;
      This : Term_Record;
      OK   : Boolean;
      Sum  : U64 := 0;
   begin
      while Pos <= Data'Last loop
         Parse_Term_Classic (Data, Pos, This, OK);
         exit when not OK;
         Sum := Term_Mix (Sum, This);
      end loop;
      return Sum;
   end Run_Term_Classic;

   ---------------------------------------------------------------------
   --  Contents
   ---------------------------------------------------------------------

   procedure Parse_Contents_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U32)
   with No_Inline;

   procedure Parse_Contents_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U32) is
      use Kaitai.Streams;
      L : Stream := S;
   begin
      Read_Contents (Data, L, Bench_Data.Magic);
      Read_U4le (Data, L, Value);
      S := L;
   end Parse_Contents_Kaitai_Local;

   function Run_Contents_Kaitai_Local (Data : Bytes) return U64 is
      S     : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Value : U32;
      Sum   : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Contents_Kaitai_Local (Data, S, Value);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + U64 (Value);
      end loop;
      return Sum;
   end Run_Contents_Kaitai_Local;

   procedure Parse_Contents_Classic (Data : Bytes; Pos : in out Length; Value : out U32; OK : out Boolean)
   with No_Inline;

   procedure Parse_Contents_Classic (Data : Bytes; Pos : in out Length; Value : out U32; OK : out Boolean) is
      use Decoding;
      I : constant Length := Pos;
   begin
      Value := 0;
      if Data'Last - I < 7 then
         OK := False;
         return;
      end if;
      for K in Length range 0 .. 3 loop
         if Data (I + K) /= Bench_Data.Magic (Bench_Data.Magic'First + K) then
            OK := False;
            return;
         end if;
      end loop;
      Value := U32_LE (Data, I + 4);
      Pos := I + 8;
      OK := True;
   end Parse_Contents_Classic;

   function Run_Contents_Classic (Data : Bytes) return U64 is
      Pos   : Length := Data'First;
      Value : U32;
      OK    : Boolean;
      Sum   : U64 := 0;
   begin
      while Pos <= Data'Last loop
         Parse_Contents_Classic (Data, Pos, Value, OK);
         exit when not OK;
         Sum := Sum * 31 + U64 (Value);
      end loop;
      return Sum;
   end Run_Contents_Classic;

   ---------------------------------------------------------------------
   --  Substreams
   ---------------------------------------------------------------------

   procedure Parse_Body_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8)
   with No_Inline;

   procedure Parse_Body_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8) is
      use Kaitai.Streams;
      L : Stream := S;
   begin
      Read_U2le (Data, L, A);
      Read_U1 (Data, L, B);
      S := L;
   end Parse_Body_Kaitai_Local;

   procedure Parse_Substream_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8)
   with No_Inline;

   procedure Parse_Substream_Kaitai_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8) is
      use Kaitai.Streams;
      L   : Stream := S;
      N   : U8;
      Sub : Stream;
   begin
      Read_U1 (Data, L, N);
      Substream (Data, L, Length (N), Sub);
      Parse_Body_Kaitai_Local (Data, Sub, A, B);
      Join (L, Sub);
      S := L;
   end Parse_Substream_Kaitai_Local;

   function Run_Substream_Kaitai_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      A   : U16;
      B   : U8;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Substream_Kaitai_Local (Data, S, A, B);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + U64 (A) + U64 (B);
      end loop;
      return Sum;
   end Run_Substream_Kaitai_Local;

   --  The body occupies First .. Last of Data and is not read beyond
   procedure Parse_Body_Classic (Data : Bytes; First, Last : Length; A : out U16; B : out U8; OK : out Boolean)
   with No_Inline;

   procedure Parse_Body_Classic (Data : Bytes; First, Last : Length; A : out U16; B : out U8; OK : out Boolean) is
      use Decoding;
   begin
      if Last - First < 2 then
         A := 0;
         B := 0;
         OK := False;
         return;
      end if;
      A := U16_LE (Data, First);
      B := Data (First + 2);
      OK := True;
   end Parse_Body_Classic;

   procedure Parse_Substream_Classic (Data : Bytes; Pos : in out Length; A : out U16; B : out U8; OK : out Boolean)
   with No_Inline;

   procedure Parse_Substream_Classic (Data : Bytes; Pos : in out Length; A : out U16; B : out U8; OK : out Boolean) is
      I : Length := Pos;
      N : Length;
   begin
      N := Length (Data (I));
      I := I + 1;
      if Data'Last - I + 1 < N then
         A := 0;
         B := 0;
         OK := False;
         return;
      end if;
      Parse_Body_Classic (Data, I, I + N - 1, A, B, OK);
      if OK then
         Pos := I + N;
      end if;
   end Parse_Substream_Classic;

   function Run_Substream_Classic (Data : Bytes) return U64 is
      Pos : Length := Data'First;
      A   : U16;
      B   : U8;
      OK  : Boolean;
      Sum : U64 := 0;
   begin
      while Pos <= Data'Last loop
         Parse_Substream_Classic (Data, Pos, A, B, OK);
         exit when not OK;
         Sum := Sum * 31 + U64 (A) + U64 (B);
      end loop;
      return Sum;
   end Run_Substream_Classic;

   ---------------------------------------------------------------------
   --  Nested types
   ---------------------------------------------------------------------

   type Quad is record
      A : U8;
      B : U8;
      C : U8;
      D : U8;
   end record;

   function Quad_Mix (Sum : U64; This : Quad) return U64
   is (Sum * 31 + U64 (This.A) + U64 (This.B) + U64 (This.C) + U64 (This.D))
   with Inline_Always;

   --  The nested type: a single u1
   procedure Parse_Inner_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U8)
   with No_Inline;

   procedure Parse_Inner_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U8) is
      use Kaitai.Streams;
      L : Stream := S;
   begin
      Read_U1 (Data, L, Value);
      S := L;
   end Parse_Inner_Local;

   procedure Parse_Inner_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U8)
   with No_Inline;

   procedure Parse_Inner_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U8) is
   begin
      Kaitai.Streams.Read_U1 (Data, S, Value);
   end Parse_Inner_Direct;

   --  The record: four nested types.  Parse_Outer_Local and
   --  Parse_Outer_Only copy the stream, Parse_Outer_Direct does not; the
   --  first calls the nested parser that copies, the other two the one that
   --  does not.
   procedure Parse_Outer_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Quad)
   with No_Inline;

   procedure Parse_Outer_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Quad) is
      use Kaitai.Streams;
      L : Stream := S;
   begin
      Parse_Inner_Local (Data, L, This.A);
      Parse_Inner_Local (Data, L, This.B);
      Parse_Inner_Local (Data, L, This.C);
      Parse_Inner_Local (Data, L, This.D);
      S := L;
   end Parse_Outer_Local;

   procedure Parse_Outer_Only (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Quad)
   with No_Inline;

   procedure Parse_Outer_Only (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Quad) is
      use Kaitai.Streams;
      L : Stream := S;
   begin
      Parse_Inner_Direct (Data, L, This.A);
      Parse_Inner_Direct (Data, L, This.B);
      Parse_Inner_Direct (Data, L, This.C);
      Parse_Inner_Direct (Data, L, This.D);
      S := L;
   end Parse_Outer_Only;

   procedure Parse_Outer_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Quad)
   with No_Inline;

   procedure Parse_Outer_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Quad) is
   begin
      Parse_Inner_Direct (Data, S, This.A);
      Parse_Inner_Direct (Data, S, This.B);
      Parse_Inner_Direct (Data, S, This.C);
      Parse_Inner_Direct (Data, S, This.D);
   end Parse_Outer_Direct;

   function Run_Nested_Local (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Quad;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Outer_Local (Data, S, This);
         exit when not Kaitai.Streams.OK (S);
         Sum := Quad_Mix (Sum, This);
      end loop;
      return Sum;
   end Run_Nested_Local;

   function Run_Nested_Outer_Only (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Quad;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Outer_Only (Data, S, This);
         exit when not Kaitai.Streams.OK (S);
         Sum := Quad_Mix (Sum, This);
      end loop;
      return Sum;
   end Run_Nested_Outer_Only;

   function Run_Nested_Direct (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Quad;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Outer_Direct (Data, S, This);
         exit when not Kaitai.Streams.OK (S);
         Sum := Quad_Mix (Sum, This);
      end loop;
      return Sum;
   end Run_Nested_Direct;

   ---------------------------------------------------------------------
   --  Local copy against direct access, by number of fields
   ---------------------------------------------------------------------

   procedure Parse_Fields1_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields1_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      L : Stream := S;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, L, V);
      A := U64 (V);
      Acc := A;
      S := L;
   end Parse_Fields1_Local;

   function Run_Fields1_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields1_Local (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields1_Local;

   procedure Parse_Fields1_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields1_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Acc := A;
   end Parse_Fields1_Direct;

   function Run_Fields1_Direct (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields1_Direct (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields1_Direct;

   procedure Parse_Fields2_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields2_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      L : Stream := S;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, L, V);
      A := U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Acc := A;
      S := L;
   end Parse_Fields2_Local;

   function Run_Fields2_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields2_Local (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields2_Local;

   procedure Parse_Fields2_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields2_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Fields2_Direct;

   function Run_Fields2_Direct (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields2_Direct (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields2_Direct;

   procedure Parse_Fields3_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields3_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      L : Stream := S;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, L, V);
      A := U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Acc := A;
      S := L;
   end Parse_Fields3_Local;

   function Run_Fields3_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields3_Local (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields3_Local;

   procedure Parse_Fields3_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields3_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Fields3_Direct;

   function Run_Fields3_Direct (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields3_Direct (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields3_Direct;

   procedure Parse_Fields4_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields4_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      L : Stream := S;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, L, V);
      A := U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Acc := A;
      S := L;
   end Parse_Fields4_Local;

   function Run_Fields4_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields4_Local (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields4_Local;

   procedure Parse_Fields4_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields4_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Fields4_Direct;

   function Run_Fields4_Direct (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields4_Direct (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields4_Direct;

   procedure Parse_Fields8_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields8_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      L : Stream := S;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, L, V);
      A := U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, L, V);
      A := A * 31 + U64 (V);
      Acc := A;
      S := L;
   end Parse_Fields8_Local;

   function Run_Fields8_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields8_Local (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields8_Local;

   procedure Parse_Fields8_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Fields8_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Fields8_Direct;

   function Run_Fields8_Direct (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Fields8_Direct (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Fields8_Direct;

   ---------------------------------------------------------------------
   --  Calls of nested parsers
   ---------------------------------------------------------------------

   --  The nested type: two u1
   procedure Parse_Pair_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U8; B : out U8)
   with No_Inline;

   procedure Parse_Pair_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U8; B : out U8) is
      use Kaitai.Streams;
      L : Stream := S;
   begin
      Read_U1 (Data, L, A);
      Read_U1 (Data, L, B);
      S := L;
   end Parse_Pair_Local;

   procedure Parse_Pair_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U8; B : out U8)
   with No_Inline;

   procedure Parse_Pair_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U8; B : out U8) is
      use Kaitai.Streams;
   begin
      Read_U1 (Data, S, A);
      Read_U1 (Data, S, B);
   end Parse_Pair_Direct;

   procedure Parse_Calls_Both_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Calls_Both_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      use Kaitai.Streams;
      L : Stream := S;
      A : U8;
      B : U8;
   begin
      Parse_Pair_Local (Data, L, A, B);
      Acc := U64 (A) * 31 + U64 (B);
      Parse_Pair_Local (Data, L, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
      Parse_Pair_Local (Data, L, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
      Parse_Pair_Local (Data, L, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
      S := L;
   end Parse_Calls_Both_Local;

   procedure Parse_Calls_Inner_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Calls_Inner_Local (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      A : U8;
      B : U8;
   begin
      Parse_Pair_Local (Data, S, A, B);
      Acc := U64 (A) * 31 + U64 (B);
      Parse_Pair_Local (Data, S, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
      Parse_Pair_Local (Data, S, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
      Parse_Pair_Local (Data, S, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
   end Parse_Calls_Inner_Local;

   procedure Parse_Calls_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Calls_Direct (Data : Bytes; S : in out Kaitai.Streams.Stream; Acc : out U64) is
      A : U8;
      B : U8;
   begin
      Parse_Pair_Direct (Data, S, A, B);
      Acc := U64 (A) * 31 + U64 (B);
      Parse_Pair_Direct (Data, S, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
      Parse_Pair_Direct (Data, S, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
      Parse_Pair_Direct (Data, S, A, B);
      Acc := Acc * 31 + U64 (A) * 31 + U64 (B);
   end Parse_Calls_Direct;

   function Run_Calls_Both_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Calls_Both_Local (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Calls_Both_Local;

   function Run_Calls_Inner_Local (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Calls_Inner_Local (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Calls_Inner_Local;

   function Run_Calls_Direct (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Calls_Direct (Data, S, Acc);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Calls_Direct;

   ---------------------------------------------------------------------
   --  Processing
   ---------------------------------------------------------------------

   Process_Size : constant := Bench_Data.Process_Record_Size;

   --  Where every record is processed to
   Process_Target : Bytes (1 .. Process_Size) := [others => 0];

   function Process_Mix (Sum : U64) return U64
   is (Sum
       * 31
       + U64 (Process_Target (1))
       + U64 (Process_Target (22))
       + U64 (Process_Target (43))
       + U64 (Process_Target (Process_Size)))
   with Inline_Always;

   procedure Parse_Xor_One_Kaitai (Data : Bytes; First : Length; Target : in out Bytes)
   with No_Inline;

   procedure Parse_Xor_One_Kaitai (Data : Bytes; First : Length; Target : in out Bytes) is
   begin
      Kaitai.Processing.Xor_One (Data (First .. First + Process_Size - 1), 16#5A#, Target);
   end Parse_Xor_One_Kaitai;

   procedure Parse_Xor_One_Classic (Data : Bytes; First : Length; Target : in out Bytes)
   with No_Inline;

   procedure Parse_Xor_One_Classic (Data : Bytes; First : Length; Target : in out Bytes) is
   begin
      for I in Length range 0 .. Process_Size - 1 loop
         Target (Target'First + I) := Data (First + I) xor 16#5A#;
      end loop;
   end Parse_Xor_One_Classic;

   procedure Parse_Xor_Many_Kaitai (Data : Bytes; First : Length; Target : in out Bytes)
   with No_Inline;

   procedure Parse_Xor_Many_Kaitai (Data : Bytes; First : Length; Target : in out Bytes) is
   begin
      Kaitai.Processing.Xor_Many (Data (First .. First + Process_Size - 1), Bench_Data.Xor_Key, Target);
   end Parse_Xor_Many_Kaitai;

   procedure Parse_Xor_Many_Classic_Mod (Data : Bytes; First : Length; Target : in out Bytes)
   with No_Inline;

   procedure Parse_Xor_Many_Classic_Mod (Data : Bytes; First : Length; Target : in out Bytes) is
      Key : Bytes renames Bench_Data.Xor_Key;
   begin
      for I in Length range 0 .. Process_Size - 1 loop
         Target (Target'First + I) := Data (First + I) xor Key (Key'First + I mod Key'Length);
      end loop;
   end Parse_Xor_Many_Classic_Mod;

   procedure Parse_Xor_Many_Classic_Counter (Data : Bytes; First : Length; Target : in out Bytes)
   with No_Inline;

   procedure Parse_Xor_Many_Classic_Counter (Data : Bytes; First : Length; Target : in out Bytes) is
      Key : Bytes renames Bench_Data.Xor_Key;
      K   : Length := Key'First;
   begin
      for I in Length range 0 .. Process_Size - 1 loop
         Target (Target'First + I) := Data (First + I) xor Key (K);
         K := K + 1;
         if K > Key'Last then
            K := Key'First;
         end if;
      end loop;
   end Parse_Xor_Many_Classic_Counter;

   procedure Parse_Rotate_Kaitai (Data : Bytes; First : Length; Target : in out Bytes)
   with No_Inline;

   procedure Parse_Rotate_Kaitai (Data : Bytes; First : Length; Target : in out Bytes) is
   begin
      Kaitai.Processing.Rotate_Left (Data (First .. First + Process_Size - 1), 3, Target);
   end Parse_Rotate_Kaitai;

   procedure Parse_Rotate_Classic (Data : Bytes; First : Length; Target : in out Bytes)
   with No_Inline;

   procedure Parse_Rotate_Classic (Data : Bytes; First : Length; Target : in out Bytes) is
   begin
      for I in Length range 0 .. Process_Size - 1 loop
         Target (Target'First + I) := Rotate_Left (Data (First + I), 3);
      end loop;
   end Parse_Rotate_Classic;

   function Run_Xor_One_Kaitai (Data : Bytes) return U64 is
      First : Length := Data'First;
      Sum   : U64 := 0;
   begin
      while Data'Last - First >= Process_Size - 1 loop
         Parse_Xor_One_Kaitai (Data, First, Process_Target);
         Sum := Process_Mix (Sum);
         First := First + Process_Size;
      end loop;
      return Sum;
   end Run_Xor_One_Kaitai;

   function Run_Xor_One_Classic (Data : Bytes) return U64 is
      First : Length := Data'First;
      Sum   : U64 := 0;
   begin
      while Data'Last - First >= Process_Size - 1 loop
         Parse_Xor_One_Classic (Data, First, Process_Target);
         Sum := Process_Mix (Sum);
         First := First + Process_Size;
      end loop;
      return Sum;
   end Run_Xor_One_Classic;

   function Run_Xor_Many_Kaitai (Data : Bytes) return U64 is
      First : Length := Data'First;
      Sum   : U64 := 0;
   begin
      while Data'Last - First >= Process_Size - 1 loop
         Parse_Xor_Many_Kaitai (Data, First, Process_Target);
         Sum := Process_Mix (Sum);
         First := First + Process_Size;
      end loop;
      return Sum;
   end Run_Xor_Many_Kaitai;

   function Run_Xor_Many_Classic_Mod (Data : Bytes) return U64 is
      First : Length := Data'First;
      Sum   : U64 := 0;
   begin
      while Data'Last - First >= Process_Size - 1 loop
         Parse_Xor_Many_Classic_Mod (Data, First, Process_Target);
         Sum := Process_Mix (Sum);
         First := First + Process_Size;
      end loop;
      return Sum;
   end Run_Xor_Many_Classic_Mod;

   function Run_Xor_Many_Classic_Counter (Data : Bytes) return U64 is
      First : Length := Data'First;
      Sum   : U64 := 0;
   begin
      while Data'Last - First >= Process_Size - 1 loop
         Parse_Xor_Many_Classic_Counter (Data, First, Process_Target);
         Sum := Process_Mix (Sum);
         First := First + Process_Size;
      end loop;
      return Sum;
   end Run_Xor_Many_Classic_Counter;

   function Run_Rotate_Kaitai (Data : Bytes) return U64 is
      First : Length := Data'First;
      Sum   : U64 := 0;
   begin
      while Data'Last - First >= Process_Size - 1 loop
         Parse_Rotate_Kaitai (Data, First, Process_Target);
         Sum := Process_Mix (Sum);
         First := First + Process_Size;
      end loop;
      return Sum;
   end Run_Rotate_Kaitai;

   function Run_Rotate_Classic (Data : Bytes) return U64 is
      First : Length := Data'First;
      Sum   : U64 := 0;
   begin
      while Data'Last - First >= Process_Size - 1 loop
         Parse_Rotate_Classic (Data, First, Process_Target);
         Sum := Process_Mix (Sum);
         First := First + Process_Size;
      end loop;
      return Sum;
   end Run_Rotate_Classic;

   ---------------------------------------------------------------------
   --  The library reading through the stream parameter
   ---------------------------------------------------------------------

   procedure Parse_Term_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Term_Record)
   with No_Inline;

   procedure Parse_Term_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; This : out Term_Record) is
      use Kaitai.Streams;
   begin
      Read_Bytes_Term (Data, S, 0, Include => False, Consume => True, EOS_Error => True, Data => This.S1);
      Read_Bytes_Term (Data, S, 0, Include => False, Consume => True, EOS_Error => True, Data => This.S2);
      Read_U2le (Data, S, This.N);
   end Parse_Term_Kaitai;

   function Run_Term_Kaitai (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Term_Record;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Term_Kaitai (Data, S, This);
         exit when not Kaitai.Streams.OK (S);
         Sum := Term_Mix (Sum, This);
      end loop;
      return Sum;
   end Run_Term_Kaitai;

   procedure Parse_Contents_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U32)
   with No_Inline;

   procedure Parse_Contents_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; Value : out U32) is
      use Kaitai.Streams;
   begin
      Read_Contents (Data, S, Bench_Data.Magic);
      Read_U4le (Data, S, Value);
   end Parse_Contents_Kaitai;

   function Run_Contents_Kaitai (Data : Bytes) return U64 is
      S     : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      Value : U32;
      Sum   : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Contents_Kaitai (Data, S, Value);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + U64 (Value);
      end loop;
      return Sum;
   end Run_Contents_Kaitai;

   procedure Parse_Body_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8)
   with No_Inline;

   procedure Parse_Body_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8) is
      use Kaitai.Streams;
   begin
      Read_U2le (Data, S, A);
      Read_U1 (Data, S, B);
   end Parse_Body_Kaitai;

   procedure Parse_Substream_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8)
   with No_Inline;

   procedure Parse_Substream_Kaitai (Data : Bytes; S : in out Kaitai.Streams.Stream; A : out U16; B : out U8) is
      use Kaitai.Streams;
      N   : U8;
      Sub : Stream;
   begin
      Read_U1 (Data, S, N);
      Substream (Data, S, Length (N), Sub);
      Parse_Body_Kaitai (Data, Sub, A, B);
      Join (S, Sub);
   end Parse_Substream_Kaitai;

   function Run_Substream_Kaitai (Data : Bytes) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      A   : U16;
      B   : U8;
      Sum : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Parse_Substream_Kaitai (Data, S, A, B);
         exit when not Kaitai.Streams.OK (S);
         Sum := Sum * 31 + U64 (A) + U64 (B);
      end loop;
      return Sum;
   end Run_Substream_Kaitai;

   ---------------------------------------------------------------------
   --  Sticky against returned status, one parser per record
   ---------------------------------------------------------------------

   procedure Parse_Status1_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Status1_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Acc : out U64) is
      use Cursor_Sticky;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Acc := A;
   end Parse_Status1_Sticky;

   function Run_Status1_Sticky (Data : Bytes) return U64 is
      S   : Cursor_Sticky.Stream := Cursor_Sticky.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while S.Pos <= S.Last loop
         Parse_Status1_Sticky (Data, S, Acc);
         exit when S.Failed;
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Status1_Sticky;

   procedure Parse_Status1_Returned (Data : Bytes; S : in out Cursor_Status.Stream; Acc : out U64; OK : out Boolean)
   with No_Inline;

   procedure Parse_Status1_Returned (Data : Bytes; S : in out Cursor_Status.Stream; Acc : out U64; OK : out Boolean) is
      use Cursor_Status;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := U64 (V);
      Acc := A;
   end Parse_Status1_Returned;

   function Run_Status1_Returned (Data : Bytes) return U64 is
      S   : Cursor_Status.Stream := Cursor_Status.Open (Data);
      Acc : U64;
      OK  : Boolean;
      Sum : U64 := 0;
   begin
      while S.Pos <= S.Last loop
         Parse_Status1_Returned (Data, S, Acc, OK);
         exit when not OK;
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Status1_Returned;

   procedure Parse_Status4_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Status4_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Acc : out U64) is
      use Cursor_Sticky;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Status4_Sticky;

   function Run_Status4_Sticky (Data : Bytes) return U64 is
      S   : Cursor_Sticky.Stream := Cursor_Sticky.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while S.Pos <= S.Last loop
         Parse_Status4_Sticky (Data, S, Acc);
         exit when S.Failed;
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Status4_Sticky;

   procedure Parse_Status4_Returned (Data : Bytes; S : in out Cursor_Status.Stream; Acc : out U64; OK : out Boolean)
   with No_Inline;

   procedure Parse_Status4_Returned (Data : Bytes; S : in out Cursor_Status.Stream; Acc : out U64; OK : out Boolean) is
      use Cursor_Status;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Status4_Returned;

   function Run_Status4_Returned (Data : Bytes) return U64 is
      S   : Cursor_Status.Stream := Cursor_Status.Open (Data);
      Acc : U64;
      OK  : Boolean;
      Sum : U64 := 0;
   begin
      while S.Pos <= S.Last loop
         Parse_Status4_Returned (Data, S, Acc, OK);
         exit when not OK;
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Status4_Returned;

   procedure Parse_Status8_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Acc : out U64)
   with No_Inline;

   procedure Parse_Status8_Sticky (Data : Bytes; S : in out Cursor_Sticky.Stream; Acc : out U64) is
      use Cursor_Sticky;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V);
      A := U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V);
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Status8_Sticky;

   function Run_Status8_Sticky (Data : Bytes) return U64 is
      S   : Cursor_Sticky.Stream := Cursor_Sticky.Open (Data);
      Acc : U64;
      Sum : U64 := 0;
   begin
      while S.Pos <= S.Last loop
         Parse_Status8_Sticky (Data, S, Acc);
         exit when S.Failed;
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Status8_Sticky;

   procedure Parse_Status8_Returned (Data : Bytes; S : in out Cursor_Status.Stream; Acc : out U64; OK : out Boolean)
   with No_Inline;

   procedure Parse_Status8_Returned (Data : Bytes; S : in out Cursor_Status.Stream; Acc : out U64; OK : out Boolean) is
      use Cursor_Status;
      V : U8;
      A : U64;
   begin
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Read_U1 (Data, S, V, OK);
      if not OK then
         Acc := 0;
         return;
      end if;
      A := A * 31 + U64 (V);
      Acc := A;
   end Parse_Status8_Returned;

   function Run_Status8_Returned (Data : Bytes) return U64 is
      S   : Cursor_Status.Stream := Cursor_Status.Open (Data);
      Acc : U64;
      OK  : Boolean;
      Sum : U64 := 0;
   begin
      while S.Pos <= S.Last loop
         Parse_Status8_Returned (Data, S, Acc, OK);
         exit when not OK;
         Sum := Sum * 31 + Acc;
      end loop;
      return Sum;
   end Run_Status8_Returned;

end Stream_Runs;
