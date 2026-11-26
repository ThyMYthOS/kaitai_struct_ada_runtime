with Ada.Text_IO;
with Kaitai.Streams; use Kaitai.Streams;
with Bench_Puser_V3;
with Pnav_V1;
with Pnav_V2;
with Pnav_V3;
with Pstr_V1;
with Pstr_V2;
with Puser_V1;
with Puser_V2;

package body Param_Runs is

   function Run_Pstr_V1 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Pstr_V1.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Pstr_V1.Parse (Data, S, P);
         exit when not OK (S) or else not Pstr_V1.Valid (P);
         Sum := Sum * 31 + U64 (Pstr_V1.Items_Count (P));
         if Phase /= 1 then
            declare
               use Pstr_V1;
               Position : Items_Cursor := Items_First (P);
               Item     : Item_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Item_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Data (Item_Type.Body_Field (Item).First));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Item_Type.Is_Key (Data, Item) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Pstr_V1;

   function Run_Pstr_V2 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Pstr_V2.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Pstr_V2.Parse (Data, S, P);
         exit when not OK (S) or else not Pstr_V2.Valid (P);
         Sum := Sum * 31 + U64 (Pstr_V2.Items_Count (P));
         if Phase /= 1 then
            declare
               use Pstr_V2;
               Position : Items_Cursor := Items_First (P);
               Item     : Item_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Item_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Data (Item_Type.Body_Field (Item).First));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Item_Type.Is_Key (Data, Item, Pstr_V2.Key (P)) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Pstr_V2;

   function Run_Pstr_V2W (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Pstr_V2.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Pstr_V2.Parse (Data, S, P);
         exit when not OK (S) or else not Pstr_V2.Valid (P);
         Sum := Sum * 31 + U64 (Pstr_V2.Items_Count (P));
         if Phase /= 1 then
            declare
               use Pstr_V2;
               Position : Items_Cursor := Items_First (P);
               Item     : Item_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Item_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Data (Item_Type.Body_Field (Item).First));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Items_Is_Key (Data, P, Item) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Pstr_V2W;

   function Run_Puser_V1 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Puser_V1.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Puser_V1.Parse (Data, S, P);
         exit when not OK (S) or else not Puser_V1.Valid (P);
         Sum := Sum * 31 + U64 (Puser_V1.Items_Count (P));
         if Phase /= 1 then
            declare
               use Puser_V1;
               Position : Items_Cursor := Items_First (P);
               Item     : Item_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Item_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Item_Type.X (Item)) + U64 (Item_Type.Y (Item));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Item_Type.Inside (Item) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Puser_V1;

   function Run_Puser_V2 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Puser_V2.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Puser_V2.Parse (Data, S, P);
         exit when not OK (S) or else not Puser_V2.Valid (P);
         Sum := Sum * 31 + U64 (Puser_V2.Items_Count (P));
         if Phase /= 1 then
            declare
               use Puser_V2;
               Position : Items_Cursor := Items_First (P);
               Item     : Item_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Item_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Item_Type.X (Item)) + U64 (Item_Type.Y (Item));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Item_Type.Inside (Item, Puser_V2.Hdr (P)) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Puser_V2;

   function Run_Puser_V2W (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Puser_V2.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Puser_V2.Parse (Data, S, P);
         exit when not OK (S) or else not Puser_V2.Valid (P);
         Sum := Sum * 31 + U64 (Puser_V2.Items_Count (P));
         if Phase /= 1 then
            declare
               use Puser_V2;
               Position : Items_Cursor := Items_First (P);
               Item     : Item_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Item_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Item_Type.X (Item)) + U64 (Item_Type.Y (Item));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Items_Inside (P, Item) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Puser_V2W;

   function Run_Puser_V3 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Bench_Puser_V3.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Bench_Puser_V3.Parse (Data, S, P);
         exit when not OK (S) or else not Bench_Puser_V3.Valid (P);
         Sum := Sum * 31 + U64 (Bench_Puser_V3.Items_Count (P));
         if Phase /= 1 then
            declare
               use Bench_Puser_V3;
               Position : Items_Cursor := Items_First (P);
               Item     : Item_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Item_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Item_Type.X (Item)) + U64 (Item_Type.Y (Item));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Item_Type.Inside (Item) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Puser_V3;

   function Run_Pnav_V1 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Pnav_V1.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Pnav_V1.Parse (Data, S, P);
         exit when not OK (S) or else not Pnav_V1.Valid (P);
         Sum := Sum * 31 + U64 (Pnav_V1.Items_Count (P));
         if Phase /= 1 then
            declare
               use Pnav_V1;
               Position : Items_Cursor := Items_First (P);
               Item     : Child_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Child_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Child_Type.V (Item));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Child_Type.Do_Something (Data, Item) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Pnav_V1;

   function Run_Pnav_V2 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Pnav_V2.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Pnav_V2.Parse (Data, S, P);
         exit when not OK (S) or else not Pnav_V2.Valid (P);
         Sum := Sum * 31 + U64 (Pnav_V2.Items_Count (P));
         if Phase /= 1 then
            declare
               use Pnav_V2;
               Position : Items_Cursor := Items_First (P);
               Item     : Child_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Child_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Child_Type.V (Item));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Child_Type.Do_Something (Data, Item, Pnav_V2.S1 (P)) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Pnav_V2;

   function Run_Pnav_V3 (Data : Bytes; Phase : Phase_Number) return U64 is
      S   : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      P   : Pnav_V3.T;
      Sum : U64 := 0;
   begin
      while not Is_EOF (S) loop
         Pnav_V3.Parse (Data, S, P);
         exit when not OK (S) or else not Pnav_V3.Valid (P);
         Sum := Sum * 31 + U64 (Pnav_V3.Items_Count (P));
         if Phase /= 1 then
            declare
               use Pnav_V3;
               Position : Items_Cursor := Items_First (P);
               Item     : Child_Type.T;
            begin
               while Has_Element (Position) loop
                  Next (Data, P, Position, Item);
                  exit when not Child_Type.Valid (Item);
                  Sum := Sum * 31 + U64 (Child_Type.V (Item));
                  if Phase = 3 then
                     Sum := Sum * 31 + (if Child_Type.Do_Something (Item) then 1 else 0);
                  end if;
               end loop;
            end;
         end if;
      end loop;
      return Sum;
   end Run_Pnav_V3;

   function Run (V : Variant; Data : Bytes; Phase : Phase_Number) return U64
   is (if Phase = 0
       then 0
       else
         (case V is
            when Pstr_1   => Run_Pstr_V1 (Data, Phase),
            when Pstr_2   => Run_Pstr_V2 (Data, Phase),
            when Pstr_2w  => Run_Pstr_V2W (Data, Phase),
            when Puser_1  => Run_Puser_V1 (Data, Phase),
            when Puser_2  => Run_Puser_V2 (Data, Phase),
            when Puser_2w => Run_Puser_V2W (Data, Phase),
            when Puser_3  => Run_Puser_V3 (Data, Phase),
            when Pnav_1   => Run_Pnav_V1 (Data, Phase),
            when Pnav_2   => Run_Pnav_V2 (Data, Phase),
            when Pnav_3   => Run_Pnav_V3 (Data, Phase)));

   procedure Put_Sizes is
      use Ada.Text_IO;

      function Image (Bits : Natural) return String
      is (Natural'Image (Bits / 8));
   begin
      Put_Line ("pstr_v1 " & Image (Pstr_V1.Item_Type.T'Object_Size) & Image (Pstr_V1.T'Object_Size));
      Put_Line ("pstr_v2 " & Image (Pstr_V2.Item_Type.T'Object_Size) & Image (Pstr_V2.T'Object_Size));
      Put_Line ("puser_v1 " & Image (Puser_V1.Item_Type.T'Object_Size) & Image (Puser_V1.T'Object_Size));
      Put_Line ("puser_v2 " & Image (Puser_V2.Item_Type.T'Object_Size) & Image (Puser_V2.T'Object_Size));
      Put_Line ("puser_v3 " & Image (Bench_Puser_V3.Item_Type.T'Object_Size) & Image (Bench_Puser_V3.T'Object_Size));
      Put_Line ("pnav_v1 " & Image (Pnav_V1.Child_Type.T'Object_Size) & Image (Pnav_V1.T'Object_Size));
      Put_Line ("pnav_v2 " & Image (Pnav_V2.Child_Type.T'Object_Size) & Image (Pnav_V2.T'Object_Size));
      Put_Line ("pnav_v3 " & Image (Pnav_V3.Child_Type.T'Object_Size) & Image (Pnav_V3.T'Object_Size));
   end Put_Sizes;

end Param_Runs;
