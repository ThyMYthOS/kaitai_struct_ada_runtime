package body Kaitai.Decoding
  with SPARK_Mode
is

   function Min_Element (Buffer : Bytes; Items : Slice; Width : Length; Signed : Boolean; Order : Byte_Order) return S64
   is
      Count  : constant Length := Size (Items) / Width;
      Result : S64 := Element (Buffer, Items.First, Width, Signed, Order);
   begin
      for J in 0 .. Count - 1 loop
         pragma Assert (J * Width <= Size (Items) - Width);
         declare
            Value : constant S64 := Element (Buffer, Items.First + J * Width, Width, Signed, Order);
         begin
            if Value < Result then
               Result := Value;
            end if;
         end;
         pragma
           Loop_Invariant
             (for all K in 0 .. J => Result <= Element (Buffer, Items.First + K * Width, Width, Signed, Order));
         pragma
           Loop_Invariant
             (for some K in 0 .. J => Result = Element (Buffer, Items.First + K * Width, Width, Signed, Order));
      end loop;
      return Result;
   end Min_Element;

   function Max_Element (Buffer : Bytes; Items : Slice; Width : Length; Signed : Boolean; Order : Byte_Order) return S64
   is
      Count  : constant Length := Size (Items) / Width;
      Result : S64 := Element (Buffer, Items.First, Width, Signed, Order);
   begin
      for J in 0 .. Count - 1 loop
         pragma Assert (J * Width <= Size (Items) - Width);
         declare
            Value : constant S64 := Element (Buffer, Items.First + J * Width, Width, Signed, Order);
         begin
            if Value > Result then
               Result := Value;
            end if;
         end;
         pragma
           Loop_Invariant
             (for all K in 0 .. J => Result >= Element (Buffer, Items.First + K * Width, Width, Signed, Order));
         pragma
           Loop_Invariant
             (for some K in 0 .. J => Result = Element (Buffer, Items.First + K * Width, Width, Signed, Order));
      end loop;
      return Result;
   end Max_Element;

end Kaitai.Decoding;
