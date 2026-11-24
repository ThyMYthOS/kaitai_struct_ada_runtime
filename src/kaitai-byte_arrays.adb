package body Kaitai.Byte_Arrays
  with SPARK_Mode
is

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

   function Terminate_At (Buffer : Bytes; Item : Slice; Term : Byte; Include : Boolean) return Slice is
      Found : constant Length := Find (Buffer, Item, Term);
   begin
      if Found > Item.Last then
         return Item;
      elsif Include then
         return (First => Item.First, Last => Found);
      else
         return (First => Item.First, Last => Found - 1);
      end if;
   end Terminate_At;

   function Strip_Right (Buffer : Bytes; Item : Slice; Pad : Byte) return Slice is
      Last : Length := Item.Last;
   begin
      while Last >= Item.First and then Buffer (Last) = Pad loop
         pragma Loop_Invariant (Last in Item.First .. Item.Last);
         pragma Loop_Invariant (for all I in Last .. Item.Last => Buffer (I) = Pad);
         pragma Loop_Variant (Decreases => Last);
         Last := Last - 1;
      end loop;
      return (First => Item.First, Last => Last);
   end Strip_Right;

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

   function Find_Multi (Buffer : Bytes; Item : Slice; Term : Bytes) return Length is
      Unit : constant Length := Term'Length;
      From : Length := Item.First;
   begin
      while Unit - 1 <= Item.Last - From loop
         pragma Loop_Invariant (From in Item.First .. Item.Last);
         pragma Loop_Invariant ((From - Item.First) mod Unit = 0);
         pragma Loop_Variant (Increases => From);
         if Equal (Buffer, (First => From, Last => From + (Unit - 1)), Term) then
            return From;
         end if;
         From := From + Unit;
      end loop;
      return Item.Last + 1;
   end Find_Multi;

   function Terminate_At_Multi (Buffer : Bytes; Item : Slice; Term : Bytes; Include : Boolean) return Slice is
      Found : constant Length := Find_Multi (Buffer, Item, Term);
   begin
      if Found > Item.Last then
         return Item;
      elsif Include then
         return (First => Item.First, Last => Found + (Term'Length - 1));
      else
         return (First => Item.First, Last => Found - 1);
      end if;
   end Terminate_At_Multi;

   function Min (Buffer : Bytes; Item : Slice) return Byte is
      Result : Byte := Byte'Last;
   begin
      for I in Item.First .. Item.Last loop
         if Buffer (I) < Result then
            Result := Buffer (I);
         end if;
         pragma Loop_Invariant (for all J in Item.First .. I => Result <= Buffer (J));
         pragma Loop_Invariant (for some J in Item.First .. I => Result = Buffer (J));
      end loop;
      return Result;
   end Min;

   function Max (Buffer : Bytes; Item : Slice) return Byte is
      Result : Byte := Byte'First;
   begin
      for I in Item.First .. Item.Last loop
         if Buffer (I) > Result then
            Result := Buffer (I);
         end if;
         pragma Loop_Invariant (for all J in Item.First .. I => Result >= Buffer (J));
         pragma Loop_Invariant (for some J in Item.First .. I => Result = Buffer (J));
      end loop;
      return Result;
   end Max;

   function Compare (Left, Right : Bytes) return Order is
      Common : constant Length := Length'Min (Left'Length, Right'Length);
   begin
      for I in 0 .. Common - 1 loop
         if Left (Left'First + I) < Right (Right'First + I) then
            return Less;
         elsif Left (Left'First + I) > Right (Right'First + I) then
            return Greater;
         end if;
         pragma Loop_Invariant (Common_Prefix (Left, Right, I + 1));
      end loop;
      if Left'Length < Right'Length then
         return Less;
      elsif Left'Length > Right'Length then
         return Greater;
      else
         return Same;
      end if;
   end Compare;

end Kaitai.Byte_Arrays;
