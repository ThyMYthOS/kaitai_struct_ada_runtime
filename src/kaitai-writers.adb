package body Kaitai.Writers
  with SPARK_Mode
is

   --  True if Count bytes can be written at the current position
   function Available (W : Writer; Count : Length) return Boolean
   is (W.State = Success and then Count <= W.Last - W.Next + 1)
   with Inline;

   --  Record that the writer ran out of space, unless it has failed before.
   --  There is no contract on purpose: GNATprove then analyses the body in
   --  the context of each call.
   procedure Run_Out (W : in out Writer)
   with Inline;

   procedure Run_Out (W : in out Writer) is
   begin
      if W.State = Success then
         W.State := Capacity_Exceeded;
      end if;
   end Run_Out;

   --  Move on by Count bytes that are there, ending a bit field in progress
   --  or beginning one that leaves Free bits free, and extending the written
   --  part if need be.  No contract, as above.
   procedure Step (W : in out Writer; Count : Length; Free : Bit_Remainder := 0)
   with Inline;

   procedure Step (W : in out Writer; Count : Length; Free : Bit_Remainder := 0) is
   begin
      if W.Next + Count > W.High then
         W.High := W.Next + Count;
      end if;
      W.Next := W.Next + Count;
      W.Free := Free;
   end Step;

   --  The Store_ procedures are those of Kaitai.Encoding once more, and
   --  To_Raw_S64 is its To_U64.  A body of this package that is inlined into
   --  a serializer can only take along what this package holds itself: the
   --  compiler does not look into the body of a package the serializer does
   --  not name.

   procedure Store_U8 (Target : in out Bytes; From : Index; Value : U8)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 1),
     Post => Decoding.U8_At (Target, From) = Value and then Kept (Target'Old, Target, From, 1);

   procedure Store_U16_LE (Target : in out Bytes; From : Index; Value : U16)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 2),
     Post => Decoding.U16_LE (Target, From) = Value and then Kept (Target'Old, Target, From, 2);

   procedure Store_U16_BE (Target : in out Bytes; From : Index; Value : U16)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 2),
     Post => Decoding.U16_BE (Target, From) = Value and then Kept (Target'Old, Target, From, 2);

   procedure Store_U32_LE (Target : in out Bytes; From : Index; Value : U32)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 4),
     Post => Decoding.U32_LE (Target, From) = Value and then Kept (Target'Old, Target, From, 4);

   procedure Store_U32_BE (Target : in out Bytes; From : Index; Value : U32)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 4),
     Post => Decoding.U32_BE (Target, From) = Value and then Kept (Target'Old, Target, From, 4);

   procedure Store_U64_LE (Target : in out Bytes; From : Index; Value : U64)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 8),
     Post => Decoding.U64_LE (Target, From) = Value and then Kept (Target'Old, Target, From, 8);

   procedure Store_U64_BE (Target : in out Bytes; From : Index; Value : U64)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 8),
     Post => Decoding.U64_BE (Target, From) = Value and then Kept (Target'Old, Target, From, 8);

   procedure Store_U8 (Target : in out Bytes; From : Index; Value : U8) is
   begin
      Target (From) := Value;
   end Store_U8;

   procedure Store_U16_LE (Target : in out Bytes; From : Index; Value : U16) is
   begin
      Target (From) := U8 (Value and 16#FF#);
      Target (From + 1) := U8 (Shift_Right (Value, 8));
   end Store_U16_LE;

   procedure Store_U16_BE (Target : in out Bytes; From : Index; Value : U16) is
   begin
      Target (From) := U8 (Shift_Right (Value, 8));
      Target (From + 1) := U8 (Value and 16#FF#);
   end Store_U16_BE;

   procedure Store_U32_LE (Target : in out Bytes; From : Index; Value : U32) is
   begin
      Target (From) := U8 (Value and 16#FF#);
      Target (From + 1) := U8 (Shift_Right (Value, 8) and 16#FF#);
      Target (From + 2) := U8 (Shift_Right (Value, 16) and 16#FF#);
      Target (From + 3) := U8 (Shift_Right (Value, 24));
   end Store_U32_LE;

   procedure Store_U32_BE (Target : in out Bytes; From : Index; Value : U32) is
   begin
      Target (From) := U8 (Shift_Right (Value, 24));
      Target (From + 1) := U8 (Shift_Right (Value, 16) and 16#FF#);
      Target (From + 2) := U8 (Shift_Right (Value, 8) and 16#FF#);
      Target (From + 3) := U8 (Value and 16#FF#);
   end Store_U32_BE;

   procedure Store_U64_LE (Target : in out Bytes; From : Index; Value : U64) is
   begin
      Store_U32_LE (Target, From, U32 (Value and 16#FFFF_FFFF#));
      Store_U32_LE (Target, From + 4, U32 (Shift_Right (Value, 32)));
   end Store_U64_LE;

   procedure Store_U64_BE (Target : in out Bytes; From : Index; Value : U64) is
   begin
      Store_U32_BE (Target, From, U32 (Shift_Right (Value, 32)));
      Store_U32_BE (Target, From + 4, U32 (Value and 16#FFFF_FFFF#));
   end Store_U64_BE;

   function To_Raw_S64 (Value : S64) return U64
   with Inline, Post => Decoding.To_S64 (To_Raw_S64'Result) = Value;

   function To_Raw_S64 (Value : S64) return U64 is
   begin
      if Value >= 0 then
         pragma Assert (U64 (Value) < 2**63);
         pragma Assert (Decoding.To_S64 (U64 (Value)) = Value);
         return U64 (Value);
      end if;
      declare
         Low : constant U64 := U64 (Value - S64'First);
      begin
         pragma Assert (Low < 2**63);
         pragma Assert (S64 (Low) = Value - S64'First);
         pragma Assert (Low + 2**63 >= 2**63);
         pragma Assert (Low + 2**63 - 2**63 = Low);
         pragma Assert (Decoding.To_S64 (Low + 2**63) = Value);
         return Low + 2**63;
      end;
   end To_Raw_S64;

   --  Set Count bytes at From to Value
   procedure Fill (Target : in out Bytes; From : Length; Count : Length; Value : Byte)
   with
     Pre  => Decoding.Has (Target, From, Count),
     Post => Kept (Target'Old, Target, From, Count) and then Filled (Target, From, Count, Value);

   procedure Fill (Target : in out Bytes; From : Length; Count : Length; Value : Byte) is
   begin
      for I in 0 .. Count - 1 loop
         Target (From + I) := Value;
         pragma Loop_Invariant (Kept (Target'Loop_Entry, Target, From, I + 1));
         pragma Loop_Invariant (for all J in 0 .. I => Target (From + J) = Value);
      end loop;
   end Fill;

   --  Copy Source to the bytes at From
   procedure Copy (Target : in out Bytes; From : Length; Source : Bytes)
   with
     Pre  => Decoding.Has (Target, From, Length (Source'Length)),
     Post => Kept (Target'Old, Target, From, Length (Source'Length)) and then Stored (Target, From, Source);

   procedure Copy (Target : in out Bytes; From : Length; Source : Bytes) is
   begin
      for I in 0 .. Length (Source'Length) - 1 loop
         Target (From + I) := Source (Source'First + I);
         pragma Loop_Invariant (Kept (Target'Loop_Entry, Target, From, I + 1));
         pragma Loop_Invariant (for all J in 0 .. I => Target (From + J) = Source (Source'First + J));
      end loop;
   end Copy;

   function Open (Target : Bytes) return Writer is
   begin
      if Target'Length = 0 then
         return (First => 1, Last => 0, Next => 1, High => 1, State => Success, Free => 0);
      else
         return
           (First => Target'First,
            Last  => Target'Last,
            Next  => Target'First,
            High  => Target'First,
            State => Success,
            Free  => 0);
      end if;
   end Open;

   procedure Seek (W : in out Writer; To : Length) is
   begin
      if W.State = Success and then To <= W.Last - W.First + 1 then
         W.Free := 0;
         if W.First + To > W.High then
            W.High := W.First + To;
         end if;
         W.Next := W.First + To;
      else
         Run_Out (W);
      end if;
   end Seek;

   procedure Skip (Target : in out Bytes; W : in out Writer; Count : Length) is
   begin
      if Available (W, Count) then
         Fill (Target, W.Next, Count, 0);
         Step (W, Count);
      else
         Run_Out (W);
      end if;
   end Skip;

   procedure Fail (W : in out Writer; Reason : Status_Kind) is
   begin
      if W.State = Success then
         W.State := Reason;
      end if;
   end Fail;

   procedure Write_U1 (Target : in out Bytes; W : in out Writer; Value : U8) is
   begin
      if Available (W, 1) then
         Store_U8 (Target, W.Next, Value);
         Step (W, 1);
      else
         Run_Out (W);
      end if;
   end Write_U1;

   procedure Write_S1 (Target : in out Bytes; W : in out Writer; Value : S8) is
   begin
      Write_U1 (Target, W, To_U8 (Value));
   end Write_S1;

   procedure Write_U2le (Target : in out Bytes; W : in out Writer; Value : U16) is
   begin
      if Available (W, 2) then
         Store_U16_LE (Target, W.Next, Value);
         Step (W, 2);
      else
         Run_Out (W);
      end if;
   end Write_U2le;

   procedure Write_U2be (Target : in out Bytes; W : in out Writer; Value : U16) is
   begin
      if Available (W, 2) then
         Store_U16_BE (Target, W.Next, Value);
         Step (W, 2);
      else
         Run_Out (W);
      end if;
   end Write_U2be;

   procedure Write_U2 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : U16) is
   begin
      case Order is
         when Little_Endian =>
            Write_U2le (Target, W, Value);

         when Big_Endian    =>
            Write_U2be (Target, W, Value);
      end case;
   end Write_U2;

   procedure Write_S2le (Target : in out Bytes; W : in out Writer; Value : S16) is
   begin
      Write_U2le (Target, W, To_U16 (Value));
   end Write_S2le;

   procedure Write_S2be (Target : in out Bytes; W : in out Writer; Value : S16) is
   begin
      Write_U2be (Target, W, To_U16 (Value));
   end Write_S2be;

   procedure Write_S2 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : S16) is
   begin
      Write_U2 (Target, W, Order, To_U16 (Value));
   end Write_S2;

   procedure Write_U4le (Target : in out Bytes; W : in out Writer; Value : U32) is
   begin
      if Available (W, 4) then
         Store_U32_LE (Target, W.Next, Value);
         Step (W, 4);
      else
         Run_Out (W);
      end if;
   end Write_U4le;

   procedure Write_U4be (Target : in out Bytes; W : in out Writer; Value : U32) is
   begin
      if Available (W, 4) then
         Store_U32_BE (Target, W.Next, Value);
         Step (W, 4);
      else
         Run_Out (W);
      end if;
   end Write_U4be;

   procedure Write_U4 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : U32) is
   begin
      case Order is
         when Little_Endian =>
            Write_U4le (Target, W, Value);

         when Big_Endian    =>
            Write_U4be (Target, W, Value);
      end case;
   end Write_U4;

   procedure Write_S4le (Target : in out Bytes; W : in out Writer; Value : S32) is
   begin
      Write_U4le (Target, W, To_U32 (Value));
   end Write_S4le;

   procedure Write_S4be (Target : in out Bytes; W : in out Writer; Value : S32) is
   begin
      Write_U4be (Target, W, To_U32 (Value));
   end Write_S4be;

   procedure Write_S4 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : S32) is
   begin
      Write_U4 (Target, W, Order, To_U32 (Value));
   end Write_S4;

   procedure Write_U8le (Target : in out Bytes; W : in out Writer; Value : U64) is
   begin
      if Available (W, 8) then
         Store_U64_LE (Target, W.Next, Value);
         Step (W, 8);
      else
         Run_Out (W);
      end if;
   end Write_U8le;

   procedure Write_U8be (Target : in out Bytes; W : in out Writer; Value : U64) is
   begin
      if Available (W, 8) then
         Store_U64_BE (Target, W.Next, Value);
         Step (W, 8);
      else
         Run_Out (W);
      end if;
   end Write_U8be;

   procedure Write_U8 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : U64) is
   begin
      case Order is
         when Little_Endian =>
            Write_U8le (Target, W, Value);

         when Big_Endian    =>
            Write_U8be (Target, W, Value);
      end case;
   end Write_U8;

   procedure Write_S8le (Target : in out Bytes; W : in out Writer; Value : S64) is
   begin
      Write_U8le (Target, W, To_Raw_S64 (Value));
   end Write_S8le;

   procedure Write_S8be (Target : in out Bytes; W : in out Writer; Value : S64) is
   begin
      Write_U8be (Target, W, To_Raw_S64 (Value));
   end Write_S8be;

   procedure Write_S8 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : S64) is
   begin
      Write_U8 (Target, W, Order, To_Raw_S64 (Value));
   end Write_S8;

   procedure Align_To_Byte (W : in out Writer) is
   begin
      W.Free := 0;
   end Align_To_Byte;

   procedure Write_Bits_Int_Be (Target : in out Bytes; W : in out Writer; Count : Bit_Count; Value : U64) is
      Before : constant Bytes := Target
      with Ghost;
      Left   : constant Bit_Remainder := W.Free;
      W_Old  : constant Writer := W
      with Ghost;
   begin
      if W.State /= Success then
         pragma Assert (Produced_Bits (W_Old, W, Count, Value));
         return;
      end if;

      if Value > Mask (Count) then
         W.State := Validation_Greater_Than;
         pragma Assert (Produced_Bits (W_Old, W, Count, Value));
         return;
      end if;

      if Count <= Left then
         --  Everything goes into the byte begun last, whose Left least
         --  significant bits are free
         Target (W.Next - 1) :=
           (Target (W.Next - 1) and not U8 (Mask (Left))) or U8 (Shift_Left (Value, Left - Count) and 16#FF#);
         W.Free := Left - Count;
         pragma Assert (Produced_Bits (W_Old, W, Count, Value));
         return;
      end if;

      declare
         Open      : constant Length := (if Left > 0 then 1 else 0);
         Whole     : constant Length := Bytes_Needed (Count, Left);
         Spare     : constant Bit_Remainder := Left_After (Count, Left);
         Rest_Bits : constant Natural := Count - Left;
      begin
         if Whole > W.Last - W.Next + 1 then
            Run_Out (W);
            pragma Assert (Produced_Bits (W_Old, W, Count, Value));
            return;
         end if;
         pragma Assert (Whole in 1 .. 8);
         pragma Assert (8 * Natural (Whole) = Rest_Bits + Spare);

         --  The most significant bits of the value fill the byte begun last
         if Left > 0 then
            Target (W.Next - 1) :=
              (Target (W.Next - 1) and not U8 (Mask (Left))) or U8 (Shift_Right (Value, Rest_Bits) and 16#FF#);
         end if;

         --  All new bytes but the last are taken whole
         for I in 0 .. Whole - 2 loop
            Target (W.Next + I) := U8 (Shift_Right (Value, Rest_Bits - 8 * (Natural (I) + 1)) and 16#FF#);
            pragma Loop_Invariant (Kept (Before, Target, W.Next - Open, Open + (I + 1)));
         end loop;

         --  The last one gets the least significant bits at its top; Spare
         --  of its bits are left free
         Target (W.Next + (Whole - 1)) := U8 (Shift_Left (Value, Spare) and 16#FF#);
         Step (W, Whole, Spare);
      end;
   end Write_Bits_Int_Be;

   procedure Write_Bits_Int_Le (Target : in out Bytes; W : in out Writer; Count : Bit_Count; Value : U64) is
      Before : constant Bytes := Target
      with Ghost;
      Left   : constant Bit_Remainder := W.Free;
      W_Old  : constant Writer := W
      with Ghost;
   begin
      if W.State /= Success then
         pragma Assert (Produced_Bits (W_Old, W, Count, Value));
         return;
      end if;

      if Value > Mask (Count) then
         W.State := Validation_Greater_Than;
         pragma Assert (Produced_Bits (W_Old, W, Count, Value));
         return;
      end if;

      if Count <= Left then
         --  Everything goes into the byte begun last, whose Left most
         --  significant bits are free
         Target (W.Next - 1) :=
           (Target (W.Next - 1) and U8 (Mask (8 - Left))) or U8 (Shift_Left (Value, 8 - Left) and 16#FF#);
         W.Free := Left - Count;
         pragma Assert (Produced_Bits (W_Old, W, Count, Value));
         return;
      end if;

      declare
         Open      : constant Length := (if Left > 0 then 1 else 0);
         Whole     : constant Length := Bytes_Needed (Count, Left);
         Spare     : constant Bit_Remainder := Left_After (Count, Left);
         Rest_Bits : constant Natural := Count - Left;
      begin
         if Whole > W.Last - W.Next + 1 then
            Run_Out (W);
            pragma Assert (Produced_Bits (W_Old, W, Count, Value));
            return;
         end if;
         pragma Assert (Whole in 1 .. 8);
         pragma Assert (8 * Natural (Whole) = Rest_Bits + Spare);
         pragma Assert (Left + 8 * (Natural (Whole) - 1) < 64);

         --  The least significant bits of the value fill the byte begun
         --  last, from its first free bit on
         if Left > 0 then
            Target (W.Next - 1) :=
              (Target (W.Next - 1) and U8 (Mask (8 - Left))) or U8 (Shift_Left (Value, 8 - Left) and 16#FF#);
         end if;

         --  Each new byte takes the next eight bits.  The bits above Count
         --  are zero, which leaves the last byte's free bits zero.
         for I in 0 .. Whole - 1 loop
            Target (W.Next + I) := U8 (Shift_Right (Value, Left + 8 * Natural (I)) and 16#FF#);
            pragma Loop_Invariant (Kept (Before, Target, W.Next - Open, Open + (I + 1)));
         end loop;

         Step (W, Whole, Spare);
      end;
   end Write_Bits_Int_Le;

   procedure Write_Bytes (Target : in out Bytes; W : in out Writer; Source : Bytes) is
   begin
      if Available (W, Length (Source'Length)) then
         Copy (Target, W.Next, Source);
         Step (W, Length (Source'Length));
      else
         Run_Out (W);
      end if;
   end Write_Bytes;

   procedure Write_Bytes_Term (Target : in out Bytes; W : in out Writer; Source : Bytes; Term : Byte) is
      Before : constant Bytes := Target
      with Ghost;
      Count  : constant Length := Length (Source'Length);
   begin
      if W.State /= Success then
         return;
      end if;

      for I in Source'Range loop
         if Source (I) = Term then
            W.State := Validation_Expr;
            return;
         end if;
         pragma Loop_Invariant (for all J in Source'First .. I => Source (J) /= Term);
      end loop;

      if Count < W.Last - W.Next + 1 then
         Copy (Target, W.Next, Source);
         Target (W.Next + Count) := Term;
         pragma Assert (Kept (Before, Target, W.Next, Count + 1));
         Step (W, Count + 1);
      else
         Run_Out (W);
      end if;
   end Write_Bytes_Term;

   procedure Write_Padded (Target : in out Bytes; W : in out Writer; Source : Bytes; Size : Length; Pad : Byte) is
      Before : constant Bytes := Target
      with Ghost;
      Count  : constant Length := Length (Source'Length);
   begin
      if W.State /= Success then
         return;
      end if;

      if Count > Size then
         W.State := Validation_Greater_Than;
      elsif Size <= W.Last - W.Next + 1 then
         Copy (Target, W.Next, Source);
         Fill (Target, W.Next + Count, Size - Count, Pad);
         pragma Assert (Kept (Before, Target, W.Next, Size));
         Step (W, Size);
      else
         Run_Out (W);
      end if;
   end Write_Padded;

   procedure Subwriter (Target : in out Bytes; W : in out Writer; Count : Length; Sub : out Writer) is
   begin
      if Available (W, Count) then
         Fill (Target, W.Next, Count, 0);
         Sub :=
           (First => W.Next, Last => W.Next + Count - 1, Next => W.Next, High => W.Next, State => Success, Free => 0);
         Step (W, Count);
      else
         Run_Out (W);
         Sub := (First => 1, Last => 0, Next => 1, High => 1, State => W.State, Free => 0);
      end if;
   end Subwriter;

   procedure Join (W : in out Writer; Sub : Writer) is
   begin
      if W.State = Success then
         W.State := Sub.State;
      end if;
   end Join;

end Kaitai.Writers;
