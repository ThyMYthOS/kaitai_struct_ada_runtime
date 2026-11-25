package body Kaitai.Streams
  with SPARK_Mode
is

   --  True if Count bytes can be read at the current position
   function Available (S : Stream; Count : Length) return Boolean
   is (S.State = Success and then Count - 1 <= S.Last - S.Next)
   with Inline;

   --  Record that the stream ran out of bytes, unless it has failed before.
   --  There is no contract on purpose: GNATprove then analyses the body in
   --  the context of each call.
   procedure Run_Out (S : in out Stream)
   with Inline;

   procedure Run_Out (S : in out Stream) is
   begin
      if S.State = Success then
         S.State := End_Of_Stream;
      end if;
   end Run_Out;

   --  Byte_Arrays.Find and Byte_Arrays.Equal once more.  A body of this
   --  package that is inlined into a parser can only take along what this
   --  package holds itself: the compiler does not look into the body of a
   --  package the parser does not name.  With a call left in, a terminated
   --  string cost a quarter more instructions.

   function Find (Buffer : Bytes; Item : Slice; Term : Byte) return Length
   with Inline, Pre => Within (Item, Buffer), Post => Find'Result = Byte_Arrays.Find (Buffer, Item, Term);

   function Find (Buffer : Bytes; Item : Slice; Term : Byte) return Length is
   begin
      for I in Item.First .. Item.Last loop
         if Buffer (I) = Term then
            return I;
         end if;
         pragma Loop_Invariant (for all J in Item.First .. I => Buffer (J) /= Term);
      end loop;
      return Item.Last + 1;
   end Find;

   function Equal (Buffer : Bytes; Item : Slice; Expected : Bytes) return Boolean
   with Inline, Pre => Within (Item, Buffer), Post => Equal'Result = Byte_Arrays.Equal (Buffer, Item, Expected);

   function Equal (Buffer : Bytes; Item : Slice; Expected : Bytes) return Boolean is
   begin
      if Size (Item) /= Expected'Length then
         return False;
      end if;
      for I in Item.First .. Item.Last loop
         if Buffer (I) /= Expected (Expected'First + (I - Item.First)) then
            return False;
         end if;
         pragma
           Loop_Invariant (for all J in Item.First .. I => Buffer (J) = Expected (Expected'First + (J - Item.First)));
      end loop;
      return True;
   end Equal;

   function Open (Buffer : Bytes) return Stream is
   begin
      if Buffer'Length = 0 then
         return (First => 1, Last => 0, Next => 1, State => Success, Unread => 0);
      else
         return (First => Buffer'First, Last => Buffer'Last, Next => Buffer'First, State => Success, Unread => 0);
      end if;
   end Open;

   function Open (Buffer : Bytes; Item : Slice) return Stream is
      --  Buffer only serves the contract
      pragma Warnings (Off, Buffer);
   begin
      return (First => Item.First, Last => Item.Last, Next => Item.First, State => Success, Unread => 0);
   end Open;

   procedure Seek (S : in out Stream; To : Length) is
   begin
      if S.State = Success and then To <= S.Last - S.First + 1 then
         S.Unread := 0;
         S.Next := S.First + To;
      else
         Run_Out (S);
      end if;
   end Seek;

   procedure Skip (S : in out Stream; Count : Length) is
   begin
      if Available (S, Count) then
         S.Next := S.Next + Count;
         S.Unread := 0;
      else
         Run_Out (S);
      end if;
   end Skip;

   procedure Advance (S : in out Stream; Count : Length) is
   begin
      S.Next := S.Next + Count;
      S.Unread := 0;
   end Advance;

   procedure Fail (S : in out Stream; Reason : Status_Kind) is
   begin
      if S.State = Success then
         S.State := Reason;
      end if;
   end Fail;

   procedure Read_U1 (Buffer : Bytes; S : in out Stream; Value : out U8) is
   begin
      if Available (S, 1) then
         Value := Decoding.U8_At (Buffer, S.Next);
         S.Next := S.Next + 1;
         S.Unread := 0;
      else
         Value := 0;
         Run_Out (S);
      end if;
   end Read_U1;

   procedure Read_S1 (Buffer : Bytes; S : in out Stream; Value : out S8) is
      Raw : U8;
   begin
      Read_U1 (Buffer, S, Raw);
      Value := Decoding.To_S8 (Raw);
   end Read_S1;

   procedure Read_U2le (Buffer : Bytes; S : in out Stream; Value : out U16) is
   begin
      if Available (S, 2) then
         Value := Decoding.U16_LE (Buffer, S.Next);
         S.Next := S.Next + 2;
         S.Unread := 0;
      else
         Value := 0;
         Run_Out (S);
      end if;
   end Read_U2le;

   procedure Read_U2be (Buffer : Bytes; S : in out Stream; Value : out U16) is
   begin
      if Available (S, 2) then
         Value := Decoding.U16_BE (Buffer, S.Next);
         S.Next := S.Next + 2;
         S.Unread := 0;
      else
         Value := 0;
         Run_Out (S);
      end if;
   end Read_U2be;

   procedure Read_U2 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out U16) is
   begin
      case Order is
         when Little_Endian =>
            Read_U2le (Buffer, S, Value);

         when Big_Endian    =>
            Read_U2be (Buffer, S, Value);
      end case;
   end Read_U2;

   procedure Read_S2le (Buffer : Bytes; S : in out Stream; Value : out S16) is
      Raw : U16;
   begin
      Read_U2le (Buffer, S, Raw);
      Value := Decoding.To_S16 (Raw);
   end Read_S2le;

   procedure Read_S2be (Buffer : Bytes; S : in out Stream; Value : out S16) is
      Raw : U16;
   begin
      Read_U2be (Buffer, S, Raw);
      Value := Decoding.To_S16 (Raw);
   end Read_S2be;

   procedure Read_S2 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out S16) is
      Raw : U16;
   begin
      Read_U2 (Buffer, S, Order, Raw);
      Value := Decoding.To_S16 (Raw);
   end Read_S2;

   procedure Read_U4le (Buffer : Bytes; S : in out Stream; Value : out U32) is
   begin
      if Available (S, 4) then
         Value := Decoding.U32_LE (Buffer, S.Next);
         S.Next := S.Next + 4;
         S.Unread := 0;
      else
         Value := 0;
         Run_Out (S);
      end if;
   end Read_U4le;

   procedure Read_U4be (Buffer : Bytes; S : in out Stream; Value : out U32) is
   begin
      if Available (S, 4) then
         Value := Decoding.U32_BE (Buffer, S.Next);
         S.Next := S.Next + 4;
         S.Unread := 0;
      else
         Value := 0;
         Run_Out (S);
      end if;
   end Read_U4be;

   procedure Read_U4 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out U32) is
   begin
      case Order is
         when Little_Endian =>
            Read_U4le (Buffer, S, Value);

         when Big_Endian    =>
            Read_U4be (Buffer, S, Value);
      end case;
   end Read_U4;

   procedure Read_S4le (Buffer : Bytes; S : in out Stream; Value : out S32) is
      Raw : U32;
   begin
      Read_U4le (Buffer, S, Raw);
      Value := Decoding.To_S32 (Raw);
   end Read_S4le;

   procedure Read_S4be (Buffer : Bytes; S : in out Stream; Value : out S32) is
      Raw : U32;
   begin
      Read_U4be (Buffer, S, Raw);
      Value := Decoding.To_S32 (Raw);
   end Read_S4be;

   procedure Read_S4 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out S32) is
      Raw : U32;
   begin
      Read_U4 (Buffer, S, Order, Raw);
      Value := Decoding.To_S32 (Raw);
   end Read_S4;

   procedure Read_U8le (Buffer : Bytes; S : in out Stream; Value : out U64) is
   begin
      if Available (S, 8) then
         Value := Decoding.U64_LE (Buffer, S.Next);
         S.Next := S.Next + 8;
         S.Unread := 0;
      else
         Value := 0;
         Run_Out (S);
      end if;
   end Read_U8le;

   procedure Read_U8be (Buffer : Bytes; S : in out Stream; Value : out U64) is
   begin
      if Available (S, 8) then
         Value := Decoding.U64_BE (Buffer, S.Next);
         S.Next := S.Next + 8;
         S.Unread := 0;
      else
         Value := 0;
         Run_Out (S);
      end if;
   end Read_U8be;

   procedure Read_U8 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out U64) is
   begin
      case Order is
         when Little_Endian =>
            Read_U8le (Buffer, S, Value);

         when Big_Endian    =>
            Read_U8be (Buffer, S, Value);
      end case;
   end Read_U8;

   procedure Read_S8le (Buffer : Bytes; S : in out Stream; Value : out S64) is
      Raw : U64;
   begin
      Read_U8le (Buffer, S, Raw);
      Value := Decoding.To_S64 (Raw);
   end Read_S8le;

   procedure Read_S8be (Buffer : Bytes; S : in out Stream; Value : out S64) is
      Raw : U64;
   begin
      Read_U8be (Buffer, S, Raw);
      Value := Decoding.To_S64 (Raw);
   end Read_S8be;

   procedure Read_S8 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out S64) is
      Raw : U64;
   begin
      Read_U8 (Buffer, S, Order, Raw);
      Value := Decoding.To_S64 (Raw);
   end Read_S8;

   procedure Read_Bytes (S : in out Stream; Count : Length; Data : out Slice) is
   begin
      if Available (S, Count) then
         Data := (First => S.Next, Last => S.Next + Count - 1);
         S.Next := S.Next + Count;
         S.Unread := 0;
      else
         Data := (First => 1, Last => 0);
         Run_Out (S);
      end if;
   end Read_Bytes;

   procedure Read_Bytes_Full (S : in out Stream; Data : out Slice) is
   begin
      if S.State = Success then
         Data := (First => S.Next, Last => S.Last);
         S.Next := S.Last + 1;
         S.Unread := 0;
      else
         Data := (First => 1, Last => 0);
      end if;
   end Read_Bytes_Full;

   procedure Read_Bytes_Term
     (Buffer    : Bytes;
      S         : in out Stream;
      Term      : Byte;
      Include   : Boolean;
      Consume   : Boolean;
      EOS_Error : Boolean;
      Data      : out Slice)
   is
      Found : Length;
   begin
      Data := (First => 1, Last => 0);
      if S.State /= Success then
         return;
      end if;

      Found := Find (Buffer, (First => S.Next, Last => S.Last), Term);
      if Found <= S.Last then
         Data := (First => S.Next, Last => (if Include then Found else Found - 1));
         S.Unread := 0;
         S.Next := (if Consume then Found + 1 else Found);
      elsif EOS_Error then
         Run_Out (S);
      else
         Data := (First => S.Next, Last => S.Last);
         S.Unread := 0;
         S.Next := S.Last + 1;
      end if;
   end Read_Bytes_Term;

   procedure Read_Bytes_Term_Multi
     (Buffer    : Bytes;
      S         : in out Stream;
      Term      : Bytes;
      Include   : Boolean;
      Consume   : Boolean;
      EOS_Error : Boolean;
      Data      : out Slice)
   is
      Found : Length;
   begin
      Data := (First => 1, Last => 0);
      if S.State /= Success then
         return;
      end if;

      Found := Byte_Arrays.Find_Multi (Buffer, (First => S.Next, Last => S.Last), Term);
      if Found <= S.Last then
         Data := (First => S.Next, Last => (if Include then Found + (Term'Length - 1) else Found - 1));
         S.Unread := 0;
         S.Next := (if Consume then Found + Term'Length else Found);
      elsif EOS_Error then
         Run_Out (S);
      else
         Data := (First => S.Next, Last => S.Last);
         S.Unread := 0;
         S.Next := S.Last + 1;
      end if;
   end Read_Bytes_Term_Multi;

   procedure Read_Elements (S : in out Stream; Count : Length; Element_Size : Length; Data : out Slice) is
   begin
      if S.State = Success and then Count <= (S.Last - S.Next + 1) / Element_Size then
         Data := (First => S.Next, Last => S.Next + Count * Element_Size - 1);
         S.Unread := 0;
         S.Next := Data.Last + 1;
      else
         Data := (First => 1, Last => 0);
         Run_Out (S);
      end if;
   end Read_Elements;

   procedure Read_Elements_Full (S : in out Stream; Element_Size : Length; Data : out Slice) is
   begin
      if S.State = Success and then (S.Last - S.Next + 1) mod Element_Size = 0 then
         Data := (First => S.Next, Last => S.Last);
         S.Unread := 0;
         S.Next := S.Last + 1;
      else
         Data := (First => 1, Last => 0);
         Run_Out (S);
      end if;
   end Read_Elements_Full;

   procedure Read_Contents (Buffer : Bytes; S : in out Stream; Expected : Bytes) is
      Data : Slice;
   begin
      Read_Bytes (S, Expected'Length, Data);
      if S.State = Success and then not Equal (Buffer, Data, Expected) then
         S.State := Validation_Not_Equal;
      end if;
   end Read_Contents;

   procedure Substream (Buffer : Bytes; S : in out Stream; Count : Length; Sub : out Stream) is
      --  Buffer only serves the contract
      pragma Warnings (Off, Buffer);
   begin
      if Available (S, Count) then
         Sub := (First => S.Next, Last => S.Next + Count - 1, Next => S.Next, State => Success, Unread => 0);
         S.Next := S.Next + Count;
         S.Unread := 0;
      else
         Run_Out (S);
         Sub := (First => 1, Last => 0, Next => 1, State => S.State, Unread => 0);
      end if;
   end Substream;

   procedure Join (S : in out Stream; Sub : Stream) is
   begin
      if S.State = Success then
         S.State := Sub.State;
      end if;
   end Join;

   procedure Align_To_Byte (S : in out Stream) is
   begin
      S.Unread := 0;
   end Align_To_Byte;

   procedure Read_Bits_Int_Be (Buffer : Bytes; S : in out Stream; Count : Bit_Count; Value : out U64) is
      Left : constant Bit_Remainder := S.Unread;
   begin
      Value := 0;
      if S.State /= Success then
         return;
      end if;

      if Count <= Left then
         --  Everything comes from the byte read last, whose Left least
         --  significant bits are unread
         Value := Shift_Right (U64 (Buffer (S.Next - 1)), Left - Count) and Mask (Count);
         S.Unread := Left - Count;
         return;
      end if;

      declare
         Whole : constant Length := Bytes_Needed (Count, Left);
         Spare : constant Bit_Remainder := Left_After (Count, Left);
         Acc   : U64 := 0;
      begin
         if Whole - 1 > S.Last - S.Next then
            Run_Out (S);
            return;
         end if;

         if Left > 0 then
            Acc := U64 (Buffer (S.Next - 1)) and Mask (Left);
         end if;

         --  All new bytes but the last are taken whole
         for I in 0 .. Whole - 2 loop
            Acc := Shift_Left (Acc, 8) or U64 (Buffer (S.Next + I));
         end loop;

         --  The last one gives its most significant bits; Spare are left
         Acc := Shift_Left (Acc, 8 - Spare) or Shift_Right (U64 (Buffer (S.Next + Whole - 1)), Spare);

         Value := Acc and Mask (Count);
         S.Next := S.Next + Whole;
         S.Unread := Spare;
      end;
   end Read_Bits_Int_Be;

   procedure Read_Bits_Int_Le (Buffer : Bytes; S : in out Stream; Count : Bit_Count; Value : out U64) is
      Left : constant Bit_Remainder := S.Unread;
   begin
      Value := 0;
      if S.State /= Success then
         return;
      end if;

      if Count <= Left then
         --  Everything comes from the byte read last, whose Left most
         --  significant bits are unread
         Value := Shift_Right (U64 (Buffer (S.Next - 1)), 8 - Left) and Mask (Count);
         S.Unread := Left - Count;
         return;
      end if;

      declare
         Whole : constant Length := Bytes_Needed (Count, Left);
         Spare : constant Bit_Remainder := Left_After (Count, Left);
         Acc   : U64 := 0;
         Shift : Natural := Left;
      begin
         if Whole - 1 > S.Last - S.Next then
            Run_Out (S);
            return;
         end if;

         if Left > 0 then
            Acc := Shift_Right (U64 (Buffer (S.Next - 1)), 8 - Left);
         end if;

         --  Each new byte goes above the bits collected so far.  Bits that
         --  do not fit into 64 are beyond Count and fall away.
         for I in 0 .. Whole - 1 loop
            pragma Loop_Invariant (Shift = Left + 8 * Natural (I));
            Acc := Acc or Shift_Left (U64 (Buffer (S.Next + I)), Shift);
            Shift := Shift + 8;
         end loop;

         Value := Acc and Mask (Count);
         S.Next := S.Next + Whole;
         S.Unread := Spare;
      end;
   end Read_Bits_Int_Le;

end Kaitai.Streams;
