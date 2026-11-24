--  The decoder follows "puff.c" by Mark Adler, which comes with zlib as a
--  small model of an inflater: Huffman codes are decoded bit by bit with a
--  table of the number of codes of each length and a table of symbols in
--  the order of their codes.  It is small, not fast.

package body Kaitai.Zlib
  with SPARK_Mode
is

   --  The most symbols that a code of one alphabet has: 286 literals and
   --  lengths and 30 distances are sent together, 288 literals and lengths
   --  are needed for the fixed code, and a little room is left.
   Max_Symbols : constant := 320;

   --  The longest code of DEFLATE
   Max_Bits : constant := 15;

   subtype Small is Natural range 0 .. Max_Symbols;
   subtype Symbol_Value is Natural range 0 .. Max_Symbols - 1;
   subtype Code_Length is Natural range 0 .. Max_Bits;

   --  The code lengths of the symbols of one or two alphabets
   type Length_Table is array (0 .. Max_Symbols - 1) of Code_Length;

   --  A Huffman code in canonical form.  Count (L) is the number of symbols
   --  whose code has L bits (Count (0) is the number of unused symbols).
   --  Symbol holds the used symbols ordered by code length and then by
   --  value, which is also the order of their codes.
   type Count_Table is array (0 .. Max_Bits) of Small with Component_Size => 16;
   type Symbol_Table is array (0 .. Max_Symbols - 1) of Symbol_Value with Component_Size => 16;

   type Huffman is record
      Count  : Count_Table;
      Symbol : Symbol_Table;
   end record;

   --  Where decoding is.  The bits of Source are used from the least
   --  significant one of each byte.  Buf holds the Cnt bits of the last
   --  byte taken from Source that are not used yet; there are always fewer
   --  than eight, because a byte is taken only when bits are missing.
   --  Pos is the position in Source of the next byte to take, Out_Pos the
   --  position in Target for the next byte of data.
   subtype Bit_Count is Natural range 0 .. 7;

   type State is record
      Pos     : Length;
      Buf     : U32;
      Cnt     : Bit_Count;
      Out_Pos : Length;
   end record;

   --  Pos and Out_Pos denote bytes of the arrays or the place after the last.
   function Source_OK (S : State; Source : Bytes) return Boolean
   is (S.Pos >= Source'First and then S.Pos <= Source'Last + 1)
   with Ghost;

   function Target_OK (S : State; Target : Bytes) return Boolean
   is (S.Out_Pos >= Target'First and then S.Out_Pos <= Target'Last + 1)
   with Ghost;

   --  Decoding has used at least as many bits as at Before, or more of them.
   --  Every loop below consumes at least one bit per iteration; this is why
   --  they end.  Pos does not decrease, and if it does not grow, Cnt
   --  falls.  Counting the bits in a number is not possible, because it
   --  could be larger than any number the target has.
   function Not_Behind (Before : State; S : State) return Boolean
   is (S.Pos > Before.Pos or else (S.Pos = Before.Pos and then S.Cnt <= Before.Cnt))
   with Ghost;

   function Ahead (Before : State; S : State) return Boolean
   is (S.Pos > Before.Pos or else (S.Pos = Before.Pos and then S.Cnt < Before.Cnt))
   with Ghost;

   --  The next Need bits of Source as a number; the first bit is the least
   --  significant one.
   procedure Get_Bits (Source : Bytes; S : in out State; Need : Natural; Value : out U32; Result : out Result_Kind)
   with
     Pre  => Need <= 13 and then Source_OK (S, Source),
     Post =>
       Result in Done | Corrupt
       and then (if Result = Done
                 then
                   Source_OK (S, Source)
                   and then S.Out_Pos = S'Old.Out_Pos
                   and then Value < Shift_Left (1, Need)
                   and then Not_Behind (S'Old, S)
                   and then (if Need > 0 then Ahead (S'Old, S)));

   procedure Get_Bits (Source : Bytes; S : in out State; Need : Natural; Value : out U32; Result : out Result_Kind) is
      Pos0 : constant Length := S.Pos;
      Cnt0 : constant Bit_Count := S.Cnt;
      Val  : U32 := S.Buf;
      Have : Natural := S.Cnt;
   begin
      Value := 0;
      Result := Corrupt;
      while Have < Need loop
         pragma Loop_Invariant (Source_OK (S, Source));
         pragma Loop_Invariant (Have < Need + 8);
         pragma Loop_Invariant (S.Pos > Pos0 or else (S.Pos = Pos0 and then Have = Cnt0));
         pragma Loop_Invariant (S.Out_Pos = S.Out_Pos'Loop_Entry);
         pragma Loop_Variant (Increases => Have);

         --  The input ends before the bits are complete
         if S.Pos > Source'Last then
            return;
         end if;
         Val := Val or Shift_Left (U32 (Source (S.Pos)), Have);
         S.Pos := S.Pos + 1;
         Have := Have + 8;
      end loop;
      Value := Val and (Shift_Left (1, Need) - 1);
      S.Buf := Shift_Right (Val, Need);
      S.Cnt := Have - Need;
      Result := Done;
   end Get_Bits;

   --  Make H the code for symbols 0 .. N - 1 whose lengths are
   --  Lens (First) .. Lens (First + N - 1).  Left is how many more codes of
   --  the longest length the code would have room for, negative if the
   --  lengths are impossible, because they need more codes than there are.
   --  Zero means that the code is complete.
   procedure Construct (H : out Huffman; Lens : Length_Table; First : Natural; N : Natural; Left : out Integer)
   with Pre => First <= Max_Symbols and then N <= Max_Symbols - First;

   procedure Construct (H : out Huffman; Lens : Length_Table; First : Natural; N : Natural; Left : out Integer) is
      --  Place in Symbol where the next symbol of each length goes
      Offs : array (1 .. Max_Bits) of Natural := (others => 0);
      Free : Integer := 1;
   begin
      H.Count := (others => 0);
      H.Symbol := (others => 0);
      Left := -1;
      for Sym in 0 .. N - 1 loop
         pragma Loop_Invariant (for all L in H.Count'Range => H.Count (L) <= Sym);
         declare
            L : constant Code_Length := Lens (First + Sym);
         begin
            H.Count (L) := H.Count (L) + 1;
         end;
      end loop;

      --  Every length a code may have is looked at: the codes of length L
      --  are 2 ** L at most, and Free is how many of them are not taken.
      for L in 1 .. Max_Bits loop
         pragma Loop_Invariant (Free >= 0 and then Free <= 2**(L - 1));
         Free := 2 * Free - H.Count (L);
         if Free < 0 then
            return;
         end if;
      end loop;
      Left := Free;

      for L in 1 .. Max_Bits - 1 loop
         pragma Loop_Invariant (for all K in 1 .. L => Offs (K) <= Max_Symbols * (K - 1));
         Offs (L + 1) := Offs (L) + H.Count (L);
      end loop;

      for Sym in 0 .. N - 1 loop
         declare
            L : constant Code_Length := Lens (First + Sym);
         begin
            if L /= 0 then

               --  There are fewer places than symbols
               if Offs (L) >= Max_Symbols then
                  Left := -1;
                  return;
               end if;
               H.Symbol (Offs (L)) := Sym;
               Offs (L) := Offs (L) + 1;
            end if;
         end;
      end loop;
   end Construct;

   --  The next symbol of Source according to H.  A code of length L is a
   --  number of L bits, sent starting with the most significant one.  The
   --  codes of one length are consecutive numbers, and those of the next
   --  length start after the last of this one (First is the smallest code
   --  of length L) and are one bit longer.  So if the bits read so far are
   --  a number below First + Count (L), they are the code of one of the
   --  symbols of length L, namely the one that many places after the first.
   procedure Decode (Source : Bytes; S : in out State; H : Huffman; Sym : out Symbol_Value; Result : out Result_Kind)
   with
     Pre  => Source_OK (S, Source),
     Post =>
       Result in Done | Corrupt
       and then (if Result = Done
                 then Source_OK (S, Source) and then S.Out_Pos = S'Old.Out_Pos and then Ahead (S'Old, S));

   procedure Decode (Source : Bytes; S : in out State; H : Huffman; Sym : out Symbol_Value; Result : out Result_Kind) is
      S0    : constant State := S;
      Bit   : U32;
      Code  : Natural := 0;  --  bits read so far as a number
      First : Natural := 0;  --  smallest code of the current length
      Index : Natural := 0;  --  place in H.Symbol of the first symbol of the current length
   begin
      Sym := 0;
      for L in 1 .. Max_Bits loop
         pragma Loop_Invariant (Source_OK (S, Source));
         pragma Loop_Invariant (S.Out_Pos = S0.Out_Pos);
         pragma Loop_Invariant (if L = 1 then S = S0 else Ahead (S0, S));
         pragma Loop_Invariant (Code <= 32767 and then First <= 32768);
         pragma Loop_Invariant (Index <= Max_Symbols * (L - 1));

         Get_Bits (Source, S, 1, Bit, Result);
         if Result /= Done then
            return;
         end if;
         Result := Corrupt;
         pragma Assert (Bit <= 1);
         Code := Code + Natural (Bit);

         declare
            Count : constant Natural := H.Count (L);
         begin
            if Code < First + Count then
               if Code >= First and then Index + (Code - First) < Max_Symbols then
                  Sym := H.Symbol (Index + (Code - First));
                  Result := Done;
               end if;
               return;
            end if;
            Index := Index + Count;
            First := (First + Count) * 2;
            Code := Code * 2;
         end;

         --  A code of fewer than 15 bits is below 2 ** 15 and so is First;
         --  larger numbers mean that the code was not found
         if Code > 32767 or else First > 32768 then
            return;
         end if;
      end loop;
   end Decode;

   --  Base values and numbers of extra bits of the symbols 257 .. 285 for
   --  lengths and of the symbols 0 .. 29 for distances
   Length_Base  : constant array (0 .. 28) of Positive :=
     (3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      13,
      15,
      17,
      19,
      23,
      27,
      31,
      35,
      43,
      51,
      59,
      67,
      83,
      99,
      115,
      131,
      163,
      195,
      227,
      258);
   Length_Extra : constant array (0 .. 28) of Natural range 0 .. 5 :=
     (0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0);
   Dist_Base    : constant array (0 .. 29) of Positive :=
     (1,
      2,
      3,
      4,
      5,
      7,
      9,
      13,
      17,
      25,
      33,
      49,
      65,
      97,
      129,
      193,
      257,
      385,
      513,
      769,
      1025,
      1537,
      2049,
      3073,
      4097,
      6145,
      8193,
      12289,
      16385,
      24577);
   Dist_Extra   : constant array (0 .. 29) of Natural range 0 .. 13 :=
     (0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13);

   --  The data of a block that is compressed with the codes Lit and Dist,
   --  up to the end-of-block symbol.
   procedure Codes
     (Source : Bytes; Target : in out Bytes; S : in out State; Lit : Huffman; Dist : Huffman; Result : out Result_Kind)
   with
     Pre  => Source_OK (S, Source) and then Target_OK (S, Target),
     Post =>
       (if Result = Done then Source_OK (S, Source) and then Target_OK (S, Target) and then Not_Behind (S'Old, S));

   procedure Codes
     (Source : Bytes; Target : in out Bytes; S : in out State; Lit : Huffman; Dist : Huffman; Result : out Result_Kind)
   is
      S0    : constant State := S;
      Sym   : Symbol_Value;
      Bits  : U32;
      Len   : Positive;
      Back  : Positive;
      Start : Length;
   begin
      loop
         pragma Loop_Invariant (Source_OK (S, Source) and then Target_OK (S, Target));
         pragma Loop_Invariant (Not_Behind (S0, S));
         pragma Loop_Variant (Increases => S.Pos, Decreases => S.Cnt);

         Decode (Source, S, Lit, Sym, Result);
         if Result /= Done then
            return;
         end if;
         Result := Corrupt;

         if Sym < 256 then
            if S.Out_Pos > Target'Last then
               Result := Target_Full;
               return;
            end if;
            Target (S.Out_Pos) := U8 (Sym);
            S.Out_Pos := S.Out_Pos + 1;

         elsif Sym = 256 then
            Result := Done;
            return;

         else
            Sym := Sym - 257;

            --  The symbols 286 and 287 do not stand for anything
            if Sym > 28 then
               return;
            end if;
            Get_Bits (Source, S, Length_Extra (Sym), Bits, Result);
            if Result /= Done then
               return;
            end if;
            Len := Length_Base (Sym) + Natural (Bits);

            Decode (Source, S, Dist, Sym, Result);
            if Result /= Done then
               return;
            end if;
            Result := Corrupt;
            if Sym > 29 then
               return;
            end if;
            Get_Bits (Source, S, Dist_Extra (Sym), Bits, Result);
            if Result /= Done then
               return;
            end if;
            Result := Corrupt;
            Back := Dist_Base (Sym) + Natural (Bits);

            --  The data that is referred to has to exist
            if Length (Back) > S.Out_Pos - Target'First then
               return;
            end if;
            if Length (Len) > Target'Last + 1 - S.Out_Pos then
               Result := Target_Full;
               return;
            end if;

            --  The bytes are copied one by one, because the data may
            --  overlap the place it is copied to; Back = 1 repeats the last
            --  byte Len times.
            Start := S.Out_Pos;
            for I in 1 .. Len loop
               pragma Loop_Invariant (S.Out_Pos = Start + Length (I - 1));
               pragma Loop_Invariant (Start = Start'Loop_Entry);
               Target (S.Out_Pos) := Target (S.Out_Pos - Length (Back));
               S.Out_Pos := S.Out_Pos + 1;
            end loop;
         end if;
      end loop;
   end Codes;

   --  A block of bytes that are not compressed: Len and its complement as
   --  two bytes each, then the bytes.  The bits that are left of the byte
   --  of the block header are not used.
   procedure Stored (Source : Bytes; Target : in out Bytes; S : in out State; Result : out Result_Kind)
   with
     Pre  => Source_OK (S, Source) and then Target_OK (S, Target),
     Post =>
       (if Result = Done then Source_OK (S, Source) and then Target_OK (S, Target) and then Not_Behind (S'Old, S));

   procedure Stored (Source : Bytes; Target : in out Bytes; S : in out State; Result : out Result_Kind) is
      Len, Complement : Natural;
      From, To        : Length;
   begin
      Result := Corrupt;
      S.Buf := 0;
      S.Cnt := 0;
      if Source'Last + 1 - S.Pos < 4 then
         return;
      end if;
      Len := Natural (Source (S.Pos)) + 256 * Natural (Source (S.Pos + 1));
      Complement := Natural (Source (S.Pos + 2)) + 256 * Natural (Source (S.Pos + 3));
      if Len + Complement /= 65535 then
         return;
      end if;
      S.Pos := S.Pos + 4;
      if Source'Last + 1 - S.Pos < Length (Len) then
         return;
      end if;
      if Target'Last + 1 - S.Out_Pos < Length (Len) then
         Result := Target_Full;
         return;
      end if;
      From := S.Pos;
      To := S.Out_Pos;
      for I in 0 .. Len - 1 loop
         Target (To + Length (I)) := Source (From + Length (I));
      end loop;
      S.Pos := S.Pos + Length (Len);
      S.Out_Pos := S.Out_Pos + Length (Len);
      Result := Done;
   end Stored;

   --  A block with the fixed codes of the format
   procedure Fixed (Source : Bytes; Target : in out Bytes; S : in out State; Result : out Result_Kind)
   with
     Pre  => Source_OK (S, Source) and then Target_OK (S, Target),
     Post =>
       (if Result = Done then Source_OK (S, Source) and then Target_OK (S, Target) and then Not_Behind (S'Old, S));

   procedure Fixed (Source : Bytes; Target : in out Bytes; S : in out State; Result : out Result_Kind) is
      Lens : Length_Table := (others => 5);
      Lit  : Huffman;
      Dist : Huffman;
      Left : Integer;
   begin
      Result := Corrupt;

      --  All 30 distances have five bits.  Such a code is not complete, as
      --  it has room for two more.
      Construct (Dist, Lens, 0, 30, Left);
      if Left < 0 then
         return;
      end if;
      for I in 0 .. 143 loop
         Lens (I) := 8;
      end loop;
      for I in 144 .. 255 loop
         Lens (I) := 9;
      end loop;
      for I in 256 .. 279 loop
         Lens (I) := 7;
      end loop;
      for I in 280 .. 287 loop
         Lens (I) := 8;
      end loop;
      Construct (Lit, Lens, 0, 288, Left);
      if Left /= 0 then
         return;
      end if;
      Codes (Source, Target, S, Lit, Dist, Result);
   end Fixed;

   --  The order in which the lengths of the codes that code lengths are
   --  sent with come.
   Order : constant array (0 .. 18) of Natural range 0 .. 18 :=
     (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15);

   --  True if the Left of a code with N symbols is acceptable for the
   --  code of literals or of distances.  It may be incomplete only if the
   --  code is for one symbol.
   function Usable (H : Huffman; N : Natural; Left : Integer) return Boolean
   is (Left = 0 or else (Left > 0 and then N = H.Count (0) + H.Count (1)));

   --  A block whose codes are sent in front of its data
   procedure Dynamic (Source : Bytes; Target : in out Bytes; S : in out State; Result : out Result_Kind)
   with
     Pre  => Source_OK (S, Source) and then Target_OK (S, Target),
     Post =>
       (if Result = Done then Source_OK (S, Source) and then Target_OK (S, Target) and then Not_Behind (S'Old, S));

   procedure Dynamic (Source : Bytes; Target : in out Bytes; S : in out State; Result : out Result_Kind) is
      S0    : constant State := S;
      Lens  : Length_Table := (others => 0);
      Lit   : Huffman;
      Dist  : Huffman;
      Left  : Integer;
      Bits  : U32;
      Sym   : Symbol_Value;
      N_Lit : Natural;
      N_Dis : Natural;
      N_Cod : Natural;
      Total : Natural;
      Index : Natural := 0;
      Rep   : Natural;
      Prev  : Code_Length;
   begin
      Get_Bits (Source, S, 5, Bits, Result);
      if Result /= Done then
         return;
      end if;
      N_Lit := Natural (Bits) + 257;
      Get_Bits (Source, S, 5, Bits, Result);
      if Result /= Done then
         return;
      end if;
      N_Dis := Natural (Bits) + 1;
      Get_Bits (Source, S, 4, Bits, Result);
      if Result /= Done then
         return;
      end if;
      N_Cod := Natural (Bits) + 4;
      Result := Corrupt;
      if N_Lit > 286 or else N_Dis > 30 then
         return;
      end if;
      Total := N_Lit + N_Dis;

      --  The lengths of the codes of the code lengths, three bits each
      for I in 0 .. N_Cod - 1 loop
         pragma Loop_Invariant (Source_OK (S, Source) and then Target_OK (S, Target));
         pragma Loop_Invariant (Not_Behind (S0, S));
         Get_Bits (Source, S, 3, Bits, Result);
         if Result /= Done then
            return;
         end if;
         Lens (Order (I)) := Natural (Bits);
      end loop;
      Result := Corrupt;
      Construct (Lit, Lens, 0, 19, Left);
      if Left /= 0 then
         return;
      end if;

      --  The lengths of the codes of literals, lengths and distances, which
      --  are coded with that code.  Symbols 16 to 18 repeat a length.
      Lens := (others => 0);
      while Index < Total loop
         pragma Loop_Invariant (Source_OK (S, Source) and then Target_OK (S, Target));
         pragma Loop_Invariant (Not_Behind (S0, S));
         pragma Loop_Invariant (Total = N_Lit + N_Dis and then Total <= 316);
         pragma Loop_Variant (Increases => Index);

         Decode (Source, S, Lit, Sym, Result);
         if Result /= Done then
            return;
         end if;
         Result := Corrupt;
         if Sym < 16 then
            Lens (Index) := Sym;
            Index := Index + 1;
         else
            Prev := 0;
            case Sym is
               when 16     =>

                  --  Repeat the previous length; there is none at first
                  if Index = 0 then
                     return;
                  end if;
                  Prev := Lens (Index - 1);
                  Get_Bits (Source, S, 2, Bits, Result);
                  if Result /= Done then
                     return;
                  end if;
                  Rep := 3 + Natural (Bits);

               when 17     =>
                  Get_Bits (Source, S, 3, Bits, Result);
                  if Result /= Done then
                     return;
                  end if;
                  Rep := 3 + Natural (Bits);

               when 18     =>
                  Get_Bits (Source, S, 7, Bits, Result);
                  if Result /= Done then
                     return;
                  end if;
                  Rep := 11 + Natural (Bits);

               when others =>
                  return;
            end case;
            Result := Corrupt;
            if Rep > Total - Index then
               return;
            end if;
            for K in 0 .. Rep - 1 loop
               Lens (Index + K) := Prev;
            end loop;
            Index := Index + Rep;
         end if;
      end loop;

      --  Without the symbol 256 the block could not end
      if Lens (256) = 0 then
         return;
      end if;
      Construct (Lit, Lens, 0, N_Lit, Left);
      if not Usable (Lit, N_Lit, Left) then
         return;
      end if;
      Construct (Dist, Lens, N_Lit, N_Dis, Left);
      if not Usable (Dist, N_Dis, Left) then
         return;
      end if;
      Codes (Source, Target, S, Lit, Dist, Result);
   end Dynamic;

   --  The two numbers that Adler-32 is made of are sums modulo 65521, the
   --  largest prime below 2 ** 16.
   function Adler_32 (Data : Bytes; Last : Length) return U32
   with Pre => Last >= Data'First - 1 and then Last <= Data'Last;

   function Adler_32 (Data : Bytes; Last : Length) return U32 is
      A : U32 := 1;
      B : U32 := 0;
   begin
      for I in Data'First .. Last loop
         pragma Loop_Invariant (A < 65521 and then B < 65521);
         A := (A + U32 (Data (I))) mod 65521;
         B := (B + A) mod 65521;
      end loop;
      return Shift_Left (B, 16) or A;
   end Adler_32;

   procedure Run (Source : Bytes; Target : in out Bytes; Last : out Length; Result : out Result_Kind)
   with
     Pre  =>
       Source'First >= 1
       and then Source'Last >= Source'First - 1
       and then Target'First >= 1
       and then Target'Last >= Target'First - 1,
     Post =>
       Last >= Target'First - 1 and then Last <= Target'Last and then (if Result /= Done then Last = Target'First - 1);

   procedure Run (Source : Bytes; Target : in out Bytes; Last : out Length; Result : out Result_Kind) is
      S      : State := (Pos => Source'First, Buf => 0, Cnt => 0, Out_Pos => Target'First);
      Bits   : U32;
      Final  : Boolean;
      Header : Natural;
      Check  : U32;
   begin
      Last := Target'First - 1;
      Result := Corrupt;

      --  The header: method and window size in one byte, flags and a check
      --  value in the next, which together are a multiple of 31.  Only the
      --  method 8 (deflate) with a window of at most 32768 bytes exists, and
      --  a preset dictionary is not supported.
      if Source'Last + 1 - Source'First < 2 then
         return;
      end if;
      Header := Natural (Source (Source'First)) * 256 + Natural (Source (Source'First + 1));
      if Header mod 31 /= 0
        or else Source (Source'First) mod 16 /= 8
        or else Source (Source'First) / 16 > 7
        or else Source (Source'First + 1) / 32 mod 2 /= 0
      then
         return;
      end if;
      S.Pos := Source'First + 2;

      loop
         pragma Loop_Invariant (Source_OK (S, Source) and then Target_OK (S, Target));
         pragma Loop_Variant (Increases => S.Pos, Decreases => S.Cnt);

         declare
            S0 : constant State := S;
         begin
            Get_Bits (Source, S, 1, Bits, Result);
            if Result /= Done then
               return;
            end if;
            Final := Bits = 1;
            Get_Bits (Source, S, 2, Bits, Result);
            if Result /= Done then
               return;
            end if;
            case Bits is
               when 0      =>
                  Stored (Source, Target, S, Result);

               when 1      =>
                  Fixed (Source, Target, S, Result);

               when 2      =>
                  Dynamic (Source, Target, S, Result);

               when others =>
                  Result := Corrupt;
            end case;
            if Result /= Done then
               return;
            end if;
            pragma Assert (Ahead (S0, S));
         end;
         exit when Final;
      end loop;

      --  The Adler-32 of the data follows, most significant byte first
      if Source'Last + 1 - S.Pos < 4 then
         Result := Corrupt;
         return;
      end if;
      Check :=
        Shift_Left (U32 (Source (S.Pos)), 24)
        or Shift_Left (U32 (Source (S.Pos + 1)), 16)
        or Shift_Left (U32 (Source (S.Pos + 2)), 8)
        or U32 (Source (S.Pos + 3));
      if Adler_32 (Target, S.Out_Pos - 1) /= Check then
         Result := Corrupt;
         return;
      end if;
      Last := S.Out_Pos - 1;
      Result := Done;
   end Run;

   procedure Inflate (Source : Bytes; Target : in out Bytes; Last : out Length; Result : out Result_Kind) is

      --  The bounds of an array without elements can be anything, which is
      --  more than the decoder can handle; it is given bounds that are the
      --  ones of an array with at most one element less than the first.
      Empty       : constant Bytes (1 .. 0) := (1 .. 0 => 0);
      Target_Last : constant Length := (if Target'Last < Target'First then Target'First - 1 else Target'Last);
   begin
      if Source'Last < Source'First then
         Run (Empty, Target (Target'First .. Target_Last), Last, Result);
      else
         Run (Source, Target (Target'First .. Target_Last), Last, Result);
      end if;
   end Inflate;

end Kaitai.Zlib;
