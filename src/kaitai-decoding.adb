package body Kaitai.Decoding
  with SPARK_Mode
is

   --  Each loop is written once for a width that is a constant of a generic function, and the four widths are
   --  instances of it.  With the width as a variable, the bounds that the calls of Element ask for contain products
   --  of the index and the width, and the provers need about a second for each of them; with a constant, the bounds
   --  are linear.

   generic
      Width : Length;
   function Min_Of_Width (Buffer : Bytes; Items : Slice; Signed : Boolean; Order : Byte_Order) return S64
   with
     Pre  => Elements_OK (Buffer, Items, Width, Signed),
     Post =>
       (for all J in 0 .. Size (Items) / Width - 1 =>
          Min_Of_Width'Result <= Element (Buffer, Items.First + J * Width, Width, Signed, Order))
       and then (for some J in 0 .. Size (Items) / Width - 1 =>
                   Min_Of_Width'Result = Element (Buffer, Items.First + J * Width, Width, Signed, Order));

   function Min_Of_Width (Buffer : Bytes; Items : Slice; Signed : Boolean; Order : Byte_Order) return S64 is
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
   end Min_Of_Width;

   generic
      Width : Length;
   function Max_Of_Width (Buffer : Bytes; Items : Slice; Signed : Boolean; Order : Byte_Order) return S64
   with
     Pre  => Elements_OK (Buffer, Items, Width, Signed),
     Post =>
       (for all J in 0 .. Size (Items) / Width - 1 =>
          Max_Of_Width'Result >= Element (Buffer, Items.First + J * Width, Width, Signed, Order))
       and then (for some J in 0 .. Size (Items) / Width - 1 =>
                   Max_Of_Width'Result = Element (Buffer, Items.First + J * Width, Width, Signed, Order));

   function Max_Of_Width (Buffer : Bytes; Items : Slice; Signed : Boolean; Order : Byte_Order) return S64 is
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
   end Max_Of_Width;

   function Min_1 is new Min_Of_Width (1);
   function Min_2 is new Min_Of_Width (2);
   function Min_4 is new Min_Of_Width (4);
   function Min_8 is new Min_Of_Width (8);
   function Max_1 is new Max_Of_Width (1);
   function Max_2 is new Max_Of_Width (2);
   function Max_4 is new Max_Of_Width (4);
   function Max_8 is new Max_Of_Width (8);

   function Min_Element (Buffer : Bytes; Items : Slice; Width : Length; Signed : Boolean; Order : Byte_Order) return S64
   is (case Width is
         when 1      => Min_1 (Buffer, Items, Signed, Order),
         when 2      => Min_2 (Buffer, Items, Signed, Order),
         when 4      => Min_4 (Buffer, Items, Signed, Order),
         when others => Min_8 (Buffer, Items, Signed, Order));

   function Max_Element (Buffer : Bytes; Items : Slice; Width : Length; Signed : Boolean; Order : Byte_Order) return S64
   is (case Width is
         when 1      => Max_1 (Buffer, Items, Signed, Order),
         when 2      => Max_2 (Buffer, Items, Signed, Order),
         when 4      => Max_4 (Buffer, Items, Signed, Order),
         when others => Max_8 (Buffer, Items, Signed, Order));

end Kaitai.Decoding;
