package body Kaitai.Strings
  with SPARK_Mode
is

   subtype Len is Kaitai.Types.Length;

   --  ASCII and Single_Byte

   function All_Below_128 (Buffer : Bytes; Item : Slice) return Boolean
   with
     Pre  => Within (Item, Buffer),
     Post => All_Below_128'Result = (for all I in Item.First .. Item.Last => Buffer (I) < 128)
   is
   begin
      for I in Item.First .. Item.Last loop
         if Buffer (I) >= 128 then
            return False;
         end if;
         pragma Loop_Invariant (for all J in Item.First .. I => Buffer (J) < 128);
      end loop;
      return True;
   end All_Below_128;

   --  UTF-8

   --  The number of bytes of the sequence that starts at Position, which is
   --  0 if there is no well formed one that ends at or before Last
   function UTF_8_Sequence (Buffer : Bytes; Position, Last : Len) return Len
   with
     Pre  => Position in Buffer'Range and then Last in Position .. Buffer'Last,
     Post => UTF_8_Sequence'Result <= 4 and then UTF_8_Sequence'Result <= Last - Position + 1
   is
      Lead : constant Byte := Buffer (Position);
      Size : Len;
      Low  : Byte := 16#80#;  --  range of the second byte
      High : Byte := 16#BF#;
   begin
      case Lead is
         when 16#00# .. 16#7F#                    =>
            return 1;

         when 16#C2# .. 16#DF#                    =>
            Size := 2;

         when 16#E0#                              =>
            Size := 3;
            Low := 16#A0#;

         when 16#E1# .. 16#EC# | 16#EE# .. 16#EF# =>
            Size := 3;

         when 16#ED#                              =>
            Size := 3;
            High := 16#9F#;

         when 16#F0#                              =>
            Size := 4;
            Low := 16#90#;

         when 16#F1# .. 16#F3#                    =>
            Size := 4;

         when 16#F4#                              =>
            Size := 4;
            High := 16#8F#;

         when others                              =>
            return 0;
      end case;

      if Last - Position < Size - 1 then
         return 0;
      end if;
      if Buffer (Position + 1) not in Low .. High then
         return 0;
      end if;
      for K in 2 .. Size - 1 loop
         if Buffer (Position + K) not in 16#80# .. 16#BF# then
            return 0;
         end if;
      end loop;
      return Size;
   end UTF_8_Sequence;

   function UTF_8_Valid (Buffer : Bytes; Item : Slice) return Boolean
   with Pre => Within (Item, Buffer), Post => (if Is_Empty (Item) then UTF_8_Valid'Result)
   is
      Position : Len := Item.First;
      Count    : Len;
   begin
      while Position <= Item.Last loop
         pragma Loop_Invariant (Position in Item.First .. Item.Last);
         pragma Loop_Variant (Increases => Position);
         Count := UTF_8_Sequence (Buffer, Position, Item.Last);
         if Count = 0 then
            return False;
         end if;
         Position := Position + Count;
      end loop;
      return True;
   end UTF_8_Valid;

   function UTF_8_Length (Buffer : Bytes; Item : Slice) return Len
   with Pre => Within (Item, Buffer), Post => UTF_8_Length'Result <= Size (Item)
   is
      Count : Len := 0;
   begin
      for I in Item.First .. Item.Last loop
         if Buffer (I) not in 16#80# .. 16#BF# then
            Count := Count + 1;
         end if;
         pragma Loop_Invariant (Count <= I - Item.First + 1);
      end loop;
      return Count;
   end UTF_8_Length;

   --  UTF-16

   function Unit (Buffer : Bytes; Position : Len; Order : Byte_Order) return U16
   with Pre => Position in Buffer'Range and then Position < Buffer'Last
   is
   begin
      case Order is
         when Little_Endian =>
            return U16 (Buffer (Position)) + 256 * U16 (Buffer (Position + 1));

         when Big_Endian    =>
            return 256 * U16 (Buffer (Position)) + U16 (Buffer (Position + 1));
      end case;
   end Unit;

   function UTF_16_Valid (Buffer : Bytes; Item : Slice; Order : Byte_Order) return Boolean
   with Pre => Within (Item, Buffer), Post => (if Is_Empty (Item) then UTF_16_Valid'Result)
   is
      Position : Len := Item.First;
      First    : U16;
   begin
      while Position <= Item.Last loop
         pragma Loop_Invariant (Position in Item.First .. Item.Last);
         pragma Loop_Variant (Increases => Position);
         if Item.Last - Position < 1 then
            return False;  --  half a unit

         end if;
         First := Unit (Buffer, Position, Order);
         if First in 16#D800# .. 16#DBFF# then
            if Item.Last - Position < 3 or else Unit (Buffer, Position + 2, Order) not in 16#DC00# .. 16#DFFF# then
               return False;
            end if;
            Position := Position + 4;
         elsif First in 16#DC00# .. 16#DFFF# then
            return False;
         else
            Position := Position + 2;
         end if;
      end loop;
      return True;
   end UTF_16_Valid;

   function UTF_16_Length (Buffer : Bytes; Item : Slice; Order : Byte_Order) return Len
   with Pre => Within (Item, Buffer), Post => UTF_16_Length'Result <= Size (Item) / 2
   is
      Position : Len := Item.First;
      Count    : Len := 0;
   begin
      while Position < Item.Last loop
         pragma Loop_Invariant (Position in Item.First .. Item.Last);
         pragma Loop_Invariant ((Position - Item.First) mod 2 = 0);
         pragma Loop_Invariant (Count <= (Position - Item.First) / 2);
         pragma Loop_Variant (Increases => Position);
         if Unit (Buffer, Position, Order) not in 16#DC00# .. 16#DFFF# then
            Count := Count + 1;
         end if;
         Position := Position + 2;
      end loop;
      return Count;
   end UTF_16_Length;

   --  Public operations

   function Is_Valid (Buffer : Bytes; Item : Slice; Enc : Encoding) return Boolean is
   begin
      case Enc is
         when US_ASCII    =>
            return All_Below_128 (Buffer, Item);

         when UTF_8       =>
            return UTF_8_Valid (Buffer, Item);

         when UTF_16LE    =>
            return UTF_16_Valid (Buffer, Item, Little_Endian);

         when UTF_16BE    =>
            return UTF_16_Valid (Buffer, Item, Big_Endian);

         when Single_Byte =>
            return True;
      end case;
   end Is_Valid;

   function Character_Count (Buffer : Bytes; Item : Slice; Enc : Encoding) return Kaitai.Types.Length is
   begin
      case Enc is
         when US_ASCII | Single_Byte =>
            return Size (Item);

         when UTF_8                  =>
            return UTF_8_Length (Buffer, Item);

         when UTF_16LE               =>
            return UTF_16_Length (Buffer, Item, Little_Endian);

         when UTF_16BE               =>
            return UTF_16_Length (Buffer, Item, Big_Endian);
      end case;
   end Character_Count;

   --  The value of a digit in any base up to 36; -1 if C is no digit
   function Digit_Value (C : Byte) return S64
   is (case C is
         when 48 .. 57  => S64 (C) - 48,
         when 65 .. 90  => S64 (C) - 55,
         when 97 .. 122 => S64 (C) - 87,
         when others    => -1)
   with Post => Digit_Value'Result in -1 .. 35;

   type Parsed is record
      Valid : Boolean;
      Value : S64;
   end record;

   --  Compute whether Item is a number and, if so, its value.  The digits
   --  are accumulated as a negative number, because that range includes
   --  S64'First, which is the one value that has no positive counterpart.
   function Parse (Buffer : Bytes; Item : Slice; Base : S64) return Parsed
   with
     Pre  => Within (Item, Buffer),
     Post => (if Is_Empty (Item) or else Base not in 2 .. 36 then not Parse'Result.Valid)
   is
      Negative : Boolean := False;
      Start    : Len := Item.First;
      Accum    : S64 := 0;
      Digit    : S64;
   begin
      if Is_Empty (Item) or else Base not in 2 .. 36 then
         return (Valid => False, Value => 0);
      end if;
      if Buffer (Item.First) = 45 then
         Negative := True;
         Start := Item.First + 1;
      elsif Buffer (Item.First) = 43 then
         Start := Item.First + 1;
      end if;
      if Start > Item.Last then
         return (Valid => False, Value => 0);  --  no digit

      end if;
      for I in Start .. Item.Last loop
         pragma Loop_Invariant (Accum <= 0);
         Digit := Digit_Value (Buffer (I));
         if Digit < 0 or else Digit >= Base then
            return (Valid => False, Value => 0);
         end if;
         --  Accum * Base - Digit >= S64'First, rounded up for the division
         if Accum < (S64'First + Digit) / Base then
            return (Valid => False, Value => 0);
         end if;
         Accum := Accum * Base - Digit;
      end loop;
      if Negative then
         return (Valid => True, Value => Accum);
      elsif Accum /= S64'First then
         return (Valid => True, Value => -Accum);
      else
         return (Valid => False, Value => 0);
      end if;
   end Parse;

   function To_Integer_OK (Buffer : Bytes; Item : Slice; Base : S64) return Boolean
   is (Parse (Buffer, Item, Base).Valid);

   function To_Integer (Buffer : Bytes; Item : Slice; Base : S64) return S64
   is (Parse (Buffer, Item, Base).Value);

   procedure Put_Integer (Value : S64; Target : in out Bytes; Last : out Kaitai.Types.Length) is
      --  S64'First has 19 digits, as 10**19 is the first power of ten
      --  above S64'Last
      Digits_Of : Bytes (1 .. 19) := (others => 48);
      Count     : Len := 0;
      Rest      : S64 := (if Value > 0 then -Value else Value);
      Start     : constant Len := Target'First + (if Value < 0 then 1 else 0);
      Position  : Len := Start;
   begin
      for K in Len range 1 .. 19 loop
         pragma Loop_Invariant (Count = K - 1);
         pragma Loop_Invariant (Rest <= 0);
         pragma Loop_Invariant ((Rest = 0) = (Value = 0));
         pragma Loop_Invariant (if K > 1 then Rest /= 0);
         pragma Loop_Invariant (for all J in Digits_Of'Range => Digits_Of (J) in 48 .. 57);
         Digits_Of (K) := Byte (-(Rest rem 10)) + 48;
         Rest := Rest / 10;
         Count := K;
         exit when Rest = 0;
      end loop;
      pragma Assert (Count in 1 .. 19);
      pragma Assert (if Value = 0 then Count = 1);
      if Value < 0 then
         Target (Target'First) := 45;
      end if;
      for K in reverse 1 .. Count loop
         pragma Loop_Invariant (Position = Start + (Count - K));
         pragma Loop_Invariant (for all I in Start .. Position - 1 => Target (I) in 48 .. 57);
         pragma Loop_Invariant (if Value < 0 then Target (Target'First) = 45);
         pragma Loop_Invariant (for all I in Position .. Target'Last => Target (I) = Target'Loop_Entry (I));
         Target (Position) := Digits_Of (K);
         Position := Position + 1;
      end loop;
      Last := Position - 1;
   end Put_Integer;

   function Equal_Literal (Buffer : Bytes; Item : Slice; Literal : String) return Boolean is
   begin
      if Size (Item) /= Len (Literal'Length) then
         return False;
      end if;
      for I in Item.First .. Item.Last loop
         if Buffer (I) /= Byte (Character'Pos (Literal (Literal'First + Integer (I - Item.First)))) then
            return False;
         end if;
         pragma
           Loop_Invariant
             (for all J in Item.First .. I =>
                Buffer (J) = Byte (Character'Pos (Literal (Literal'First + Integer (J - Item.First)))));
      end loop;
      return True;
   end Equal_Literal;

end Kaitai.Strings;
