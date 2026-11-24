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

   function Open (Buffer : Bytes) return Stream is
   begin
      if Buffer'Length = 0 then
         return (First => 1, Last => 0, Next => 1, State => Success, Unread => 0);
      else
         return (First => Buffer'First, Last => Buffer'Last, Next => Buffer'First, State => Success, Unread => 0);
      end if;
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
