package body Rep_Data is

   --  Writes Value as a u4 at Pos and moves Pos on
   procedure Put_U4 (Buffer : in out Bytes; Pos : in out Length; Value : U32) is
   begin
      for J in 0 .. 3 loop
         Buffer (Pos + Length (J)) := U8 (Shift_Right (Value, 8 * J) and 16#FF#);
      end loop;
      Pos := Pos + 4;
   end Put_U4;

   --  Writes Count bytes that are not zero
   procedure Put_Filler (Buffer : in out Bytes; Pos : in out Length; Count : Natural; From : Natural) is
   begin
      for J in 1 .. Count loop
         Buffer (Pos) := U8 (97 + (From + J) mod 26);
         Pos := Pos + 1;
      end loop;
   end Put_Filler;

   --  The element K of the repetitions of a variable size
   procedure Put_Item (Buffer : in out Bytes; Pos : in out Length; K : Natural) is
   begin
      Buffer (Pos) := U8 (K mod 8);
      Pos := Pos + 1;
      Put_Filler (Buffer, Pos, K mod 8, K);
      Buffer (Pos) := U8 (K mod 251);
      Pos := Pos + 1;
   end Put_Item;

   procedure Put_Items (Buffer : in out Bytes; Pos : in out Length; N : Natural) is
   begin
      Put_U4 (Buffer, Pos, U32 (N));
      for K in 0 .. N - 1 loop
         Put_Item (Buffer, Pos, K);
      end loop;
   end Put_Items;

   --  num_items : u4, then N elements of len 0 and v 0
   procedure Put_U32_Items_Zero (Buffer : in out Bytes; Pos : in out Length; N : Natural) is
   begin
      Put_U4 (Buffer, Pos, U32 (N));
      Pos := Pos + 2 * Length (N);
   end Put_U32_Items_Zero;

   procedure Fill_Rep (N : Natural; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      Put_Items (Buffer, Pos, N);
      Used := Pos - 1;
   end Fill_Rep;

   procedure Fill_Rep_Empty (N : Natural; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      Put_U4 (Buffer, Pos, U32 (N));
      Buffer (Pos) := 0;
      Used := Pos;
   end Fill_Rep_Empty;

   procedure Put_Fixed (Buffer : in out Bytes; Pos : in out Length; N : Natural) is
   begin
      Put_U4 (Buffer, Pos, U32 (N));
      for K in 0 .. N - 1 loop
         Buffer (Pos) := U8 (K mod 8);
         Pos := Pos + 1;
      end loop;
   end Put_Fixed;

   procedure Fill_Rep_Fixed (N : Natural; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      Put_Fixed (Buffer, Pos, N);
      Used := Pos - 1;
   end Fill_Rep_Fixed;

   procedure Fill_Index (N : Natural; Fixed : Boolean; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
      Idx : Natural;
   begin
      Buffer := [others => 0];
      if Fixed then
         Put_Fixed (Buffer, Pos, N);
      else
         Put_Items (Buffer, Pos, N);
      end if;
      Put_U4 (Buffer, Pos, U32 (N));
      for J in 0 .. N - 1 loop
         Idx := (7 * J + 3) mod N;
         Put_U4 (Buffer, Pos, U32 (Idx));
         Put_Filler (Buffer, Pos, Idx mod 8, J);
      end loop;
      Used := Pos - 1;
   end Fill_Index;

   procedure Fill_Index_Worst (N : Natural; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      Put_U32_Items_Zero (Buffer, Pos, N);
      Put_U4 (Buffer, Pos, U32 (N / 4));
      for J in 1 .. N / 4 loop
         Put_U4 (Buffer, Pos, U32 (N - 1));
      end loop;
      Used := Pos - 1;
   end Fill_Index_Worst;

   procedure Fill_Last (N : Natural; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      Put_Items (Buffer, Pos, N);
      Put_Filler (Buffer, Pos, (N - 1) mod 8, N);
      Used := Pos - 1;
   end Fill_Last;

   procedure Fill_Prev_Self (N : Natural; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      Put_U4 (Buffer, Pos, U32 (N));
      for K in 0 .. N - 1 loop
         Buffer (Pos) := U8 (K mod 8);
         Pos := Pos + 1;
         Put_Filler (Buffer, Pos, K mod 8, K);
         if K > 0 then
            Put_Filler (Buffer, Pos, (K - 1) mod 8, K);
         end if;
      end loop;
      Used := Pos - 1;
   end Fill_Prev_Self;

   procedure Fill_Prev_Other (N : Natural; Buffer : out Bytes; Used : out Length) is
      Pos : Length := 1;
   begin
      Buffer := [others => 0];
      Put_Items (Buffer, Pos, N);
      for K in 1 .. N - 1 loop
         Put_Filler (Buffer, Pos, (K - 1) mod 8, K);
      end loop;
      Used := Pos - 1;
   end Fill_Prev_Other;

end Rep_Data;
