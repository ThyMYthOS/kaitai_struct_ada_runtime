with Bit_Variants;
with Kaitai.Decoding;
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

end Stream_Runs;
