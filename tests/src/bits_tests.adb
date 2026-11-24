with Kaitai.Bits;    use Kaitai.Bits;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Test_Support;   use Test_Support;

package body Bits_Tests is

   type Bit_Order is (Big, Little);

   --  Reference model: the stream as a sequence of single bits.  Bit number
   --  K is in byte K / 8.  In big endian order the most significant bit of a
   --  byte comes first and the first bit read is the most significant bit
   --  of the value; in little endian order it is the other way round.
   function Model (Data : Bytes; Order : Bit_Order; From : Natural; Count : Bit_Count) return U64 is
      Result : U64 := 0;
      Octet  : U8;
      Bit    : U64;
   begin
      for I in 0 .. Count - 1 loop
         Octet := Data (Data'First + Length ((From + I) / 8));
         case Order is
            when Big    =>
               Bit := U64 (Shift_Right (Octet, 7 - (From + I) mod 8) and 1);
               Result := Shift_Left (Result, 1) or Bit;

            when Little =>
               Bit := U64 (Shift_Right (Octet, (From + I) mod 8) and 1);
               Result := Result or Shift_Left (Bit, I);
         end case;
      end loop;
      return Result;
   end Model;

   procedure Read (Data : Bytes; S : in out Stream; Order : Bit_Order; Count : Bit_Count; Value : out U64) is
   begin
      case Order is
         when Big    =>
            Read_Bits_Int_Be (Data, S, Count, Value);

         when Little =>
            Read_Bits_Int_Le (Data, S, Count, Value);
      end case;
   end Read;

   Data : constant Bytes (3 .. 12) :=
     (2#1010_1100#, 2#1111_0000#, 16#12#, 16#34#, 16#56#, 16#78#, 16#9A#, 16#BC#, 16#DE#, 16#F1#);

   procedure Test_Examples is
      S : Stream := Open (Data);
      V : U64;
      B : U8;
   begin
      Group ("Bits helpers");
      Check (Mask (1) = 1 and then Mask (8) = 255 and then Mask (63) = 2**63 - 1, "mask");
      Check (Mask (64) = U64'Last, "mask of 64 bits");
      Check (Bytes_Needed (3, 0) = 1 and then Bytes_Needed (8, 0) = 1 and then Bytes_Needed (9, 0) = 2, "bytes needed");
      Check
        (Bytes_Needed (3, 5) = 0 and then Bytes_Needed (5, 5) = 0 and then Bytes_Needed (6, 5) = 1, "with bits left");
      Check (Bytes_Needed (64, 0) = 8 and then Bytes_Needed (64, 7) = 8 and then Bytes_Needed (64, 1) = 8, "64 bits");
      Check (Left_After (3, 0) = 5 and then Left_After (8, 0) = 0 and then Left_After (9, 0) = 7, "bits left after");
      Check
        (Left_After (3, 5) = 2 and then Left_After (5, 5) = 0 and then Left_After (6, 5) = 7, "after, with bits left");

      Group ("Bits big endian");
      Read_Bits_Int_Be (Data, S, 3, V);
      Check (V = 2#101# and then Pos (S) = 1 and then Bits_Left (S) = 5, "first three bits");
      Read_Bits_Int_Be (Data, S, 5, V);
      Check (V = 2#01100# and then Pos (S) = 1 and then Bits_Left (S) = 0, "rest of the byte");
      Read_Bits_Int_Be (Data, S, 4, V);
      Check (V = 2#1111# and then Pos (S) = 2 and then Bits_Left (S) = 4, "half of the next byte");
      Read_Bits_Int_Be (Data, S, 12, V);
      Check (V = 16#012# and then Pos (S) = 3 and then Bits_Left (S) = 0, "across a byte boundary");
      Read_Bits_Int_Be (Data, S, 1, V);
      Check (V = 0 and then Bits_Left (S) = 7, "a single bit");
      Read_Bits_Int_Be (Data, S, 64, V);
      Check (Status (S) = End_Of_Stream and then V = 0, "64 bits with 55 left fails");

      S := Open (Data);
      Read_Bits_Int_Be (Data, S, 7, V);
      Check (V = 2#1010110#, "seven bits");
      Read_Bits_Int_Be (Data, S, 64, V);
      Check (V = 16#7809_1A2B_3C4D_5E6F#, "64 bits that span nine bytes");
      Check (V = Model (Data, Big, 7, 64), "the model agrees");
      Check (Pos (S) = 9 and then Bits_Left (S) = 1 and then OK (S), "position after 64 bits");

      Group ("Bits little endian");
      S := Open (Data);
      Read_Bits_Int_Le (Data, S, 3, V);
      Check (V = 2#100# and then Pos (S) = 1 and then Bits_Left (S) = 5, "first three bits");
      Read_Bits_Int_Le (Data, S, 5, V);
      Check (V = 2#10101# and then Bits_Left (S) = 0, "rest of the byte");
      Read_Bits_Int_Le (Data, S, 4, V);
      Check (V = 0 and then Pos (S) = 2 and then Bits_Left (S) = 4, "low half of the next byte");
      Read_Bits_Int_Le (Data, S, 12, V);
      Check (V = 16#12F# and then Pos (S) = 3 and then Bits_Left (S) = 0, "across a byte boundary");

      Group ("Bits alignment");
      S := Open (Data);
      Read_Bits_Int_Be (Data, S, 3, V);
      Align_To_Byte (S);
      Check (Bits_Left (S) = 0 and then Pos (S) = 1, "align drops the bits left");
      Read_Bits_Int_Be (Data, S, 4, V);
      Check (V = 2#1111#, "the next bit field starts at the byte boundary");
      Read_U1 (Data, S, B);
      Check (B = 16#12# and then Bits_Left (S) = 0, "a byte read starts at the next byte and aligns");
      Read_Bits_Int_Be (Data, S, 4, V);
      Check (V = 3, "a bit field after a byte read starts at the byte boundary");
      Seek (S, 0);
      Check (Bits_Left (S) = 0, "seek aligns");
      Read_Bits_Int_Be (Data, S, 2, V);
      Skip (S, 1);
      Check (Bits_Left (S) = 0 and then Pos (S) = 2, "skip aligns");

      Group ("Bits failure");
      S := Open (Data);
      Seek (S, 9);
      Read_Bits_Int_Be (Data, S, 5, V);
      Check (V = 2#11110# and then Bits_Left (S) = 3, "five of the last eight bits");
      Read_Bits_Int_Be (Data, S, 4, V);
      Check (Status (S) = End_Of_Stream and then V = 0, "four bits with three left fails");
      Check (Pos (S) = 10 and then Bits_Left (S) = 3, "a failed read leaves position and bits");
      Read_Bits_Int_Be (Data, S, 1, V);
      Check (V = 0 and then Bits_Left (S) = 3, "a bit field after a failure does nothing");
      S := Open (Data);
      Seek (S, 3);
      Read_Bits_Int_Le (Data, S, 64, V);
      Check (Status (S) = End_Of_Stream and then V = 0 and then Pos (S) = 3, "64 bits with 56 left fails");
      S := Open (Data);
      Seek (S, 2);
      Read_Bits_Int_Le (Data, S, 64, V);
      Check (OK (S) and then V = 16#F1DE_BC9A_7856_3412# and then Is_EOF (S), "64 bits in little endian order");
   end Test_Examples;

   --  Compare the library with the model on pseudo random data and widths
   procedure Test_Against_Model (Order : Bit_Order) is
      Random : Bytes (1 .. 40);
      State  : U32 := 16#C0FF_EE11#;
      S      : Stream;
      Value  : U64;
      Wrong  : Natural := 0;
      Reads  : Natural := 0;

      function Next return U32 is
      begin
         State := State * 1_664_525 + 1_013_904_223;
         return Shift_Right (State, 8);
      end Next;
   begin
      Group (if Order = Big then "Bits model, big endian" else "Bits model, little endian");
      for B of Random loop
         B := U8 (Next mod 256);
      end loop;

      for Round in 1 .. 300 loop
         S := Open (Random);
         declare
            At_Bit : Natural := 0;
            Count  : Bit_Count;
         begin
            loop
               --  Small widths are more likely, as in real formats
               Count := (if Next mod 4 = 0 then Natural (Next mod 64) + 1 else Natural (Next mod 12) + 1);
               exit when At_Bit + Count > Random'Length * 8;
               Read (Random, S, Order, Count, Value);
               Reads := Reads + 1;
               At_Bit := At_Bit + Count;
               if not OK (S)
                 or else Value /= Model (Random, Order, At_Bit - Count, Count)
                 or else Natural (Pos (S)) /= (At_Bit + 7) / 8
                 or else Bits_Left (S) /= (8 - At_Bit mod 8) mod 8
               then
                  Wrong := Wrong + 1;
               end if;
            end loop;
         end;
      end loop;
      Check (Reads > 3_000, "enough reads were compared");
      Check (Wrong = 0, "value, position and bits left agree with the model");
   end Test_Against_Model;

   procedure Test_EOF is
      S : Stream := Open (Data (11 .. 12));
      B : U64;
      V : U8;
   begin
      Group ("Bits end of stream");
      Read_U1 (Data, S, V);
      Check (not Is_EOF (S), "a byte is left");
      Read_Bits_Int_Be (Data, S, 3, B);
      Check (Remaining (S) = 0 and then not Is_EOF (S), "no byte is left, but five bits are");
      Read_Bits_Int_Be (Data, S, 4, B);
      Check (not Is_EOF (S), "one bit is left");
      Read_Bits_Int_Be (Data, S, 1, B);
      Check (OK (S) and then Is_EOF (S), "nothing is left");

      S := Open (Data (12 .. 12));
      Read_Bits_Int_Le (Data, S, 7, B);
      Check (not Is_EOF (S), "the same in little endian bit order");
      Align_To_Byte (S);
      Check (OK (S) and then Is_EOF (S), "bits that are dropped are not left");

      S := Open (Data (12 .. 12));
      Read_Bits_Int_Be (Data, S, 2, B);
      Read_U1 (Data, S, V);
      Check (Status (S) = End_Of_Stream, "a byte cannot be read from the bits that are left");
   end Test_EOF;

   procedure Run is
   begin
      Test_EOF;
      Test_Examples;
      Test_Against_Model (Big);
      Test_Against_Model (Little);
   end Run;

end Bits_Tests;
