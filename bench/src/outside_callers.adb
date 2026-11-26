with Kaitai.Streams;
with Bench_Puser_V3;
with Pnav_V1;
with Pnav_V2;
with Pnav_V3;
with Pstr_V1;
with Pstr_V2;
with Puser_V1;
with Puser_V2;

package body Outside_Callers
  with SPARK_Mode
is

   procedure Count_Pstr_V1 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Pstr_V1.T;
   begin
      Found := 0;
      Pstr_V1.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Pstr_V1.Valid (P) then
         declare
            Position : Pstr_V1.Items_Cursor := Pstr_V1.Items_First (P);
            Item     : Pstr_V1.Item_Type.T;
         begin
            while Pstr_V1.Has_Element (Position) loop
               pragma Loop_Invariant (Pstr_V1.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Pstr_V1.Remaining (Position));
               Pstr_V1.Next (Buffer, P, Position, Item);
               exit when not Pstr_V1.Item_Type.Valid (Item);
               if Pstr_V1.Item_Type.Is_Key (Buffer, Item) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Pstr_V1;

   procedure Count_Pstr_V2 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Pstr_V2.T;
   begin
      Found := 0;
      Pstr_V2.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Pstr_V2.Valid (P) then
         declare
            Position : Pstr_V2.Items_Cursor := Pstr_V2.Items_First (P);
            Item     : Pstr_V2.Item_Type.T;
         begin
            while Pstr_V2.Has_Element (Position) loop
               pragma Loop_Invariant (Pstr_V2.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Pstr_V2.Remaining (Position));
               Pstr_V2.Next (Buffer, P, Position, Item);
               exit when not Pstr_V2.Item_Type.Valid (Item);
               if Pstr_V2.Item_Type.Is_Key (Buffer, Item, Pstr_V2.Key (P)) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Pstr_V2;

   procedure Count_Pstr_V2W (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Pstr_V2.T;
   begin
      Found := 0;
      Pstr_V2.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Pstr_V2.Valid (P) then
         declare
            Position : Pstr_V2.Items_Cursor := Pstr_V2.Items_First (P);
            Item     : Pstr_V2.Item_Type.T;
         begin
            while Pstr_V2.Has_Element (Position) loop
               pragma Loop_Invariant (Pstr_V2.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Pstr_V2.Remaining (Position));
               Pstr_V2.Next (Buffer, P, Position, Item);
               exit when not Pstr_V2.Item_Type.Valid (Item);
               if Pstr_V2.Items_Is_Key (Buffer, P, Item) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Pstr_V2W;

   procedure Count_Puser_V1 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Puser_V1.T;
   begin
      Found := 0;
      Puser_V1.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Puser_V1.Valid (P) then
         declare
            Position : Puser_V1.Items_Cursor := Puser_V1.Items_First (P);
            Item     : Puser_V1.Item_Type.T;
         begin
            while Puser_V1.Has_Element (Position) loop
               pragma Loop_Invariant (Puser_V1.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Puser_V1.Remaining (Position));
               Puser_V1.Next (Buffer, P, Position, Item);
               exit when not Puser_V1.Item_Type.Valid (Item);
               if Puser_V1.Item_Type.Inside (Item) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Puser_V1;

   procedure Count_Puser_V2 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Puser_V2.T;
   begin
      Found := 0;
      Puser_V2.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Puser_V2.Valid (P) then
         declare
            Position : Puser_V2.Items_Cursor := Puser_V2.Items_First (P);
            Item     : Puser_V2.Item_Type.T;
         begin
            while Puser_V2.Has_Element (Position) loop
               pragma Loop_Invariant (Puser_V2.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Puser_V2.Remaining (Position));
               Puser_V2.Next (Buffer, P, Position, Item);
               exit when not Puser_V2.Item_Type.Valid (Item);
               if Puser_V2.Item_Type.Inside (Item, Puser_V2.Hdr (P)) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Puser_V2;

   procedure Count_Puser_V2W (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Puser_V2.T;
   begin
      Found := 0;
      Puser_V2.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Puser_V2.Valid (P) then
         declare
            Position : Puser_V2.Items_Cursor := Puser_V2.Items_First (P);
            Item     : Puser_V2.Item_Type.T;
         begin
            while Puser_V2.Has_Element (Position) loop
               pragma Loop_Invariant (Puser_V2.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Puser_V2.Remaining (Position));
               Puser_V2.Next (Buffer, P, Position, Item);
               exit when not Puser_V2.Item_Type.Valid (Item);
               if Puser_V2.Items_Inside (P, Item) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Puser_V2W;

   procedure Count_Puser_V3 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Bench_Puser_V3.T;
   begin
      Found := 0;
      Bench_Puser_V3.Parse (P, Buffer, S);
      if Kaitai.Streams.OK (S) and then Bench_Puser_V3.Valid (P) then
         declare
            Position : Bench_Puser_V3.Items_Cursor := Bench_Puser_V3.Items_First (P);
            Item     : Bench_Puser_V3.Item_Type.T;
         begin
            while Bench_Puser_V3.Has_Element (Position) loop
               pragma Loop_Invariant (Bench_Puser_V3.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Bench_Puser_V3.Remaining (Position));
               Bench_Puser_V3.Next (Buffer, P, Position, Item);
               exit when not Bench_Puser_V3.Item_Type.Valid (Item);
               if Bench_Puser_V3.Item_Type.Inside (Item) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Puser_V3;

   procedure Count_Pnav_V1 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Pnav_V1.T;
   begin
      Found := 0;
      Pnav_V1.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Pnav_V1.Valid (P) then
         declare
            Position : Pnav_V1.Items_Cursor := Pnav_V1.Items_First (P);
            Item     : Pnav_V1.Child_Type.T;
         begin
            while Pnav_V1.Has_Element (Position) loop
               pragma Loop_Invariant (Pnav_V1.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Pnav_V1.Remaining (Position));
               Pnav_V1.Next (Buffer, P, Position, Item);
               exit when not Pnav_V1.Child_Type.Valid (Item);
               if Pnav_V1.Child_Type.Do_Something (Buffer, Item) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Pnav_V1;

   procedure Count_Pnav_V2 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Pnav_V2.T;
   begin
      Found := 0;
      Pnav_V2.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Pnav_V2.Valid (P) then
         declare
            Position : Pnav_V2.Items_Cursor := Pnav_V2.Items_First (P);
            Item     : Pnav_V2.Child_Type.T;
         begin
            while Pnav_V2.Has_Element (Position) loop
               pragma Loop_Invariant (Pnav_V2.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Pnav_V2.Remaining (Position));
               Pnav_V2.Next (Buffer, P, Position, Item);
               exit when not Pnav_V2.Child_Type.Valid (Item);
               if Pnav_V2.Child_Type.Do_Something (Buffer, Item, Pnav_V2.S1 (P)) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Pnav_V2;

   procedure Count_Pnav_V3 (Buffer : Kaitai.Types.Bytes; Found : out Natural) is
      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      P : Pnav_V3.T;
   begin
      Found := 0;
      Pnav_V3.Parse (Buffer, S, P);
      if Kaitai.Streams.OK (S) and then Pnav_V3.Valid (P) then
         declare
            Position : Pnav_V3.Items_Cursor := Pnav_V3.Items_First (P);
            Item     : Pnav_V3.Child_Type.T;
         begin
            while Pnav_V3.Has_Element (Position) loop
               pragma Loop_Invariant (Pnav_V3.Belongs_To (Position, Buffer));
               pragma Loop_Variant (Decreases => Pnav_V3.Remaining (Position));
               Pnav_V3.Next (Buffer, P, Position, Item);
               exit when not Pnav_V3.Child_Type.Valid (Item);
               if Pnav_V3.Child_Type.Do_Something (Item) then
                  Found := Found + (if Found < Natural'Last then 1 else 0);
               end if;
            end loop;
         end;
      end if;
   end Count_Pnav_V3;

end Outside_Callers;
