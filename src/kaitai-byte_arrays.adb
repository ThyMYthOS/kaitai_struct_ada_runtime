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

end Kaitai.Byte_Arrays;
